-- Rollback: remove KYC columns and turnover columns

ALTER TABLE users.accounts
    DROP COLUMN IF EXISTS is_email_verified,
    DROP COLUMN IF EXISTS is_phone_verified,
    DROP COLUMN IF EXISTS kyc_status,
    DROP COLUMN IF EXISTS national_id,
    DROP COLUMN IF EXISTS kyc_image_url;

ALTER TABLE payments.wallets
    DROP COLUMN IF EXISTS required_turnover,
    DROP COLUMN IF EXISTS current_turnover;
