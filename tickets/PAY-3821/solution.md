# Solution — wrap Treasury funding-batch send in error handling

**Scope:** `wellfit-payments` / `treasury-ms`. One method + a minimal test seam + tests. Small.

## Change

Wrap the per-batch send in `WorldpayFunding.SendFundingBatch()` (`Infrastructure/Funding/Worldpay/WorldpayFunding.cs:201-208`):

```csharp
for (var i = 0; i < pendingBatches.Count; i++)
{
    var fundingBatch = pendingBatches[i];
    try
    {
        SendBatchFile(fundingBatch.BatchFileName);   // seam — see below

        fundingBatch.RequestSentTimeStamp = DateTimeOffset.Now;
        this._domainFacade.Commit();
    }
    catch (Exception ex) when (ex is LitleOnlineException or SocketException)
    {
        // Everything from the failing batch onward is unsent — name them all in the alert.
        var unsent = pendingBatches.Skip(i)
            .Select(b => $"{b.Id} ({b.BatchFileName})")
            .ToList();

        _logger.LogError(ex,
            "Funding batch send to Worldpay failed; stopping run. BatchId={BatchId} File={BatchFileName} Host={Host} UnsentBatches={UnsentCount}: {UnsentBatches}",
            fundingBatch.Id, fundingBatch.BatchFileName,
            _configuration["processor:vantiv:batch:sftpUrl"],
            unsent.Count, string.Join("; ", unsent));

        try
        {
            _email.Send(
                "Error - Funding Batch Send Failed",
                $"Funding batch {fundingBatch.Id} ({fundingBatch.BatchFileName}) failed to send to Worldpay: {ex.Message}. " +
                $"The run was stopped. {unsent.Count} batch(es) remain unsent and will be retried on the next run:<br/>" +
                string.Join("<br/>", unsent),
                _configuration["notifications:noReplyEmail"],
                _settlementNotificationRecipients);
        }
        catch (Exception emailEx)
        {
            _logger.LogError(emailEx, "Failed to send funding-batch failure notification");
        }

        // Transport-level failure affects every batch in this run identically —
        // stop instead of serially repeating the connect timeout per batch.
        break;
    }
}
```

```csharp
/// <summary>Seam for tests: the only line that touches the vendored Litle SDK.</summary>
protected virtual void SendBatchFile(string batchFileName)
{
    var request = new litleRequest(ConfigurationProperties());
    request.sendBatchToLitle(batchFileName);
}
```

Also mark `IsBankingDay()` (`WorldpayFunding.cs:1179`) `virtual` so tests can force the banking-day gate open.

### Decisions baked in

- **Catch `LitleOnlineException` *and* `SocketException`.** The SDK wraps Ssh connection/auth errors as `LitleOnlineException`, but a connect-time `SocketException` (the observed SBOX case) bypasses that wrapper. Both must be caught. Do **not** catch bare `Exception` — let genuinely unexpected errors (config nulls, Azure storage failures) surface.
- **`break`, not `continue`.** Both caught types are transport-level and shared by every batch in the run; continuing would serially repeat the connect timeout (~20s+ per batch) and spam one alert per batch for one cause. One log + one email + stop. Remaining batches keep `RequestSentTimeStamp == null` and are re-selected next run — retry semantics identical.
- **Leave `RequestSentTimeStamp` null on failure.** Preserves the existing idempotent retry — no new retry machinery.
- **Guard the notification.** `ISendEmail.Send` is the sync void SendGrid wrapper and can itself throw; a notification failure must not replace the controlled handling (the error log has already landed).
- **Seam instead of mock.** `litleRequest` is a concrete vendored class with a non-virtual `sendBatchToLitle`, newed inline — it cannot be mocked (same no-Vantiv-seam pattern as payments-api ECommerce). `WorldpayFunding` is `public partial`, unsealed, and all five ctor deps are interfaces (`IConfiguration`, `IDomainFacade`, `ILogger<>`, `ISendEmail`, `IPaymentLookupService`), so a `protected virtual` extraction is the smallest possible seam: tests subclass and override; no new interfaces, no DI changes, runtime behavior byte-identical.

