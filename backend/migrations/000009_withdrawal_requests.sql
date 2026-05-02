-- +goose Up
-- Add location column to users.accounts for agents
ALTER TABLE users.accounts ADD COLUMN IF NOT EXISTS location VARCHAR(100);

-- Alter existing withdrawal_requests table to add location and code fields
ALTER TABLE payments.withdrawal_requests ADD COLUMN IF NOT EXISTS location VARCHAR(100);
ALTER TABLE payments.withdrawal_requests ADD COLUMN IF NOT EXISTS code VARCHAR(10);
ALTER TABLE payments.withdrawal_requests ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;
ALTER TABLE payments.withdrawal_requests ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- Add index for location
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_location ON payments.withdrawal_requests(location);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_code ON payments.withdrawal_requests(code);

-- +goose Down
DROP INDEX IF EXISTS idx_withdrawal_requests_code;
DROP INDEX IF EXISTS idx_withdrawal_requests_location;
ALTER TABLE payments.withdrawal_requests DROP COLUMN IF EXISTS cancelled_at;
ALTER TABLE payments.withdrawal_requests DROP COLUMN IF EXISTS approved_at;
ALTER TABLE payments.withdrawal_requests DROP COLUMN IF EXISTS code;
ALTER TABLE payments.withdrawal_requests DROP COLUMN IF EXISTS location;
ALTER TABLE users.accounts DROP COLUMN IF EXISTS location;
