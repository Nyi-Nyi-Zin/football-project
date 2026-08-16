-- +goose Up
ALTER TABLE payments.wallets
    ADD COLUMN IF NOT EXISTS required_turnover DECIMAL(18,2) NOT NULL DEFAULT 0;

ALTER TABLE payments.wallets
    ADD COLUMN IF NOT EXISTS current_turnover DECIMAL(18,2) NOT NULL DEFAULT 0;

-- +goose Down
ALTER TABLE payments.wallets
    DROP COLUMN IF EXISTS required_turnover;

ALTER TABLE payments.wallets
    DROP COLUMN IF EXISTS current_turnover;
