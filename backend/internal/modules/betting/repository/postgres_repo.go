package repository

import (
	"context"
	"fmt"
	"strings"

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

func (r *postgresBetRepo) CreateBetSlip(ctx context.Context, slip *domain.BetSlip) error {
	if err := r.db.WithContext(ctx).Create(slip).Error; err != nil {
		return fmt.Errorf("betRepo.CreateBetSlip: %w", err)
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

func (r *postgresBetRepo) FindBetSlipsByUser(ctx context.Context, filter *domain.BetFilter) ([]*domain.BetSlip, int64, error) {
	var slips []*domain.BetSlip
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.BetSlip{}).Where("user_id = ?", filter.UserID)

	if filter.Status != "" {
		query = query.Where("status = ?", filter.Status)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("betRepo.FindBetSlipsByUser: count: %w", err)
	}

	offset := (filter.Page - 1) * filter.Limit
	if err := query.Preload("Legs.Match").Offset(offset).Limit(filter.Limit).
		Order("created_at DESC").Find(&slips).Error; err != nil {
		return nil, 0, fmt.Errorf("betRepo.FindBetSlipsByUser: find: %w", err)
	}

	return slips, total, nil
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

func (r *postgresMatchRepo) FindMatchByExternalID(ctx context.Context, externalID string) (*domain.Match, error) {
	var match domain.Match
	if err := r.db.WithContext(ctx).Where("external_id = ?", externalID).First(&match).Error; err != nil {
		return nil, fmt.Errorf("matchRepo.FindMatchByExternalID: %w", err)
	}
	return &match, nil
}

func leagueFilterPattern(value string) string {
	normalized := strings.ToLower(strings.TrimSpace(value))
	switch normalized {
	case "premier league":
		return "%premier league%"
	case "laliga", "la liga":
		return "%la liga%"
	case "ligue 1":
		return "%ligue 1%"
	case "champions league":
		return "%champions league%"
	case "bundesliga":
		return "%bundesliga%"
	case "serie a":
		return "%serie a%"
	default:
		if normalized == "" {
			return ""
		}
		return "%" + normalized + "%"
	}
}

func (r *postgresMatchRepo) ListMatches(ctx context.Context, sport string, leagues []string, status domain.MatchStatus, page, limit int) ([]*domain.Match, int64, error) {
	var matches []*domain.Match
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Match{})
	query = query.Where("external_id IS NOT NULL AND external_id <> ''")

	if sport != "" {
		query = query.Where("sport = ?", sport)
	}
	if len(leagues) > 0 {
		conditions := make([]string, 0, len(leagues))
		args := make([]interface{}, 0, len(leagues))
		for _, league := range leagues {
			pattern := leagueFilterPattern(league)
			if pattern == "" {
				continue
			}
			conditions = append(conditions, "LOWER(league) LIKE ?")
			args = append(args, pattern)
		}
		if len(conditions) > 0 {
			query = query.Where(strings.Join(conditions, " OR "), args...)
		}
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
