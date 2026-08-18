-- +goose Up
CREATE SCHEMA IF NOT EXISTS support;

CREATE TABLE IF NOT EXISTS support.tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES users.accounts(id) ON DELETE CASCADE,
    subject VARCHAR(160) NOT NULL,
    category VARCHAR(60) NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'normal',
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    description TEXT NOT NULL,
    assigned_to UUID REFERENCES users.accounts(id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_requester_updated
    ON support.tickets(requester_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status_priority
    ON support.tickets(status, priority, updated_at DESC);

CREATE TABLE IF NOT EXISTS support.ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES support.tickets(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users.accounts(id) ON DELETE CASCADE,
    author_role VARCHAR(20) NOT NULL,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_ticket_messages_ticket_created
    ON support.ticket_messages(ticket_id, created_at ASC);

-- +goose Down
DROP TABLE IF EXISTS support.ticket_messages;
DROP TABLE IF EXISTS support.tickets;
DROP SCHEMA IF EXISTS support;
