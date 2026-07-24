import { APIRequestContext, expect } from '@playwright/test';
import { env } from '../config/env';
import { newOrderId } from '../helpers/ids';

export type ProcessCardInput = {
  amount: number;
  expirationDate: string;
  network: string;
  token: string;
  orderId?: string;
  zipCode?: string;
  payPageRegistrationId?: string;
  subMerchantId?: string;
};

export type ProcessCardResult = {
  status: number;
  body: Record<string, unknown>;
  orderId: string;
  transactionId?: string;
};

export class PaymentsClient {
  constructor(private readonly request: APIRequestContext) {}

  async authenticate(): Promise<string> {
    const res = await this.request.post(`${env.paymentsUrl}/authenticate`, {
      data: {
        username: env.paymentsUsername,
        password: env.paymentsPassword,
      },
    });
    expect(res.status(), await res.text()).toBe(200);
    const body = (await res.json()) as Record<string, unknown>;
    // Postman saves j.bearerToken → Payment-Bearer-Token
    const token =
      (body.bearerToken as string | undefined) ??
      (body['Payment-Bearer-Token'] as string | undefined) ??
      (body.accessToken as string | undefined) ??
      (body.access_token as string | undefined) ??
      (body.token as string | undefined);
    expect(token, `auth body keys: ${Object.keys(body).join(',')}`).toBeTruthy();
    return token as string;
  }

  async processCard(
    bearer: string,
    input: ProcessCardInput,
  ): Promise<ProcessCardResult> {
    const orderId = input.orderId ?? newOrderId('CNP');
    const payload: Record<string, unknown> = {
      amount: input.amount,
      expirationDate: input.expirationDate,
      network: input.network,
      orderId,
      payFacFee: 0,
      subMerchantId: input.subMerchantId ?? env.subMerchantId,
      token: input.token,
    };
    if (input.zipCode) payload.zipCode = input.zipCode;
    if (input.payPageRegistrationId) {
      delete payload.token;
      payload.payPageRegistrationId = input.payPageRegistrationId;
    }

    const res = await this.request.post(
      `${env.paymentsUrl}/credit-card/process-card`,
      {
        headers: { Authorization: `Bearer ${bearer}` },
        data: payload,
      },
    );
    const text = await res.text();
    let body: Record<string, unknown> = {};
    try {
      body = text ? (JSON.parse(text) as Record<string, unknown>) : {};
    } catch {
      body = { raw: text };
    }
    const transactionId =
      (body.transactionId as string | undefined) ??
      (body.TransactionId as string | undefined);
    return { status: res.status(), body, orderId, transactionId };
  }

  async refund(
    bearer: string,
    opts: {
      amount: number;
      orderId: string;
      originalTransactionId: string;
      wasVoided: boolean;
    },
  ): Promise<{ status: number; body: Record<string, unknown> }> {
    const res = await this.request.post(
      `${env.paymentsUrl}/refund-transaction`,
      {
        headers: { Authorization: `Bearer ${bearer}` },
        data: {
          amount: opts.amount,
          orderId: opts.orderId,
          originalTransactionId: opts.originalTransactionId,
          wasVoided: opts.wasVoided,
        },
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
