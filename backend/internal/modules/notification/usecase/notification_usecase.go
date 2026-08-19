package usecase

import (
	"context"
	"fmt"
	"strings"

	"betting-app/internal/modules/notification/domain"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/internal/shared/event"
)

// NotificationUseCase handles notification business logic
type NotificationUseCase struct {
	repo     domain.NotificationRepository
	eventBus *event.Bus
}

// NewNotificationUseCase creates a new notification use case
func NewNotificationUseCase(repo domain.NotificationRepository, eventBus *event.Bus) *NotificationUseCase {
	return &NotificationUseCase{
		repo:     repo,
		eventBus: eventBus,
	}
}

// Send creates and sends a notification
func (uc *NotificationUseCase) Send(ctx context.Context, req *domain.SendNotificationRequest) (*domain.Notification, error) {
	data := strings.TrimSpace(req.Data)
	if data == "" {
		data = "{}"
	}
	notification := &domain.Notification{
		UserID:  req.UserID,
		Type:    req.Type,
		Title:   req.Title,
		Message: req.Message,
		Data:    data,
		IsRead:  false,
	}

	if err := uc.repo.Create(ctx, notification); err != nil {
		return nil, fmt.Errorf("usecase.Send: %w", err)
	}

	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.NotificationSent,
		Payload: map[string]interface{}{
			"notification_id": notification.ID,
			"user_id":         req.UserID,
			"type":            req.Type,
		},
	})

	return notification, nil
}

// GetUserNotifications returns paginated notifications for a user
func (uc *NotificationUseCase) GetUserNotifications(ctx context.Context, userID string, unreadOnly bool, page, limit int) ([]*domain.Notification, int64, error) {
	notifications, total, err := uc.repo.FindByUser(ctx, userID, unreadOnly, page, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.GetUserNotifications: %w", err)
	}
	return notifications, total, nil
}

// MarkAsRead marks a notification as read
func (uc *NotificationUseCase) MarkAsRead(ctx context.Context, notificationID string) error {
	if err := uc.repo.MarkAsRead(ctx, notificationID); err != nil {
		return fmt.Errorf("usecase.MarkAsRead: %w", err)
	}
	return nil
}

// MarkAllAsRead marks all notifications as read for a user
func (uc *NotificationUseCase) MarkAllAsRead(ctx context.Context, userID string) error {
	if err := uc.repo.MarkAllAsRead(ctx, userID); err != nil {
		return fmt.Errorf("usecase.MarkAllAsRead: %w", err)
	}
	return nil
}

// GetUnreadCount returns the count of unread notifications
func (uc *NotificationUseCase) GetUnreadCount(ctx context.Context, userID string) (int64, error) {
	count, err := uc.repo.GetUnreadCount(ctx, userID)
	if err != nil {
		return 0, fmt.Errorf("usecase.GetUnreadCount: %w", err)
	}
	return count, nil
}

// Delete deletes a notification
func (uc *NotificationUseCase) Delete(ctx context.Context, notificationID string) error {
	_, err := uc.repo.FindByID(ctx, notificationID)
	if err != nil {
		return apperrors.NewNotFoundError("Notification not found")
	}
	return uc.repo.Delete(ctx, notificationID)
}
