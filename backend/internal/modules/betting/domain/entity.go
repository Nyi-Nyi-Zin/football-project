package domain

import (
	"time"
)

// BetStatus represents the status of a bet
type BetStatus string

const (
	BetStatusPending   BetStatus = "pending"
	BetStatusActive    BetStatus = "active"
	BetStatusWon       BetStatus = "won"
	BetStatusLost      BetStatus = "lost"
	BetStatusCancelled BetStatus = "cancelled"
	BetStatusSettled   BetStatus = "settled"
)

// BetType represents the type of bet
type BetType string

const (
	BetTypeSingle     BetType = "single"
	BetTypeAccumulate BetType = "accumulate"
	BetTypeSystem     BetType = "system"
)

// MatchStatus represents the status of a match
type MatchStatus string

const (
	MatchStatusUpcoming  MatchStatus = "upcoming"
	MatchStatusLive      MatchStatus = "live"
	MatchStatusFinished  MatchStatus = "finished"
	MatchStatusCancelled MatchStatus = "cancelled"
)

// Match represents a sporting event
type Match struct {
	ID          string      `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	Sport       string      `json:"sport" gorm:"not null;index"`
	League      string      `json:"league" gorm:"not null"`
	HomeTeam    string      `json:"home_team" gorm:"not null"`
	AwayTeam    string      `json:"away_team" gorm:"not null"`
	StartTime   time.Time   `json:"start_time" gorm:"not null;index"`
	Status      MatchStatus `json:"status" gorm:"default:'upcoming'"`
	HomeScore   *int        `json:"home_score"`
	AwayScore   *int        `json:"away_score"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
}

// TableName overrides the table name
func (Match) TableName() string {
	return "betting.matches"
}

// Bet represents a user's bet
type Bet struct {
	ID             string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID         string    `json:"user_id" gorm:"type:uuid;not null;index"`
	MatchID        string    `json:"match_id" gorm:"type:uuid;not null;index"`
	BetType        BetType   `json:"bet_type" gorm:"not null"`
	Selection      string    `json:"selection" gorm:"not null"` // e.g., "home", "away", "draw"
	Odds           float64   `json:"odds" gorm:"type:decimal(10,2);not null"`
	Stake          float64   `json:"stake" gorm:"type:decimal(18,2);not null"`
	PotentialPayout float64  `json:"potential_payout" gorm:"type:decimal(18,2);not null"`
	Status         BetStatus `json:"status" gorm:"default:'pending'"`
	SettledAt      *time.Time `json:"settled_at"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
	Match          *Match    `json:"match,omitempty" gorm:"foreignKey:MatchID"`
}

// TableName overrides the table name
func (Bet) TableName() string {
	return "betting.bets"
}

// PlaceBetRequest represents a request to place a bet
type PlaceBetRequest struct {
	MatchID   string  `json:"match_id" validate:"required,uuid"`
	Selection string  `json:"selection" validate:"required,oneof=home away draw"`
	Stake     float64 `json:"stake" validate:"required,gt=0"`
	BetType   BetType `json:"bet_type" validate:"required,oneof=single accumulate system"`
}

// BetFilter represents filters for querying bets
type BetFilter struct {
	UserID string
	Status BetStatus
	Page   int
	Limit  int
}
