package usecase

import (
	"context"
	"errors"
	"testing"

	bettingDomain "betting-app/internal/modules/betting/domain"
	oddsDomain "betting-app/internal/modules/odds/domain"
	"betting-app/internal/shared/event"
)

type idempotencyBetRepo struct {
	bet         *bettingDomain.Bet
	createCalls int
}

func (r *idempotencyBetRepo) CreateBet(_ context.Context, bet *bettingDomain.Bet) error {
	r.createCalls++
	if bet.ID == "" {
		bet.ID = "bet-1"
	}
	r.bet = bet
	return nil
}

func (r *idempotencyBetRepo) CreateBetSlip(context.Context, *bettingDomain.BetSlip) error {
	return errors.New("not used")
}

func (r *idempotencyBetRepo) FindBetByIdempotencyKey(_ context.Context, userID, key string) (*bettingDomain.Bet, error) {
	if r.bet != nil && r.bet.UserID == userID && r.bet.IdempotencyKey == key {
		return r.bet, nil
	}
	return nil, nil
}

func (r *idempotencyBetRepo) FindBetSlipByIdempotencyKey(context.Context, string, string) (*bettingDomain.BetSlip, error) {
	return nil, nil
}

func (r *idempotencyBetRepo) FindBetByID(context.Context, string) (*bettingDomain.Bet, error) {
	return r.bet, nil
}

func (r *idempotencyBetRepo) FindBetsByUser(context.Context, *bettingDomain.BetFilter) ([]*bettingDomain.Bet, int64, error) {
	return nil, 0, nil
}

func (r *idempotencyBetRepo) FindBetSlipsByUser(context.Context, *bettingDomain.BetFilter) ([]*bettingDomain.BetSlip, int64, error) {
	return nil, 0, nil
}

func (r *idempotencyBetRepo) UpdateBetStatus(_ context.Context, betID string, status bettingDomain.BetStatus) error {
	if r.bet != nil && r.bet.ID == betID {
		r.bet.Status = status
	}
	return nil
}

func (r *idempotencyBetRepo) CancelBet(context.Context, string) error { return nil }

type idempotencyMatchRepo struct{}

func (idempotencyMatchRepo) CreateMatch(context.Context, *bettingDomain.Match) error { return nil }
func (idempotencyMatchRepo) FindMatchByExternalID(context.Context, string) (*bettingDomain.Match, error) {
	return nil, nil
}
func (idempotencyMatchRepo) FindMatchByID(context.Context, string) (*bettingDomain.Match, error) {
	return &bettingDomain.Match{ID: "match-1", Status: bettingDomain.MatchStatusUpcoming}, nil
}
func (idempotencyMatchRepo) ListMatches(context.Context, string, []string, bettingDomain.MatchStatus, int, int) ([]*bettingDomain.Match, int64, error) {
	return nil, 0, nil
}
func (idempotencyMatchRepo) UpdateMatch(context.Context, *bettingDomain.Match) error { return nil }
func (idempotencyMatchRepo) UpdateMatchStatus(context.Context, string, bettingDomain.MatchStatus) error {
	return nil
}

type idempotencyOddsRepo struct{}

func (idempotencyOddsRepo) Upsert(context.Context, *oddsDomain.Odds) error { return nil }
func (idempotencyOddsRepo) FindByMatchID(context.Context, string) (*oddsDomain.Odds, error) {
	return &oddsDomain.Odds{HomeOdds: 2, DrawOdds: 3, AwayOdds: 2, IsActive: true}, nil
}
func (idempotencyOddsRepo) FindActiveOdds(context.Context, []string) ([]*oddsDomain.Odds, error) {
	return nil, nil
}
func (idempotencyOddsRepo) SaveHistory(context.Context, *oddsDomain.OddsHistory) error { return nil }
func (idempotencyOddsRepo) GetHistory(context.Context, string, int) ([]*oddsDomain.OddsHistory, error) {
	return nil, nil
}

type idempotencyUserProvider struct {
	balance     float64
	deductCalls int
}

func (p *idempotencyUserProvider) GetUserBalance(context.Context, string) (float64, error) {
	return p.balance, nil
}
func (p *idempotencyUserProvider) DeductBalance(_ context.Context, _ string, amount float64) error {
	p.deductCalls++
	p.balance -= amount
	return nil
}
func (p *idempotencyUserProvider) AddBalance(_ context.Context, _ string, amount float64) error {
	p.balance += amount
	return nil
}

func TestPlaceBetReplaysIdempotencyKeyWithoutSecondDebit(t *testing.T) {
	repo := &idempotencyBetRepo{}
	wallet := &idempotencyUserProvider{balance: 10_000}
	uc := NewBettingUseCase(
		repo,
		idempotencyMatchRepo{},
		idempotencyOddsRepo{},
		wallet,
		event.NewBus(),
	)

	req := &bettingDomain.PlaceBetRequest{
		MatchID:        "match-1",
		MarketKey:      "match_result",
		Selection:      "w1",
		Stake:          500,
		BetType:        bettingDomain.BetTypeSingle,
		IdempotencyKey: "customer-submit-1",
	}

	first, err := uc.PlaceBet(context.Background(), "user-1", req)
	if err != nil {
		t.Fatalf("first placement failed: %v", err)
	}
	if first.IdempotencyKey != req.IdempotencyKey {
		t.Fatalf("expected idempotency key %q, got %q", req.IdempotencyKey, first.IdempotencyKey)
	}

	second, err := uc.PlaceBet(context.Background(), "user-1", req)
	if err != nil {
		t.Fatalf("retry placement failed: %v", err)
	}
	if second.ID != first.ID {
		t.Fatalf("expected retry to return bet %q, got %q", first.ID, second.ID)
	}
	if repo.createCalls != 1 {
		t.Fatalf("expected one bet row, got %d", repo.createCalls)
	}
	if wallet.deductCalls != 1 {
		t.Fatalf("expected one wallet debit, got %d", wallet.deductCalls)
	}
	if wallet.balance != 9_500 {
		t.Fatalf("expected balance 9500, got %.2f", wallet.balance)
	}
}
