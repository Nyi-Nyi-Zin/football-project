-- +goose Up
CREATE TABLE IF NOT EXISTS payments.agent_commission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL UNIQUE REFERENCES users.accounts(id) ON DELETE CASCADE,
    deposit_rate_bps INTEGER NOT NULL DEFAULT 0 CHECK (deposit_rate_bps BETWEEN 0 AND 10000),
    payout_rate_bps INTEGER NOT NULL DEFAULT 0 CHECK (payout_rate_bps BETWEEN 0 AND 10000),
    currency VARCHAR(10) NOT NULL DEFAULT 'MMK',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by UUID REFERENCES users.accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_agent_commission_rules_active ON payments.agent_commission_rules(active);

-- +goose Down
DROP TABLE IF EXISTS payments.agent_commission_rules;
