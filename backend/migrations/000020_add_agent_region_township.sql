-- +goose Up

ALTER TABLE users.accounts
    ADD COLUMN IF NOT EXISTS region VARCHAR(100),
    ADD COLUMN IF NOT EXISTS township VARCHAR(100);

ALTER TABLE payments.withdrawal_requests
    ADD COLUMN IF NOT EXISTS region VARCHAR(100),
    ADD COLUMN IF NOT EXISTS township VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_accounts_agent_region_township
    ON users.accounts(region, township)
    WHERE role = 'agent' AND status = 'active';

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_region_township
    ON payments.withdrawal_requests(region, township);

-- +goose Down

DROP INDEX IF EXISTS idx_withdrawal_requests_region_township;
DROP INDEX IF EXISTS idx_accounts_agent_region_township;
ALTER TABLE payments.withdrawal_requests
    DROP COLUMN IF EXISTS township,
    DROP COLUMN IF EXISTS region;
ALTER TABLE users.accounts
    DROP COLUMN IF EXISTS township,
    DROP COLUMN IF EXISTS region;
