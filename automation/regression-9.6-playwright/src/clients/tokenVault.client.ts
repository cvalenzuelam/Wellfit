import { APIRequestContext } from '@playwright/test';
import { env } from '../config/env';
import { newGuid } from '../helpers/ids';

export type AddTokenInput = {
  processorToken?: string;
  cardLastFour?: string;
  cardBrand?: string;
  cardExpirationMonth?: number;
  cardExpirationYear?: number;
  cardZipCode?: string | null;
  /** When true, omit cardZipCode from body entirely */
  omitZip?: boolean;
};

function extractTokenId(body: Record<string, unknown>): string | undefined {
  const pt = (body.paymentToken ?? body.PaymentToken) as
    | Record<string, unknown>
    | undefined;
  const id =
    (pt?.id as string | undefined) ??
    (pt?.Id as string | undefined) ??
    (body.id as string | undefined) ??
    (body.Id as string | undefined) ??
    (body.tokenId as string | undefined) ??
    (body.TokenId as string | undefined);
  return id ? String(id) : undefined;
}

export class TokenVaultClient {
  constructor(private readonly request: APIRequestContext) {}

  async addToken(
    bearer: string,
    input: AddTokenInput = {},
  ): Promise<{ status: number; body: Record<string, unknown>; id: string }> {
    const requestId = newGuid();
    const payload: Record<string, unknown> = {
      id: requestId,
      processorToken: input.processorToken ?? env.tokenVisa,
      cardLastFour: input.cardLastFour ?? env.cardLastFourVisa,
      cardBrand: input.cardBrand ?? 'VISA',
      cardExpirationMonth: input.cardExpirationMonth ?? 12,
      cardExpirationYear: input.cardExpirationYear ?? 2034,
    };
    if (!input.omitZip) {
      if (input.cardZipCode === null) {
        // omit
      } else if (input.cardZipCode !== undefined) {
        payload.cardZipCode = input.cardZipCode;
      } else {
        payload.cardZipCode = env.zipCode;
      }
    }

    const res = await this.request.post(`${env.tokenVaultUrl}/add-token`, {
      headers: { Authorization: `Bearer ${bearer}` },
      data: payload,
    });
    const text = await res.text();
    let body: Record<string, unknown> = {};
    try {
      body = text ? (JSON.parse(text) as Record<string, unknown>) : {};
    } catch {
      body = { raw: text };
    }
    const id = extractTokenId(body) ?? requestId;
    return { status: res.status(), body, id };
  }

  async getTokenDetails(
    bearer: string,
    tokenId: string,
  ): Promise<{ status: number; body: Record<string, unknown> }> {
    const res = await this.request.get(
      `${env.tokenVaultUrl}/get-token-details`,
      {
        headers: { Authorization: `Bearer ${bearer}` },
        params: { tokenId },
      },
    );
    const text = await res.text();
    let body: Record<string, unknown> = {};
    try {
      body = text ? (JSON.parse(text) as Record<string, unknown>) : {};
    } catch {
      body = { raw: text };
    }
    return { status: res.status(), body };
  }
}
