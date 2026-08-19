-- +goose Up
CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES users.accounts(id) ON DELETE SET NULL,
    actor_role VARCHAR(40) NOT NULL DEFAULT 'admin',
    action VARCHAR(120) NOT NULL,
    resource_type VARCHAR(80) NOT NULL,
    resource_id VARCHAR(120) NOT NULL DEFAULT '',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at
    ON audit.admin_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_actor_id
    ON audit.admin_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_resource
    ON audit.admin_logs(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_admin_logs_action
    ON audit.admin_logs(action);

-- +goose Down
DROP TABLE IF EXISTS audit.admin_logs;
