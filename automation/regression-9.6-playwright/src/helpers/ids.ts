import { randomUUID } from 'crypto';

/** Unique order id for STAGE charges (Postman {{orderId}} pattern). */
export function newOrderId(prefix = 'PW'): string {
  const stamp = Date.now().toString(36).toUpperCase();
  const rand = Math.random().toString(36).slice(2, 8).toUpperCase();
  return `${prefix}-${stamp}-${rand}`;
}

export function newGuid(): string {
  return randomUUID();
}
