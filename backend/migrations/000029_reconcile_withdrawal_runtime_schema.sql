-- +goose Up
-- Reconcile legacy production databases with the current location-based
-- customer withdrawal and payout-code workflow. Every statement is additive
-- or NULL-safe so it can run against both old and current schemas.
ALTER TABLE payments.transactions
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(255);

ALTER TABLE payments.wallets
    ADD COLUMN IF NOT EXISTS reserved_balance DECIMAL(18,2) DEFAULT 0;

UPDATE payments.wallets
SET reserved_balance = 0
WHERE reserved_balance IS NULL;

ALTER TABLE payments.withdrawal_requests
    ADD COLUMN IF NOT EXISTS location VARCHAR(100),
    ADD COLUMN IF NOT EXISTS region VARCHAR(100),
    ADD COLUMN IF NOT EXISTS township VARCHAR(100),
    ADD COLUMN IF NOT EXISTS code VARCHAR(10),
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

UPDATE payments.withdrawal_requests
SET location = COALESCE(NULLIF(location, ''), NULLIF(township, ''), 'Unknown')
WHERE location IS NULL OR location = '';

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_runtime_agent_lookup
    ON payments.withdrawal_requests(agent_id, code_lookup_hash, status);

-- +goose Down
DROP INDEX IF EXISTS idx_withdrawal_requests_runtime_agent_lookup;
-- Compatibility columns are intentionally retained on rollback.
