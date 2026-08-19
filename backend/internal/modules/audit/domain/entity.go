package domain

import (
	"context"
	"time"
)

// AuditLog records an administrative action that changes platform state.
// Metadata must always contain valid JSON so PostgreSQL JSONB storage is safe.
type AuditLog struct {
	ID           string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	ActorID      string    `json:"actor_id" gorm:"type:uuid;index"`
	ActorRole    string    `json:"actor_role" gorm:"not null;default:'admin'"`
	Action       string    `json:"action" gorm:"not null;index"`
	ResourceType string    `json:"resource_type" gorm:"not null;index"`
	ResourceID   string    `json:"resource_id" gorm:"index"`
	Metadata     string    `json:"metadata" gorm:"type:jsonb;not null;default:'{}'"`
	CreatedAt    time.Time `json:"created_at" gorm:"autoCreateTime;index"`
}

func (AuditLog) TableName() string {
	return "audit.admin_logs"
}

type AuditFilter struct {
	ActorID      string
	Action       string
	ResourceType string
	Page         int
	Limit        int
}

type AuditRepository interface {
	Create(ctx context.Context, log *AuditLog) error
	List(ctx context.Context, filter AuditFilter) ([]*AuditLog, int64, error)
}
