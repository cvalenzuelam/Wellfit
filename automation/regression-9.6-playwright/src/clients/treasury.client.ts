import { APIRequestContext } from '@playwright/test';
import { env } from '../config/env';

export class TreasuryClient {
  constructor(private readonly request: APIRequestContext) {}

  async health(): Promise<{ status: number; body: unknown }> {
    const res = await this.request.get(`${env.treasuryUrl}/health`);
    const text = await res.text();
    let body: unknown = text;
    try {
      body = text ? JSON.parse(text) : null;
    } catch {
      /* keep text */
    }
    return { status: res.status(), body };
  }

  async createFundingBatch(): Promise<{ status: number; body: unknown }> {
    const res = await this.request.post(
      `${env.treasuryUrl}/create-funding-batch`,
      {
        headers: { api_key: env.treasuryApiKey },
        data: {},
      },
    );
    return { status: res.status(), body: await safeJson(res) };
  }

  async sendFundingBatch(): Promise<{ status: number; body: unknown }> {
    const res = await this.request.post(
      `${env.treasuryUrl}/send-funding-batch`,
      {
        headers: { api_key: env.treasuryApiKey },
        data: {},
      },
    );
    return { status: res.status(), body: await safeJson(res) };
  }
}

async function safeJson(res: {
  text: () => Promise<string>;
}): Promise<unknown> {
  const text = await res.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
}
