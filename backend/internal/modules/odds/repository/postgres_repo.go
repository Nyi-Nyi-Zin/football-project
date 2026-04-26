package repository

import (
	"context"
	"fmt"

	"betting-app/internal/modules/odds/domain"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type postgresOddsRepo struct {
	db *gorm.DB
}

// NewPostgresOddsRepo creates a new PostgreSQL odds repository
func NewPostgresOddsRepo(db *gorm.DB) domain.OddsRepository {
	return &postgresOddsRepo{db: db}
}

func (r *postgresOddsRepo) Upsert(ctx context.Context, odds *domain.Odds) error {
	result := r.db.WithContext(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "match_id"}},
		DoUpdates: clause.AssignmentColumns([]string{"home_odds", "away_odds", "draw_odds", "is_active", "source", "updated_at"}),
	}).Create(odds)

	if result.Error != nil {
		return fmt.Errorf("oddsRepo.Upsert: %w", result.Error)
	}
	return nil
}

func (r *postgresOddsRepo) FindByMatchID(ctx context.Context, matchID string) (*domain.Odds, error) {
	var odds domain.Odds
	if err := r.db.WithContext(ctx).Where("match_id = ? AND is_active = true", matchID).First(&odds).Error; err != nil {
		return nil, fmt.Errorf("oddsRepo.FindByMatchID: %w", err)
	}
	return &odds, nil
}

func (r *postgresOddsRepo) FindActiveOdds(ctx context.Context, matchIDs []string) ([]*domain.Odds, error) {
	var oddsList []*domain.Odds
	if err := r.db.WithContext(ctx).Where("match_id IN ? AND is_active = true", matchIDs).Find(&oddsList).Error; err != nil {
		return nil, fmt.Errorf("oddsRepo.FindActiveOdds: %w", err)
	}
	return oddsList, nil
}

func (r *postgresOddsRepo) SaveHistory(ctx context.Context, history *domain.OddsHistory) error {
	if err := r.db.WithContext(ctx).Create(history).Error; err != nil {
		return fmt.Errorf("oddsRepo.SaveHistory: %w", err)
	}
	return nil
}

func (r *postgresOddsRepo) GetHistory(ctx context.Context, matchID string, limit int) ([]*domain.OddsHistory, error) {
	var history []*domain.OddsHistory
	if err := r.db.WithContext(ctx).Where("match_id = ?", matchID).
		Order("timestamp DESC").Limit(limit).Find(&history).Error; err != nil {
		return nil, fmt.Errorf("oddsRepo.GetHistory: %w", err)
	}
	return history, nil
}
