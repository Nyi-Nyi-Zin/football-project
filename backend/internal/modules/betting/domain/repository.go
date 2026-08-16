package domain

import "context"

// BetRepository defines the interface for bet data access
type BetRepository interface {
	CreateBet(ctx context.Context, bet *Bet) error
	CreateBetSlip(ctx context.Context, slip *BetSlip) error
	FindBetByID(ctx context.Context, id string) (*Bet, error)
	FindBetsByUser(ctx context.Context, filter *BetFilter) ([]*Bet, int64, error)
	FindBetSlipsByUser(ctx context.Context, filter *BetFilter) ([]*BetSlip, int64, error)
	UpdateBetStatus(ctx context.Context, betID string, status BetStatus) error
	CancelBet(ctx context.Context, betID string) error
}

// SettlementService applies a single-bet settlement and its wallet ledger entry.
type SettlementService interface {
	SettleBet(ctx context.Context, betID string) (*SettlementDecision, error)
	SettleBetSlip(ctx context.Context, slipID string) (*SettlementDecision, error)
}

// MatchRepository defines the interface for match data access
type MatchRepository interface {
	CreateMatch(ctx context.Context, match *Match) error
	FindMatchByExternalID(ctx context.Context, externalID string) (*Match, error)
	FindMatchByID(ctx context.Context, id string) (*Match, error)
	ListMatches(ctx context.Context, sport string, leagues []string, status MatchStatus, page, limit int) ([]*Match, int64, error)
	UpdateMatch(ctx context.Context, match *Match) error
	UpdateMatchStatus(ctx context.Context, matchID string, status MatchStatus) error
}

// UserProvider is the interface for cross-module user access (no direct import)
type UserProvider interface {
	GetUserBalance(ctx context.Context, userID string) (float64, error)
	DeductBalance(ctx context.Context, userID string, amount float64) error
	AddBalance(ctx context.Context, userID string, amount float64) error
}
