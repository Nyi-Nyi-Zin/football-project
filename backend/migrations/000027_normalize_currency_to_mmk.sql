-- Normalize the platform currency to Myanmar Kyat without changing monetary amounts.
-- +goose Up
ALTER TABLE payments.wallets
  ALTER COLUMN currency SET DEFAULT 'MMK';

ALTER TABLE payments.transactions
  ALTER COLUMN currency SET DEFAULT 'MMK';

UPDATE payments.wallets
SET currency = 'MMK'
WHERE currency IS NULL OR UPPER(currency) = 'USD';

UPDATE payments.transactions
SET currency = 'MMK'
WHERE currency IS NULL OR UPPER(currency) = 'USD';

-- +goose Down
UPDATE payments.wallets
SET currency = 'USD'
WHERE UPPER(currency) = 'MMK';

UPDATE payments.transactions
SET currency = 'USD'
WHERE UPPER(currency) = 'MMK';

ALTER TABLE payments.wallets
  ALTER COLUMN currency SET DEFAULT 'USD';

ALTER TABLE payments.transactions
  ALTER COLUMN currency SET DEFAULT 'USD';
