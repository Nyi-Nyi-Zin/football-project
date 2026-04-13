package domain

import (
	"time"
)

// Odds represents the odds for a match
type Odds struct {
	ID        string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	MatchID   string    `json:"match_id" gorm:"type:uuid;not null;index"`
	HomeOdds  float64   `json:"home_odds" gorm:"type:decimal(10,2);not null"`
	AwayOdds  float64   `json:"away_odds" gorm:"type:decimal(10,2);not null"`
	DrawOdds  float64   `json:"draw_odds" gorm:"type:decimal(10,2)"`
	IsActive  bool      `json:"is_active" gorm:"default:true"`
	Source    string    `json:"source" gorm:"default:'system'"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// TableName overrides the table name
func (Odds) TableName() string {
	return "odds.match_odds"
}

// OddsHistory tracks historical odds changes
type OddsHistory struct {
	ID        string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	MatchID   string    `json:"match_id" gorm:"type:uuid;not null;index"`
	HomeOdds  float64   `json:"home_odds" gorm:"type:decimal(10,2);not null"`
	AwayOdds  float64   `json:"away_odds" gorm:"type:decimal(10,2);not null"`
	DrawOdds  float64   `json:"draw_odds" gorm:"type:decimal(10,2)"`
	Timestamp time.Time `json:"timestamp" gorm:"not null"`
}

// TableName overrides the table name
func (OddsHistory) TableName() string {
	return "odds.odds_history"
}

// OddsUpdate represents a WebSocket odds update message
type OddsUpdate struct {
	Type    string      `json:"type"`
	Payload OddsPayload `json:"payload"`
}

// OddsPayload is the payload for a WebSocket odds update
type OddsPayload struct {
	MatchID   string    `json:"matchId"`
	HomeOdds  float64   `json:"homeOdds"`
	AwayOdds  float64   `json:"awayOdds"`
	DrawOdds  float64   `json:"drawOdds"`
	Timestamp time.Time `json:"timestamp"`
}

// UpdateOddsRequest represents a request to update odds
type UpdateOddsRequest struct {
	MatchID  string  `json:"match_id" validate:"required,uuid"`
	HomeOdds float64 `json:"home_odds" validate:"required,gt=1"`
	AwayOdds float64 `json:"away_odds" validate:"required,gt=1"`
	DrawOdds float64 `json:"draw_odds" validate:"gt=0"`
}
