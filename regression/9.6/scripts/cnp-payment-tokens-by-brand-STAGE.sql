-- STAGE — CNP ProcessorTokens for legacy process-card
-- DB: TokenVault
-- Use numeric ProcessorToken only (NOT WPAC*, NOT GUID-like)

-- Latest numeric tokens per CardBrand (up to 3 each)
;WITH ranked AS (
  SELECT
    ProcessorToken,
    CardBrand,
    CardLastFour,
    CardExpirationMonth,
    CardExpirationYear,
    CardZipCode,
    EntityUpdated,
    ROW_NUMBER() OVER (
      PARTITION BY CardBrand
      ORDER BY EntityUpdated DESC
    ) AS rn
  FROM [dbo].[PaymentTokens]
  WHERE ProcessorToken IS NOT NULL
    AND CardBrand IS NOT NULL
    AND ProcessorToken LIKE '[0-9]%'
    AND ProcessorToken NOT LIKE '%[A-Za-z]%'   -- exclude WPAC / GUID hybrids
    AND (
      CardExpirationYear > YEAR(SYSUTCDATETIME())
      OR (
        CardExpirationYear = YEAR(SYSUTCDATETIME())
        AND CardExpirationMonth >= MONTH(SYSUTCDATETIME())
      )
    )
)
SELECT
  ProcessorToken,
  CardBrand,
  CardLastFour,
  CardExpirationMonth,
  CardExpirationYear,
  CardZipCode,
  EntityUpdated
FROM ranked
WHERE rn <= 3
ORDER BY CardBrand, EntityUpdated DESC;
