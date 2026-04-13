package usecase

import (
	"context"
	"fmt"
	"time"

	"betting-app/internal/modules/odds/domain"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/internal/shared/event"
)

// OddsUseCase handles odds business logic
type OddsUseCase struct {
	repo     domain.OddsRepository
	eventBus *event.Bus
}

// NewOddsUseCase creates a new odds use case
func NewOddsUseCase(repo domain.OddsRepository, eventBus *event.Bus) *OddsUseCase {
	return &OddsUseCase{
		repo:     repo,
		eventBus: eventBus,
	}
}

// UpdateOdds updates the odds for a match
func (uc *OddsUseCase) UpdateOdds(ctx context.Context, req *domain.UpdateOddsRequest) (*domain.Odds, error) {
	odds := &domain.Odds{
		MatchID:  req.MatchID,
		HomeOdds: req.HomeOdds,
		AwayOdds: req.AwayOdds,
		DrawOdds: req.DrawOdds,
		IsActive: true,
		Source:   "system",
	}

	if err := uc.repo.Upsert(ctx, odds); err != nil {
		return nil, fmt.Errorf("usecase.UpdateOdds: %w", err)
	}

	// Save to history
	history := &domain.OddsHistory{
		MatchID:   req.MatchID,
		HomeOdds:  req.HomeOdds,
		AwayOdds:  req.AwayOdds,
		DrawOdds:  req.DrawOdds,
		Timestamp: time.Now(),
	}
	_ = uc.repo.SaveHistory(ctx, history)

	// Publish odds update event
	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.OddsUpdated,
		Payload: domain.OddsPayload{
			MatchID:   req.MatchID,
			HomeOdds:  req.HomeOdds,
			AwayOdds:  req.AwayOdds,
			DrawOdds:  req.DrawOdds,
			Timestamp: time.Now(),
		},
	})

	return odds, nil
}

// GetOdds returns the current odds for a match
func (uc *OddsUseCase) GetOdds(ctx context.Context, matchID string) (*domain.Odds, error) {
	odds, err := uc.repo.FindByMatchID(ctx, matchID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Odds not found for this match")
	}
	return odds, nil
}

// GetBulkOdds returns odds for multiple matches
func (uc *OddsUseCase) GetBulkOdds(ctx context.Context, matchIDs []string) ([]*domain.Odds, error) {
	odds, err := uc.repo.FindActiveOdds(ctx, matchIDs)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetBulkOdds: %w", err)
	}
	return odds, nil
}

// GetOddsHistory returns historical odds for a match
func (uc *OddsUseCase) GetOddsHistory(ctx context.Context, matchID string, limit int) ([]*domain.OddsHistory, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	history, err := uc.repo.GetHistory(ctx, matchID, limit)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetOddsHistory: %w", err)
	}
	return history, nil
}
