package repository

import (
	"context"
	"fmt"

	"betting-app/internal/modules/audit/domain"

	"gorm.io/gorm"
)

type postgresAuditRepo struct {
	db *gorm.DB
}

func NewPostgresAuditRepo(db *gorm.DB) domain.AuditRepository {
	return &postgresAuditRepo{db: db}
}

func (r *postgresAuditRepo) Create(ctx context.Context, log *domain.AuditLog) error {
	if err := r.db.WithContext(ctx).Create(log).Error; err != nil {
		return fmt.Errorf("auditRepo.Create: %w", err)
	}
	return nil
}

func (r *postgresAuditRepo) List(ctx context.Context, filter domain.AuditFilter) ([]*domain.AuditLog, int64, error) {
	page := filter.Page
	if page < 1 {
		page = 1
	}
	limit := filter.Limit
	if limit < 1 || limit > 100 {
		limit = 25
	}

	query := r.db.WithContext(ctx).Model(&domain.AuditLog{})
	if filter.ActorID != "" {
		query = query.Where("actor_id = ?", filter.ActorID)
	}
	if filter.Action != "" {
		query = query.Where("action = ?", filter.Action)
	}
	if filter.ResourceType != "" {
		query = query.Where("resource_type = ?", filter.ResourceType)
	}

	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("auditRepo.List: count: %w", err)
	}

	var logs []*domain.AuditLog
	if err := query.Order("created_at DESC").Offset((page - 1) * limit).Limit(limit).Find(&logs).Error; err != nil {
		return nil, 0, fmt.Errorf("auditRepo.List: find: %w", err)
	}
	return logs, total, nil
}
