import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';

const code = ts.transpileModule(
  readFileSync(new URL('./orders.ts', import.meta.url), 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } },
).outputText;

const { isOrderAwaitingCustomerConfirmation } = await import(
  `data:text/javascript;base64,${Buffer.from(code).toString('base64')}`
);

test('marks active orders with missing or PENDING_CUSTOMER confirmationStatus as awaiting confirmation', () => {
  assert.equal(
    isOrderAwaitingCustomerConfirmation({ status: 'PENDING', confirmationStatus: null }),
    true,
  );
  assert.equal(
    isOrderAwaitingCustomerConfirmation({ status: 'IN_PROGRESS', confirmationStatus: 'PENDING_CUSTOMER' }),
    true,
  );
  assert.equal(
    isOrderAwaitingCustomerConfirmation({ status: 'COMPLETED', confirmationStatus: '' }),
    true,
  );
});

test('does not warn when customer approved, submitted payment, rejected, or order is delivered/cancelled', () => {
  assert.equal(
    isOrderAwaitingCustomerConfirmation({ status: 'IN_PROGRESS', confirmationStatus: 'APPROVED' }),
    false,
  );
  assert.equal(
    isOrderAwaitingCustomerConfirmation({ status: 'IN_PROGRESS', confirmationStatus: 'PAYMENT_SUBMITTED' }),
    false,
  );
  assert.equal(
    isOrderAwaitingCustomerConfirmation({ status: 'IN_PROGRESS', confirmationStatus: 'REJECTED' }),
    false,
  );
  assert.equal(
    isOrderAwaitingCustomerConfirmation({ status: 'DELIVERED', confirmationStatus: 'PENDING_CUSTOMER' }),
    false,
  );
  assert.equal(
    isOrderAwaitingCustomerConfirmation({ status: 'CANCELLED', confirmationStatus: 'PENDING_CUSTOMER' }),
    false,
  );
});

