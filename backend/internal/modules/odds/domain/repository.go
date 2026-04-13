package domain

import "context"

// OddsRepository defines the interface for odds data access
type OddsRepository interface {
	Upsert(ctx context.Context, odds *Odds) error
	FindByMatchID(ctx context.Context, matchID string) (*Odds, error)
	FindActiveOdds(ctx context.Context, matchIDs []string) ([]*Odds, error)
	SaveHistory(ctx context.Context, history *OddsHistory) error
	GetHistory(ctx context.Context, matchID string, limit int) ([]*OddsHistory, error)
}
