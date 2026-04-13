package domain

import "context"

// NotificationRepository defines the interface for notification data access
type NotificationRepository interface {
	Create(ctx context.Context, notification *Notification) error
	FindByID(ctx context.Context, id string) (*Notification, error)
	FindByUser(ctx context.Context, userID string, unreadOnly bool, page, limit int) ([]*Notification, int64, error)
	MarkAsRead(ctx context.Context, id string) error
	MarkAllAsRead(ctx context.Context, userID string) error
	GetUnreadCount(ctx context.Context, userID string) (int64, error)
	Delete(ctx context.Context, id string) error
}
