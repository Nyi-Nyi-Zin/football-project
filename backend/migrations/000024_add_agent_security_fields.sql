-- +goose Up
ALTER TABLE users.accounts
    ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS security_pin_hash TEXT;

UPDATE users.accounts
SET token_version = 1
WHERE token_version IS NULL OR token_version < 1;

-- +goose Down
ALTER TABLE users.accounts
    DROP COLUMN IF EXISTS security_pin_hash,
    DROP COLUMN IF EXISTS token_version;
