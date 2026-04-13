package usecase

import (
	"context"
	"fmt"

	"betting-app/internal/modules/betting/domain"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/internal/shared/event"
)

// BettingUseCase handles betting business logic
type BettingUseCase struct {
	betRepo      domain.BetRepository
	matchRepo    domain.MatchRepository
	userProvider domain.UserProvider
	eventBus     *event.Bus
}

// NewBettingUseCase creates a new betting use case
func NewBettingUseCase(
	betRepo domain.BetRepository,
	matchRepo domain.MatchRepository,
	userProvider domain.UserProvider,
	eventBus *event.Bus,
) *BettingUseCase {
	return &BettingUseCase{
		betRepo:      betRepo,
		matchRepo:    matchRepo,
		userProvider: userProvider,
		eventBus:     eventBus,
	}
}

// PlaceBet places a new bet
func (uc *BettingUseCase) PlaceBet(ctx context.Context, userID string, req *domain.PlaceBetRequest) (*domain.Bet, error) {
	// Verify match exists and is accepting bets
	match, err := uc.matchRepo.FindMatchByID(ctx, req.MatchID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Match not found")
	}

	if match.Status != domain.MatchStatusUpcoming && match.Status != domain.MatchStatusLive {
		return nil, apperrors.NewBadRequestError("Match is not accepting bets")
	}

	// Check user balance
	balance, err := uc.userProvider.GetUserBalance(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("usecase.PlaceBet: get balance: %w", err)
	}

	if balance < req.Stake {
		return nil, apperrors.NewBadRequestError("Insufficient balance")
	}

	// TODO: Get current odds from odds module
	odds := 1.85 // placeholder — should come from odds module

	// Calculate potential payout
	potentialPayout := req.Stake * odds

	bet := &domain.Bet{
		UserID:          userID,
		MatchID:         req.MatchID,
		BetType:         req.BetType,
		Selection:       req.Selection,
		Odds:            odds,
		Stake:           req.Stake,
		PotentialPayout: potentialPayout,
		Status:          domain.BetStatusPending,
	}

	// Deduct balance
	if err := uc.userProvider.DeductBalance(ctx, userID, req.Stake); err != nil {
		return nil, fmt.Errorf("usecase.PlaceBet: deduct balance: %w", err)
	}

	// Create bet
	if err := uc.betRepo.CreateBet(ctx, bet); err != nil {
		// Refund balance on failure
		_ = uc.userProvider.AddBalance(ctx, userID, req.Stake)
		return nil, fmt.Errorf("usecase.PlaceBet: create bet: %w", err)
	}

	// Update status to active
	_ = uc.betRepo.UpdateBetStatus(ctx, bet.ID, domain.BetStatusActive)

	// Publish event
	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.BetPlaced,
		Payload: map[string]interface{}{
			"bet_id":  bet.ID,
			"user_id": userID,
			"stake":   req.Stake,
		},
	})

	return bet, nil
}

// GetBet returns a single bet
func (uc *BettingUseCase) GetBet(ctx context.Context, betID string) (*domain.Bet, error) {
	bet, err := uc.betRepo.FindBetByID(ctx, betID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Bet not found")
	}
	return bet, nil
}

// GetUserBets returns paginated bets for a user
func (uc *BettingUseCase) GetUserBets(ctx context.Context, filter *domain.BetFilter) ([]*domain.Bet, int64, error) {
	bets, total, err := uc.betRepo.FindBetsByUser(ctx, filter)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.GetUserBets: %w", err)
	}
	return bets, total, nil
}

// CancelBet cancels a pending bet and refunds the stake
func (uc *BettingUseCase) CancelBet(ctx context.Context, userID, betID string) error {
	bet, err := uc.betRepo.FindBetByID(ctx, betID)
	if err != nil {
		return apperrors.NewNotFoundError("Bet not found")
	}

	if bet.UserID != userID {
		return apperrors.NewForbiddenError("Not authorized to cancel this bet")
	}

	if bet.Status != domain.BetStatusPending && bet.Status != domain.BetStatusActive {
		return apperrors.NewBadRequestError("Bet cannot be cancelled")
	}

	// Cancel the bet
	if err := uc.betRepo.CancelBet(ctx, betID); err != nil {
		return fmt.Errorf("usecase.CancelBet: %w", err)
	}

	// Refund the stake
	if err := uc.userProvider.AddBalance(ctx, userID, bet.Stake); err != nil {
		return fmt.Errorf("usecase.CancelBet: refund: %w", err)
	}

	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.BetCancelled,
		Payload: map[string]interface{}{
			"bet_id":  betID,
			"user_id": userID,
			"refund":  bet.Stake,
		},
	})

	return nil
}

// ListMatches returns available matches
func (uc *BettingUseCase) ListMatches(ctx context.Context, sport string, status domain.MatchStatus, page, limit int) ([]*domain.Match, int64, error) {
	return uc.matchRepo.ListMatches(ctx, sport, status, page, limit)
}

// CreateMatch creates a new match (admin)
func (uc *BettingUseCase) CreateMatch(ctx context.Context, match *domain.Match) error {
	if err := uc.matchRepo.CreateMatch(ctx, match); err != nil {
		return fmt.Errorf("usecase.CreateMatch: %w", err)
	}
	return nil
}
