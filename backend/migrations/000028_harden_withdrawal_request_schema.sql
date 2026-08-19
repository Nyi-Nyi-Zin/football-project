-- +goose Up
-- Keep existing production databases compatible with the location-based
-- customer withdrawal flow and payout-code settlement.
ALTER TABLE payments.wallets
    ADD COLUMN IF NOT EXISTS reserved_balance DECIMAL(18,2) DEFAULT 0;

UPDATE payments.wallets
SET reserved_balance = 0
WHERE reserved_balance IS NULL;

ALTER TABLE payments.wallets
    ALTER COLUMN reserved_balance SET DEFAULT 0,
    ALTER COLUMN reserved_balance SET NOT NULL;

ALTER TABLE payments.withdrawal_requests
    ADD COLUMN IF NOT EXISTS location VARCHAR(100),
    ADD COLUMN IF NOT EXISTS region VARCHAR(100),
    ADD COLUMN IF NOT EXISTS township VARCHAR(100),
    ADD COLUMN IF NOT EXISTS code VARCHAR(10),
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

UPDATE payments.withdrawal_requests
SET location = COALESCE(NULLIF(location, ''), township, 'Unknown')
WHERE location IS NULL OR location = '';

-- +goose Down
-- The compatibility columns are intentionally retained on rollback because
-- older application versions may still read them.
