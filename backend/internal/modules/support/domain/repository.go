package domain

import (
	"context"
	"time"
)

// SupportRepository provides persistence for support tickets and replies.
type SupportRepository interface {
	CreateTicket(ctx context.Context, ticket *SupportTicket) error
	FindTicket(ctx context.Context, ticketID string) (*SupportTicket, error)
	ListTickets(ctx context.Context, requesterID, role string, page, limit int) ([]*SupportTicket, int64, error)
	CreateMessage(ctx context.Context, message *SupportMessage) error
	ListMessages(ctx context.Context, ticketID string) ([]*SupportMessage, error)
	UpdateStatus(ctx context.Context, ticketID string, status TicketStatus, assignedTo *string, resolvedAt *time.Time) error
}
