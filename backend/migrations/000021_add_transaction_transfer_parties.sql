-- +goose Up
ALTER TABLE payments.transactions
    ADD COLUMN IF NOT EXISTS from_user_id UUID,
    ADD COLUMN IF NOT EXISTS to_user_id UUID;

CREATE INDEX IF NOT EXISTS idx_transactions_from_user_id
    ON payments.transactions (from_user_id);

CREATE INDEX IF NOT EXISTS idx_transactions_to_user_id
    ON payments.transactions (to_user_id);

-- +goose Down
DROP INDEX IF EXISTS payments.idx_transactions_from_user_id;
DROP INDEX IF EXISTS payments.idx_transactions_to_user_id;

ALTER TABLE payments.transactions
    DROP COLUMN IF EXISTS from_user_id,
    DROP COLUMN IF EXISTS to_user_id;
