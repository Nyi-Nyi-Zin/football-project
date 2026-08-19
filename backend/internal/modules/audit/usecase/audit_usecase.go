package usecase

import (
	"context"
	"strings"

	"betting-app/internal/modules/audit/domain"
)

type AuditUseCase struct {
	repo domain.AuditRepository
}

func NewAuditUseCase(repo domain.AuditRepository) *AuditUseCase {
	return &AuditUseCase{repo: repo}
}

func (uc *AuditUseCase) List(ctx context.Context, filter domain.AuditFilter) ([]*domain.AuditLog, int64, error) {
	filter.ActorID = strings.TrimSpace(filter.ActorID)
	filter.Action = strings.TrimSpace(filter.Action)
	filter.ResourceType = strings.TrimSpace(filter.ResourceType)
	if filter.Page < 1 {
		filter.Page = 1
	}
	if filter.Limit < 1 || filter.Limit > 100 {
		filter.Limit = 25
	}
	return uc.repo.List(ctx, filter)
}
