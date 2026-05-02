-- +goose Up
CREATE TABLE IF NOT EXISTS payments.withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL UNIQUE REFERENCES payments.transactions(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL,
    agent_id UUID NOT NULL,
    verification_code_hash VARCHAR(255) NOT NULL,
    code_lookup_hash VARCHAR(128) NOT NULL,
    account_details_encrypted TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    expires_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_agent_id_status
    ON payments.withdrawal_requests(agent_id, status);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_customer_id
    ON payments.withdrawal_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_lookup
    ON payments.withdrawal_requests(agent_id, code_lookup_hash, status);

CREATE TABLE IF NOT EXISTS payments.withdrawal_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES payments.transactions(id) ON DELETE CASCADE,
    withdrawal_request_id UUID REFERENCES payments.withdrawal_requests(id) ON DELETE SET NULL,
    actor_user_id UUID,
    actor_role VARCHAR(20) NOT NULL,
    action VARCHAR(50) NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_audit_logs_transaction_id
    ON payments.withdrawal_audit_logs(transaction_id);

-- +goose Down
DROP TABLE IF EXISTS payments.withdrawal_audit_logs;
DROP TABLE IF EXISTS payments.withdrawal_requests;
