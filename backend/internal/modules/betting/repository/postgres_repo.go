package repository

import (
	"context"
	"fmt"

	"betting-app/internal/modules/betting/domain"

	"gorm.io/gorm"
)

type postgresBetRepo struct {
	db *gorm.DB
}

// NewPostgresBetRepo creates a new PostgreSQL bet repository
func NewPostgresBetRepo(db *gorm.DB) domain.BetRepository {
	return &postgresBetRepo{db: db}
}

func (r *postgresBetRepo) CreateBet(ctx context.Context, bet *domain.Bet) error {
	if err := r.db.WithContext(ctx).Create(bet).Error; err != nil {
		return fmt.Errorf("betRepo.CreateBet: %w", err)
	}
	return nil
}

func (r *postgresBetRepo) FindBetByID(ctx context.Context, id string) (*domain.Bet, error) {
	var bet domain.Bet
	if err := r.db.WithContext(ctx).Preload("Match").Where("id = ?", id).First(&bet).Error; err != nil {
		return nil, fmt.Errorf("betRepo.FindBetByID: %w", err)
	}
	return &bet, nil
}

func (r *postgresBetRepo) FindBetsByUser(ctx context.Context, filter *domain.BetFilter) ([]*domain.Bet, int64, error) {
	var bets []*domain.Bet
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Bet{}).Where("user_id = ?", filter.UserID)

	if filter.Status != "" {
		query = query.Where("status = ?", filter.Status)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("betRepo.FindBetsByUser: count: %w", err)
	}

	offset := (filter.Page - 1) * filter.Limit
	if err := query.Preload("Match").Offset(offset).Limit(filter.Limit).
		Order("created_at DESC").Find(&bets).Error; err != nil {
		return nil, 0, fmt.Errorf("betRepo.FindBetsByUser: find: %w", err)
	}

	return bets, total, nil
}

func (r *postgresBetRepo) UpdateBetStatus(ctx context.Context, betID string, status domain.BetStatus) error {
	result := r.db.WithContext(ctx).Model(&domain.Bet{}).
		Where("id = ?", betID).
		Update("status", status)
	if result.Error != nil {
		return fmt.Errorf("betRepo.UpdateBetStatus: %w", result.Error)
	}
	return nil
}

func (r *postgresBetRepo) CancelBet(ctx context.Context, betID string) error {
	return r.UpdateBetStatus(ctx, betID, domain.BetStatusCancelled)
}

// Match repository

type postgresMatchRepo struct {
	db *gorm.DB
}

// NewPostgresMatchRepo creates a new PostgreSQL match repository
func NewPostgresMatchRepo(db *gorm.DB) domain.MatchRepository {
	return &postgresMatchRepo{db: db}
}

func (r *postgresMatchRepo) CreateMatch(ctx context.Context, match *domain.Match) error {
	if err := r.db.WithContext(ctx).Create(match).Error; err != nil {
		return fmt.Errorf("matchRepo.CreateMatch: %w", err)
	}
	return nil
}

func (r *postgresMatchRepo) FindMatchByID(ctx context.Context, id string) (*domain.Match, error) {
	var match domain.Match
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&match).Error; err != nil {
		return nil, fmt.Errorf("matchRepo.FindMatchByID: %w", err)
	}
	return &match, nil
}

func (r *postgresMatchRepo) ListMatches(ctx context.Context, sport string, status domain.MatchStatus, page, limit int) ([]*domain.Match, int64, error) {
	var matches []*domain.Match
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Match{})

	if sport != "" {
		query = query.Where("sport = ?", sport)
	}
	if status != "" {
		query = query.Where("status = ?", status)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("matchRepo.ListMatches: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := query.Offset(offset).Limit(limit).
		Order("start_time ASC").Find(&matches).Error; err != nil {
		return nil, 0, fmt.Errorf("matchRepo.ListMatches: find: %w", err)
	}

	return matches, total, nil
}

func (r *postgresMatchRepo) UpdateMatch(ctx context.Context, match *domain.Match) error {
	if err := r.db.WithContext(ctx).Save(match).Error; err != nil {
		return fmt.Errorf("matchRepo.UpdateMatch: %w", err)
	}
	return nil
}

func (r *postgresMatchRepo) UpdateMatchStatus(ctx context.Context, matchID string, status domain.MatchStatus) error {
	result := r.db.WithContext(ctx).Model(&domain.Match{}).
		Where("id = ?", matchID).
		Update("status", status)
	if result.Error != nil {
		return fmt.Errorf("matchRepo.UpdateMatchStatus: %w", result.Error)
	}
	return nil
}
