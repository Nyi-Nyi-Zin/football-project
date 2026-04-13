package domain

import "context"

// BetRepository defines the interface for bet data access
type BetRepository interface {
	CreateBet(ctx context.Context, bet *Bet) error
	FindBetByID(ctx context.Context, id string) (*Bet, error)
	FindBetsByUser(ctx context.Context, filter *BetFilter) ([]*Bet, int64, error)
	UpdateBetStatus(ctx context.Context, betID string, status BetStatus) error
	CancelBet(ctx context.Context, betID string) error
}

// MatchRepository defines the interface for match data access
type MatchRepository interface {
	CreateMatch(ctx context.Context, match *Match) error
	FindMatchByID(ctx context.Context, id string) (*Match, error)
	ListMatches(ctx context.Context, sport string, status MatchStatus, page, limit int) ([]*Match, int64, error)
	UpdateMatch(ctx context.Context, match *Match) error
	UpdateMatchStatus(ctx context.Context, matchID string, status MatchStatus) error
}

// UserProvider is the interface for cross-module user access (no direct import)
type UserProvider interface {
	GetUserBalance(ctx context.Context, userID string) (float64, error)
	DeductBalance(ctx context.Context, userID string, amount float64) error
	AddBalance(ctx context.Context, userID string, amount float64) error
}
