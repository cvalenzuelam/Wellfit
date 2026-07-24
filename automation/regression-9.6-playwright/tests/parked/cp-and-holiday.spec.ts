import { SkipReason } from '../../src/helpers/skip';
import { parked } from '../../src/helpers/parked';
import { test } from '@playwright/test';

/**
 * Explicit skip registry — mirrors Postman PARKED folders.
 */
test.describe('PARKED — not runnable on STAGE API automation', () => {
  parked(test, 
    'TokenVault TC05–TC07 + TC13 CP charge-card',
    SkipReason.CP_PHYSICAL_LANE,
  );
  parked(test, 
    'PAY-2603 TC06–TC07 CP + TC12 alert inject',
    SkipReason.CP_PHYSICAL_LANE,
  );
  parked(test, 
    'Treasury A — CP Payment Settlement and Funding',
    SkipReason.CP_PHYSICAL_LANE,
  );
  parked(test, 
    'Treasury B — CP Refund Settlement and Funding',
    SkipReason.CP_PHYSICAL_LANE,
  );
  parked(test, 'Treasury G — holiday skip calendar', SkipReason.HOLIDAY_CALENDAR);
});
