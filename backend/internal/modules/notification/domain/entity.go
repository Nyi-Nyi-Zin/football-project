package domain

import (
	"time"
)

// NotificationType represents the type of notification
type NotificationType string

const (
	NotificationTypeBetResult   NotificationType = "bet_result"
	NotificationTypeDeposit     NotificationType = "deposit"
	NotificationTypeWithdrawal  NotificationType = "withdrawal"
	NotificationTypePromotion   NotificationType = "promotion"
	NotificationTypeSystem      NotificationType = "system"
	NotificationTypeOddsAlert   NotificationType = "odds_alert"
)

// Notification represents a user notification
type Notification struct {
	ID        string           `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID    string           `json:"user_id" gorm:"type:uuid;not null;index"`
	Type      NotificationType `json:"type" gorm:"not null"`
	Title     string           `json:"title" gorm:"not null"`
	Message   string           `json:"message" gorm:"not null"`
	Data      string           `json:"data" gorm:"type:jsonb"` // additional JSON payload
	IsRead    bool             `json:"is_read" gorm:"default:false"`
	CreatedAt time.Time        `json:"created_at"`
	UpdatedAt time.Time        `json:"updated_at"`
}

// TableName overrides the table name
func (Notification) TableName() string {
	return "notifications.notifications"
}

// SendNotificationRequest represents a request to send a notification
type SendNotificationRequest struct {
	UserID  string           `json:"user_id" validate:"required,uuid"`
	Type    NotificationType `json:"type" validate:"required"`
	Title   string           `json:"title" validate:"required"`
	Message string           `json:"message" validate:"required"`
	Data    string           `json:"data"`
}
