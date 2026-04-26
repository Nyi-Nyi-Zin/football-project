-- ============================================================
-- Migration 000004: KYC verification fields + AML turnover tracking
-- ============================================================

-- 1. KYC / Verification columns on user accounts
ALTER TABLE users.accounts
    ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_phone_verified BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS kyc_status        VARCHAR(20) NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS national_id       VARCHAR(100),
    ADD COLUMN IF NOT EXISTS kyc_image_url     TEXT;

-- 2. Turnover tracking on wallets
ALTER TABLE payments.wallets
    ADD COLUMN IF NOT EXISTS required_turnover DECIMAL(18,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS current_turnover  DECIMAL(18,2) NOT NULL DEFAULT 0;
