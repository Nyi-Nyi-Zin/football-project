-- +goose Up
-- Add custom_code column for agents to set their own verification code
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS custom_code VARCHAR(10) UNIQUE;

-- +goose Down
ALTER TABLE users.accounts DROP COLUMN IF EXISTS custom_code;
