package repository

import (
	"context"
	"fmt"

	"betting-app/internal/modules/notification/domain"

	"gorm.io/gorm"
)

type postgresNotificationRepo struct {
	db *gorm.DB
}

// NewPostgresNotificationRepo creates a new PostgreSQL notification repository
func NewPostgresNotificationRepo(db *gorm.DB) domain.NotificationRepository {
	return &postgresNotificationRepo{db: db}
}

func (r *postgresNotificationRepo) Create(ctx context.Context, notification *domain.Notification) error {
	if err := r.db.WithContext(ctx).Create(notification).Error; err != nil {
		return fmt.Errorf("notificationRepo.Create: %w", err)
	}
	return nil
}

func (r *postgresNotificationRepo) FindByID(ctx context.Context, id string) (*domain.Notification, error) {
	var notification domain.Notification
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&notification).Error; err != nil {
		return nil, fmt.Errorf("notificationRepo.FindByID: %w", err)
	}
	return &notification, nil
}

func (r *postgresNotificationRepo) FindByUser(ctx context.Context, userID string, unreadOnly bool, page, limit int) ([]*domain.Notification, int64, error) {
	var notifications []*domain.Notification
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Notification{}).Where("user_id = ?", userID)
	if unreadOnly {
		query = query.Where("is_read = false")
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("notificationRepo.FindByUser: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := query.Offset(offset).Limit(limit).Order("created_at DESC").Find(&notifications).Error; err != nil {
		return nil, 0, fmt.Errorf("notificationRepo.FindByUser: find: %w", err)
	}

	return notifications, total, nil
}

func (r *postgresNotificationRepo) MarkAsRead(ctx context.Context, id string) error {
	result := r.db.WithContext(ctx).Model(&domain.Notification{}).
		Where("id = ?", id).Update("is_read", true)
	if result.Error != nil {
		return fmt.Errorf("notificationRepo.MarkAsRead: %w", result.Error)
	}
	return nil
}

func (r *postgresNotificationRepo) MarkAllAsRead(ctx context.Context, userID string) error {
	result := r.db.WithContext(ctx).Model(&domain.Notification{}).
		Where("user_id = ? AND is_read = false", userID).
		Update("is_read", true)
	if result.Error != nil {
		return fmt.Errorf("notificationRepo.MarkAllAsRead: %w", result.Error)
	}
	return nil
}

func (r *postgresNotificationRepo) GetUnreadCount(ctx context.Context, userID string) (int64, error) {
	var count int64
	if err := r.db.WithContext(ctx).Model(&domain.Notification{}).
		Where("user_id = ? AND is_read = false", userID).
		Count(&count).Error; err != nil {
		return 0, fmt.Errorf("notificationRepo.GetUnreadCount: %w", err)
	}
	return count, nil
}

func (r *postgresNotificationRepo) Delete(ctx context.Context, id string) error {
	if err := r.db.WithContext(ctx).Where("id = ?", id).Delete(&domain.Notification{}).Error; err != nil {
		return fmt.Errorf("notificationRepo.Delete: %w", err)
	}
	return nil
}
