package domain

import "time"

// TicketStatus tracks the lifecycle of a support request.
type TicketStatus string

const (
	TicketStatusOpen       TicketStatus = "open"
	TicketStatusInProgress TicketStatus = "in_progress"
	TicketStatusResolved   TicketStatus = "resolved"
	TicketStatusClosed     TicketStatus = "closed"
)

// TicketPriority controls operational triage order.
type TicketPriority string

const (
	TicketPriorityLow    TicketPriority = "low"
	TicketPriorityNormal TicketPriority = "normal"
	TicketPriorityHigh   TicketPriority = "high"
	TicketPriorityUrgent TicketPriority = "urgent"
)

// SupportTicket is an authenticated user's support request.
type SupportTicket struct {
	ID          string         `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	RequesterID string         `json:"requester_id" gorm:"type:uuid;not null;index"`
	Subject     string         `json:"subject" gorm:"type:varchar(160);not null"`
	Category    string         `json:"category" gorm:"type:varchar(60);not null"`
	Priority    TicketPriority `json:"priority" gorm:"type:varchar(20);not null;default:'normal'"`
	Status      TicketStatus   `json:"status" gorm:"type:varchar(20);not null;default:'open';index"`
	Description string         `json:"description" gorm:"type:text;not null"`
	AssignedTo  *string        `json:"assigned_to,omitempty" gorm:"type:uuid;index"`
	ResolvedAt  *time.Time     `json:"resolved_at,omitempty"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
}

func (SupportTicket) TableName() string { return "support.tickets" }

// SupportMessage is a reply in a support ticket thread.
type SupportMessage struct {
	ID         string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	TicketID   string    `json:"ticket_id" gorm:"type:uuid;not null;index"`
	AuthorID   string    `json:"author_id" gorm:"type:uuid;not null;index"`
	AuthorRole string    `json:"author_role" gorm:"type:varchar(20);not null"`
	Body       string    `json:"body" gorm:"type:text;not null"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

func (SupportMessage) TableName() string { return "support.ticket_messages" }

// CreateTicketRequest is the public ticket creation payload.
type CreateTicketRequest struct {
	Subject     string         `json:"subject" validate:"required,min=4,max=160"`
	Category    string         `json:"category" validate:"required,max=60"`
	Priority    TicketPriority `json:"priority" validate:"omitempty,oneof=low normal high urgent"`
	Description string         `json:"description" validate:"required,min=10,max=5000"`
}

// AddMessageRequest is the public ticket reply payload.
type AddMessageRequest struct {
	Body string `json:"body" validate:"required,min=1,max=5000"`
}

// UpdateStatusRequest is restricted to support staff.
type UpdateStatusRequest struct {
	Status TicketStatus `json:"status" validate:"required,oneof=open in_progress resolved closed"`
}
