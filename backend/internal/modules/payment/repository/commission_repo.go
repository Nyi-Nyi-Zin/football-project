package repository

import (
	"context"
	"errors"
	"fmt"

	"betting-app/internal/modules/payment/domain"

	"gorm.io/gorm"
)

func (r *postgresTransactionRepo) GetAgentCommissionRule(ctx context.Context, agentID string) (*domain.AgentCommissionRule, error) {
	var rule domain.AgentCommissionRule
	err := r.db.WithContext(ctx).Where("agent_id = ? AND active = ?", agentID, true).First(&rule).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return &domain.AgentCommissionRule{AgentID: agentID, Currency: "MMK", Active: true}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("transactionRepo.GetAgentCommissionRule: %w", err)
	}
	return &rule, nil
}

func (r *postgresTransactionRepo) UpsertAgentCommissionRule(ctx context.Context, rule *domain.AgentCommissionRule) error {
	var existing domain.AgentCommissionRule
	err := r.db.WithContext(ctx).Where("agent_id = ?", rule.AgentID).First(&existing).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		if err := r.db.WithContext(ctx).Create(rule).Error; err != nil {
			return fmt.Errorf("transactionRepo.UpsertAgentCommissionRule: create: %w", err)
		}
		return nil
	}
	if err != nil {
		return fmt.Errorf("transactionRepo.UpsertAgentCommissionRule: find: %w", err)
	}
	if err := r.db.WithContext(ctx).Model(&existing).Updates(map[string]interface{}{
		"deposit_rate_bps": rule.DepositRateBPS,
		"payout_rate_bps":  rule.PayoutRateBPS,
		"currency":         rule.Currency,
		"active":           true,
		"updated_by":       rule.UpdatedBy,
	}).Error; err != nil {
		return fmt.Errorf("transactionRepo.UpsertAgentCommissionRule: update: %w", err)
	}
	return nil
}
