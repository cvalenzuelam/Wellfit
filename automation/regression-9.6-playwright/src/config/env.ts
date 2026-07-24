/**
 * STAGE config for Regression 9.6 API automation.
 * Prefer .env overrides; defaults mirror Postman env Regression STAGE.
 */
function required(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (!value) {
    throw new Error(`Missing required env: ${name}. Copy .env.example → .env`);
  }
  return value;
}

export const env = {
  paymentsUrl: required(
    'STAGE_PAYMENTS_URL',
    'https://stage-platform.wellfit.com/payments',
  ),
  tokenVaultUrl: required(
    'STAGE_TOKENVAULT_URL',
    'https://stage-platform.wellfit.com/tokenvault',
  ),
  treasuryUrl: required(
    'STAGE_TREASURY_URL',
    'https://stage-platform.wellfit.com/treasury',
  ),
  walletUrl: required(
    'STAGE_WALLET_URL',
    'https://stage-platform.wellfit.com/wallet',
  ),
  mpUrl: required(
    'STAGE_MP_URL',
    'https://stage-wf-merchantprovisioning-api.azurewebsites.net',
  ),

  paymentsUsername: required('PAYMENTS_USERNAME', 'WellfitUnifiedPaymentsAPI'),
  paymentsPassword: required('PAYMENTS_PASSWORD', 'Testing123!!W3llf1t1!'),

  subMerchantId: required(
    'SUB_MERCHANT_ID',
    '159F2670-1B71-4EF6-AD30-0EBF0991E2CC',
  ),

  tokenVisa: required('TOKEN_VISA', '1111000281821111'),
  tokenAmex: required('TOKEN_AMEX', '111300261500004'),
  tokenDiscover: required('TOKEN_DISCOVER', '1114000265160004'),
  tokenMc: required('TOKEN_MC', '1112000299535454'),

  expirationDate: required('EXPIRATION_DATE', '1234'),
  expirationDateAmex: required('EXPIRATION_DATE_AMEX', '1030'),
  expirationDateDiscover: required('EXPIRATION_DATE_DISCOVER', '1030'),
  expirationDateMc: required('EXPIRATION_DATE_MC', '0350'),
  zipCode: required('ZIP_CODE', '01803'),
  cardLastFourVisa: required('CARD_LAST_FOUR_VISA', '1111'),

  treasuryApiKey: required(
    'TREASURY_API_KEY',
    'V2VsbGZpdEF1dG9tYXRpb246VGVzdDEyMyE=',
  ),

  mpUsername: required('MP_USERNAME', 'WellfitOnBoardingAPI'),
  mpPassword: required('MP_PASSWORD', 'Testing12!!L0v3Wellfit'),

  walletUsername: required('WALLET_USERNAME', 'WellfitUnifiedPaymentsAPI'),
  walletPassword: required('WALLET_PASSWORD', 'Testing123!!W3llf1t1!'),

  /** Off by default — create/send funding batch mutates STAGE settlement state */
  runTreasuryFunding: process.env.RUN_TREASURY_FUNDING === '1',
};

export type CardBrand = {
  name: string;
  network: string;
  token: string;
  expirationDate: string;
  amount: number;
};

export const cnpBrands: CardBrand[] = [
  {
    name: 'VISA',
    network: 'VI',
    token: env.tokenVisa,
    expirationDate: env.expirationDate,
    amount: 10.01,
  },
  {
    name: 'AMEX',
    network: 'AX',
    token: env.tokenAmex,
    expirationDate: env.expirationDateAmex,
    amount: 10.01,
  },
  {
    name: 'Discover',
    network: 'DI',
    token: env.tokenDiscover,
    expirationDate: env.expirationDateDiscover,
    amount: 10.01,
  },
  {
    name: 'MasterCard',
    network: 'MC',
    token: env.tokenMc,
    expirationDate: env.expirationDateMc,
    amount: 10.01,
  },
];
