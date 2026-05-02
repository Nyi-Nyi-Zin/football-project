-- +goose Up
-- Restore KYC and verification fields that were dropped in migration 000004
ALTER TABLE users.accounts
    ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_phone_verified BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS kyc_status        VARCHAR(20) NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS national_id       VARCHAR(100),
    ADD COLUMN IF NOT EXISTS kyc_image_url     TEXT;

-- +goose Down
-- Drop the restored fields (revert to state after migration 000004)
ALTER TABLE users.accounts
    DROP COLUMN IF EXISTS is_email_verified,
    DROP COLUMN IF EXISTS is_phone_verified,
    DROP COLUMN IF EXISTS kyc_status,
    DROP COLUMN IF EXISTS national_id,
    DROP COLUMN IF EXISTS kyc_image_url;