## Acceptance criteria

1. A test-subclass `SendBatchFile` throwing `SocketException` (and separately `LitleOnlineException`) produces:
   - an error log carrying `BatchId`, `BatchFileName`, and the SFTP host,
   - a failure-notification email to the settlement recipients,
   - and the exception does **not** propagate out of `SendFundingBatch()`.
2. On a transport failure with multiple pending batches, the run stops after the failing batch — exactly one alert — and **all** unsent batches (including the failing one) remain `RequestSentTimeStamp == null`. The alert email and the error log **enumerate every unsent batch** (`Id` + `BatchFileName`), so the recipient knows the full blast radius without querying `FundingBatches`. Batches already sent earlier in the run are excluded (their timestamps are committed).
3. On success the timestamp is set exactly as today; happy path and the existing empty-batch warning are unchanged.
4. A throwing `_email.Send` inside the failure path is swallowed and logged; the original failure handling still completes.

## Tests

New file alongside `Tests/ApplicationTests/Funding/Worldpay/WorldpayFundingTests.cs`, using a test subclass overriding `SendBatchFile` (throw/record) and `IsBankingDay` (return true), with mocked ctor interfaces:

- `SendFundingBatch_WhenSendThrowsSocketException_LogsAlertsAndDoesNotPropagate`
- `SendFundingBatch_WhenSendThrowsLitleOnlineException_LogsAlertsAndDoesNotPropagate`
- `SendFundingBatch_OnTransportFailure_StopsRunAndAlertsWithAllUnsentBatches` (3 pending, batch 2 fails → batch 1 sent+stamped, batches 2-3 unstamped, exactly 1 email whose body names batches 2 and 3 but not 1)
- `SendFundingBatch_WhenEmailSendThrows_OriginalHandlingStillCompletes`

Note: this is the **first** test coverage of `SendFundingBatch` — the existing `WorldpayFundingTests.cs` only characterizes SDK `batchRequest` plumbing.

## QA verification (env-level, black-box)

The failure condition is config-inducible — no test harness needed.

**Trigger options**
- *Natural (while it lasts):* Dev/SBOX currently reproduce the exact `SocketException` via the Worldpay allowlist gap — trigger `POST send-funding-batch` there as-is.
- *Deterministic:* point `processor:vantiv:batch:sftpurl` at a non-routable host in the env overlay → guaranteed connect timeout (`SocketException` branch). Wrong `sftpPassword` → `SshAuthenticationException` → SDK wraps → `LitleOnlineException` branch.

**Preconditions**
- `FundingBatches` rows staged with `BatchFileName IS NOT NULL AND RequestSentTimeStamp IS NULL` (≥3 rows for the multi-batch case; SQL-stageable in Dev — see the Treasury funding SQL fixture).
- Banking day (or the `IsBankingDay()` gate skips the loop).
- `notifications:settlement:recipients` set to a team-reachable inbox.

**Assert**
1. Exactly one alert email: failed batch named, all unsent batches enumerated, previously-sent batches absent.
2. App Insights error log (role *Wellfit Treasury API*) with `BatchId`, `BatchFileName`, host, unsent list.
3. `RequestSentTimeStamp` remains `NULL` for failed + stranded rows; set for batches sent before the failure.
4. Service healthy afterwards — endpoint still returns 202, no host-loop death.
5. Restore config → re-trigger → batches send and stamp normally (retry semantics intact).

Not externally distinguishable (by design): which of the two exception types was caught — covered by unit tests.

## Coordinate with

PAY-3587 **H2** (Treasury `BackgroundService` outer try lacks a catch). Keep the two fixes consistent: H2 keeps the host loop alive; this handles/logs/alerts at the send site so the loop has nothing fatal to swallow in the first place.

## Out of scope

- The Worldpay source-IP allowlist gap (the actual cause of the SBOX/Dev failures) — separate track.
- Hardening the vendored `LitleSdkForNet/Communications.cs` to wrap `SocketException` in `LitleOnlineException`.
