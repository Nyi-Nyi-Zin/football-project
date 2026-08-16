package usecase

import (
	"context"
	"fmt"
	"strings"

	"betting-app/internal/modules/betting/domain"
	oddsDomain "betting-app/internal/modules/odds/domain"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/internal/shared/event"
)

// BettingUseCase handles betting business logic
type BettingUseCase struct {
	betRepo           domain.BetRepository
	matchRepo         domain.MatchRepository
	oddsRepo          oddsDomain.OddsRepository
	userProvider      domain.UserProvider
	eventBus          *event.Bus
	settlementService domain.SettlementService
}

// NewBettingUseCase creates a new betting use case
func NewBettingUseCase(
	betRepo domain.BetRepository,
	matchRepo domain.MatchRepository,
	oddsRepo oddsDomain.OddsRepository,
	userProvider domain.UserProvider,
	eventBus *event.Bus,
	settlementServices ...domain.SettlementService,
) *BettingUseCase {
	var settlementService domain.SettlementService
	if len(settlementServices) > 0 {
		settlementService = settlementServices[0]
	}
	return &BettingUseCase{
		betRepo:           betRepo,
		matchRepo:         matchRepo,
		oddsRepo:          oddsRepo,
		userProvider:      userProvider,
		eventBus:          eventBus,
		settlementService: settlementService,
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

	matchMarkets, err := uc.getMatchMarkets(ctx, req.MatchID)
	if err != nil {
		return nil, err
	}
	selection := findSelection(matchMarkets, req.MarketKey, req.Selection)
	if selection == nil {
		return nil, apperrors.NewBadRequestError("Selected market option is not available")
	}

	// Calculate potential payout
	potentialPayout := req.Stake * selection.Odds

	bet := &domain.Bet{
		UserID:          userID,
		MatchID:         req.MatchID,
		BetType:         req.BetType,
		MarketKey:       req.MarketKey,
		Selection:       req.Selection,
		SelectionLabel:  selection.Label,
		Odds:            selection.Odds,
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

func (uc *BettingUseCase) PlaceBetSlip(ctx context.Context, userID string, req *domain.PlaceBetSlipRequest) (*domain.BetSlip, error) {
	if len(req.Legs) < 2 {
		return nil, apperrors.NewBadRequestError("At least 2 selections are required")
	}

	balance, err := uc.userProvider.GetUserBalance(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("usecase.PlaceBetSlip: get balance: %w", err)
	}
	if balance < req.Stake {
		return nil, apperrors.NewBadRequestError("Insufficient balance")
	}

	combinedOdds := 1.0
	legs := make([]*domain.BetLeg, 0, len(req.Legs))

	for _, legReq := range req.Legs {
		match, err := uc.matchRepo.FindMatchByID(ctx, legReq.MatchID)
		if err != nil {
			return nil, apperrors.NewNotFoundError("Match not found")
		}
		if match.Status != domain.MatchStatusUpcoming && match.Status != domain.MatchStatusLive {
			return nil, apperrors.NewBadRequestError("One of the selected matches is not accepting bets")
		}

		markets, err := uc.getMatchMarkets(ctx, legReq.MatchID)
		if err != nil {
			return nil, err
		}
		selection := findSelection(markets, legReq.MarketKey, legReq.SelectionKey)
		if selection == nil {
			return nil, apperrors.NewBadRequestError("One of the selected market options is not available")
		}

		combinedOdds *= selection.Odds
		legs = append(legs, &domain.BetLeg{
			MatchID:        legReq.MatchID,
			MarketKey:      legReq.MarketKey,
			SelectionKey:   legReq.SelectionKey,
			SelectionLabel: selection.Label,
			Odds:           selection.Odds,
		})
	}

	slip := &domain.BetSlip{
		UserID:          userID,
		BetType:         domain.BetTypeAccumulate,
		Stake:           req.Stake,
		CombinedOdds:    combinedOdds,
		PotentialPayout: req.Stake * combinedOdds,
		Status:          domain.BetStatusPending,
		Legs:            legs,
	}

	if err := uc.userProvider.DeductBalance(ctx, userID, req.Stake); err != nil {
		return nil, fmt.Errorf("usecase.PlaceBetSlip: deduct balance: %w", err)
	}

	if err := uc.betRepo.CreateBetSlip(ctx, slip); err != nil {
		_ = uc.userProvider.AddBalance(ctx, userID, req.Stake)
		return nil, fmt.Errorf("usecase.PlaceBetSlip: create slip: %w", err)
	}

	return slip, nil
}

// SettleBet applies a single-bet settlement and wallet ledger entry atomically.
func (uc *BettingUseCase) SettleBet(ctx context.Context, betID string) (*domain.SettlementDecision, error) {
	if uc.settlementService == nil {
		return nil, fmt.Errorf("settlement service is not configured")
	}
	return uc.settlementService.SettleBet(ctx, betID)
}

// SettleBetSlip applies an accumulator settlement and wallet ledger entry atomically.
func (uc *BettingUseCase) SettleBetSlip(ctx context.Context, slipID string) (*domain.SettlementDecision, error) {
	if uc.settlementService == nil {
		return nil, fmt.Errorf("settlement service is not configured")
	}
	return uc.settlementService.SettleBetSlip(ctx, slipID)
}

// PreviewBetSettlement evaluates the outcome of a bet without mutating any
// wallet or bet state. An admin settlement worker can later apply the same
// decision inside a database transaction.
func (uc *BettingUseCase) PreviewBetSettlement(ctx context.Context, betID string) (*domain.SettlementDecision, error) {
	bet, err := uc.betRepo.FindBetByID(ctx, betID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Bet not found")
	}
	match := bet.Match
	if match == nil {
		match, err = uc.matchRepo.FindMatchByID(ctx, bet.MatchID)
		if err != nil {
			return nil, apperrors.NewNotFoundError("Match not found")
		}
	}
	decision, err := domain.EvaluateBetSettlement(match, bet)
	if err != nil {
		return nil, apperrors.NewBadRequestError(err.Error())
	}
	return &decision, nil
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

func (uc *BettingUseCase) GetUserBetSlips(ctx context.Context, filter *domain.BetFilter) ([]*domain.BetSlip, int64, error) {
	slips, total, err := uc.betRepo.FindBetSlipsByUser(ctx, filter)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.GetUserBetSlips: %w", err)
	}
	return slips, total, nil
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
func (uc *BettingUseCase) ListMatches(ctx context.Context, sport string, leagues []string, status domain.MatchStatus, page, limit int) ([]*domain.Match, int64, error) {
	matches, total, err := uc.matchRepo.ListMatches(ctx, sport, leagues, status, page, limit)
	if err != nil {
		return nil, 0, err
	}
	for _, match := range matches {
		// Always attach markets; fall back to balanced odds when real odds are missing.
		markets, _ := uc.getMatchMarkets(ctx, match.ID)
		match.Markets = markets
	}
	return matches, total, nil
}

// CreateMatch creates a new match (admin)
func (uc *BettingUseCase) CreateMatch(ctx context.Context, match *domain.Match) error {
	if err := uc.matchRepo.CreateMatch(ctx, match); err != nil {
		return fmt.Errorf("usecase.CreateMatch: %w", err)
	}
	return nil
}

func (uc *BettingUseCase) getMatchMarkets(ctx context.Context, matchID string) ([]domain.Market, error) {
	odds, err := uc.oddsRepo.FindByMatchID(ctx, matchID)
	if err != nil {
		// No odds in DB yet – return fallback balanced markets so the match is
		// still selectable. The validate step in PlaceBet will re-check odds.
		return buildFallbackMarkets(), nil
	}

	markets := buildMarkets(odds)
	if len(markets) == 0 {
		return buildFallbackMarkets(), nil
	}
	return markets, nil
}

func NormalizeLeagueFilters(leagues []string) []string {
	normalized := make([]string, 0, len(leagues))
	seen := map[string]struct{}{}
	for _, league := range leagues {
		trimmed := strings.TrimSpace(league)
		if trimmed == "" {
			continue
		}
		if _, exists := seen[trimmed]; exists {
			continue
		}
		seen[trimmed] = struct{}{}
		normalized = append(normalized, trimmed)
	}
	return normalized
}
