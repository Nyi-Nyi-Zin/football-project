-- +goose Up
ALTER TABLE users.accounts
    ADD COLUMN IF NOT EXISTS two_factor_secret_encrypted TEXT,
    ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE;

-- +goose Down
ALTER TABLE users.accounts
    DROP COLUMN IF EXISTS two_factor_enabled,
    DROP COLUMN IF EXISTS two_factor_secret_encrypted;
