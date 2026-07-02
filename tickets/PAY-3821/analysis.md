# Treasury funding-batch send has no error handling around the Worldpay SFTP call

**Date:** 2026-06-03 (re-assessed 2026-06-10)
**Repo:** wellfit-payments (treasury-ms)
**Discovered while investigating:** SBOX funding-batch send failure — `sbox-insights`, role *Wellfit Treasury API*, exception at `2026-06-03T14:56:22Z` (`System.Net.Sockets.SocketException @ Renci.SshNet.Abstractions.SocketAbstraction.ConnectCore` — TCP connect timeout to `batch.vantivprelive.com`). Root cause of *that* failure is a Worldpay source-IP allowlist gap (separate track); this item is the **observability/resilience defect it exposed**.

## Symptom

A Worldpay-side network failure during the SFTP upload propagates **unhandled** out of the Treasury funding-batch send path. The operator gets:

- **No alert.** The only notification email in the method fires for the *empty-batch* case, not for a send failure.
- **No failure state on the row.** `FundingBatch.RequestSentTimeStamp` stays `null` (the timestamp is only set *after* a successful send), so the batch is silently re-selected on the next run — retry happens, but nothing records that a send *failed* or *why*.
- **No domain context in the log.** The exception surfaces in App Insights only as a raw `SocketException` with a `Renci.SshNet` stack — nothing ties it to a `FundingBatch.Id`, `BatchFileName`, or the target host. We only diagnosed it by trawling telemetry.
- **Silent partial progress.** The send loop commits per-iteration; a throw on batch *N* leaves batches `1..N-1` committed and `N..M` unprocessed with no record of the break point.

## Root cause

The send call is unwrapped at all three layers of the stack:

1. **`WorldpayFunding.SendFundingBatch()`** — `Infrastructure/Funding/Worldpay/WorldpayFunding.cs:189-210`

   ```csharp
   foreach (var fundingBatch in pendingBatches)
   {
       var request = new litleRequest(ConfigurationProperties());
       request.sendBatchToLitle(fundingBatch.BatchFileName);   // line 204 — no try/catch

       fundingBatch.RequestSentTimeStamp = DateTimeOffset.Now;  // line 206 — skipped on throw
       this._domainFacade.Commit();                             // line 207 — per-iteration commit
   }
   ```
   The only `_email.Send` (line 198) is in the `pendingBatches.Count == 0` branch — there is no failure-path notification.

2. **`WorldpayFundingBatchProcessor.SendFundingBatch()`** — `Infrastructure/Funding/Worldpay/WorldpayFundingBatchProcessor.cs:117`
   ```csharp
   public void SendFundingBatch() => _worldpayFunding.SendFundingBatch();   // bare passthrough
   ```

3. **`SendFundingBatchStageHandler.HandleAsync()`** — `Infrastructure/Coordination/Handlers/SendFundingBatchStageHandler.cs:31`
   ```csharp
   _processor.SendFundingBatch();   // bare call, no catch
   ```

So the exception travels straight to the `FundingBatchCoordinator` / hosting `BackgroundService` with zero Treasury-domain handling.

### Secondary gap (vendored SDK)

The exception reached App Insights as a **raw `System.Net.Sockets.SocketException`**, not the SDK's `LitleOnlineException`. The vendored `Processor SDKs/LitleSdkForNet/Communications.cs` `FtpDropOff` only catches `SshConnectionException` / `SshAuthenticationException` — a *connect-time* `SocketException` is neither, so it bypasses the SDK's wrapper entirely. The robust fix in `WorldpayFunding` must therefore catch **both** `LitleOnlineException` (SDK-wrapped failures) and `SocketException` (raw connect failures). Hardening the vendored SDK itself is out of scope for this item.

## Failure-class observation (drives the fix shape)

Both catchable exception types are **transport-level**: a connect timeout or Ssh-layer failure to `batch.vantivprelive.com` affects *every* batch in the run identically — it is not a per-batch condition. Continuing the loop after one would serially repeat the connect timeout (~20s+ each) and fire one alert per batch, all with the same cause. The remaining batches lose nothing by waiting: their `RequestSentTimeStamp` stays `null`, so the next run re-selects them. Therefore the correct loop policy on a caught transport failure is **alert once and stop the run**, not continue.

## What this item does NOT change

- **Retry semantics.** The `RequestSentTimeStamp == null && BatchFileName != null` re-select is the existing idempotent retry; keep it. This item only makes the failure *observable* and *bounded*, it does not add a new retry mechanism.
- **The network root cause.** The Worldpay source-IP allowlist gap (SBOX `172.184.169.199`, Dev `20.59.126.13` not allowlisted; QA/Stage `20.245.x` are) is tracked separately. Error handling would not have *prevented* the failure — it would have surfaced it cleanly on day one instead of via telemetry archaeology.

## Why it wasn't caught

The happy path works, and lower-env send failures are rare (they only manifest when the destination is unreachable). Verified against the test suite: `Tests/ApplicationTests/Funding/Worldpay/WorldpayFundingTests.cs` only characterizes the SDK's `batchRequest` XML/config plumbing — **no test constructs `WorldpayFunding` or exercises `SendFundingBatch`**, and there is no mock seam around `litleRequest` (concrete class, non-virtual `sendBatchToLitle`, newed inline at `WorldpayFunding.cs:203`). Same no-Vantiv-seam pattern previously observed in payments-api ECommerce. The design treated the SFTP call as infallible.

## Related

- **PAY-3587 finding H2** — the Treasury `BackgroundService` outer `try` lacks a `catch`, so an unhandled exception from this path can kill the host loop. This item and H2 touch overlapping ground; coordinate so the fixes don't conflict (H2 = keep the loop alive; this = handle/log/alert at the send site).
