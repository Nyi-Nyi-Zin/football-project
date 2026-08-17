-- +goose Up

ALTER TABLE payments.wallets
    ADD COLUMN IF NOT EXISTS reserved_balance DECIMAL(18,2) NOT NULL DEFAULT 0;

-- Prevent corrupted negative holds from being persisted.
-- +goose StatementBegin
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'wallets_reserved_balance_non_negative'
    ) THEN
        ALTER TABLE payments.wallets
            ADD CONSTRAINT wallets_reserved_balance_non_negative
            CHECK (reserved_balance >= 0);
    END IF;
END $$;
-- +goose StatementEnd

-- +goose Down
ALTER TABLE payments.wallets
    DROP CONSTRAINT IF EXISTS wallets_reserved_balance_non_negative;
ALTER TABLE payments.wallets
    DROP COLUMN IF EXISTS reserved_balance;
