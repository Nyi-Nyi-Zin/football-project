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
	ExternalID  string      `json:"external_id,omitempty" gorm:"index"`
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
	Markets     []Market    `json:"markets,omitempty" gorm:"-"`
    Testing      string     `json:"testing" gorm:"not null"`
}

// TableName overrides the table name
func (Match) TableName() string {
	return "betting.matches"
}

// Bet represents a user's bet
type Bet struct {
	ID              string     `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID          string     `json:"user_id" gorm:"type:uuid;not null;index"`
	MatchID         string     `json:"match_id" gorm:"type:uuid;not null;index"`
	BetType         BetType    `json:"bet_type" gorm:"not null"`
	MarketKey       string     `json:"market_key" gorm:"not null;default:'match_result'"`
	Selection       string     `json:"selection" gorm:"not null"` // e.g., "w1", "x", "w2"
	SelectionLabel  string     `json:"selection_label" gorm:"not null;default:''"`
	Odds            float64    `json:"odds" gorm:"type:decimal(10,2);not null"`
	Stake           float64    `json:"stake" gorm:"type:decimal(18,2);not null"`
	PotentialPayout float64    `json:"potential_payout" gorm:"type:decimal(18,2);not null"`
	Status          BetStatus  `json:"status" gorm:"default:'pending'"`
	SettledAt       *time.Time `json:"settled_at"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	Match           *Match     `json:"match,omitempty" gorm:"foreignKey:MatchID"`
}

// TableName overrides the table name
func (Bet) TableName() string {
	return "betting.bets"
}

type BetSlip struct {
	ID              string     `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID          string     `json:"user_id" gorm:"type:uuid;not null;index"`
	BetType         BetType    `json:"bet_type" gorm:"not null"`
	Stake           float64    `json:"stake" gorm:"type:decimal(18,2);not null"`
	CombinedOdds    float64    `json:"combined_odds" gorm:"type:decimal(10,2);not null"`
	PotentialPayout float64    `json:"potential_payout" gorm:"type:decimal(18,2);not null"`
	Status          BetStatus  `json:"status" gorm:"default:'pending'"`
	SettledAt       *time.Time `json:"settled_at"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
	Legs            []*BetLeg  `json:"legs,omitempty" gorm:"foreignKey:SlipID"`
}

func (BetSlip) TableName() string {
	return "betting.bet_slips"
}

type BetLeg struct {
	ID             string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	SlipID         string    `json:"slip_id" gorm:"type:uuid;not null;index"`
	MatchID        string    `json:"match_id" gorm:"type:uuid;not null;index"`
	MarketKey      string    `json:"market_key" gorm:"not null"`
	SelectionKey   string    `json:"selection_key" gorm:"not null"`
	SelectionLabel string    `json:"selection_label" gorm:"not null"`
	Odds           float64   `json:"odds" gorm:"type:decimal(10,2);not null"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
	Match          *Match    `json:"match,omitempty" gorm:"foreignKey:MatchID"`
}

func (BetLeg) TableName() string {
	return "betting.bet_legs"
}

type Market struct {
	Key        string            `json:"key"`
	Name       string            `json:"name"`
	Selections []MarketSelection `json:"selections"`
}

type MarketSelection struct {
	Key   string  `json:"key"`
	Label string  `json:"label"`
	Odds  float64 `json:"odds"`
}

// PlaceBetRequest represents a request to place a bet
type PlaceBetRequest struct {
	MatchID   string  `json:"match_id" validate:"required,uuid"`
	MarketKey string  `json:"market_key" validate:"required"`
	Selection string  `json:"selection" validate:"required"`
	Stake     float64 `json:"stake" validate:"required,gt=0"`
	BetType   BetType `json:"bet_type" validate:"required,oneof=single accumulate system"`
}

type PlaceBetSlipRequest struct {
	Stake float64              `json:"stake" validate:"required,gt=0"`
	Legs  []PlaceBetLegRequest `json:"legs" validate:"required,min=2,dive"`
}

type PlaceBetLegRequest struct {
	MatchID      string `json:"match_id" validate:"required,uuid"`
	MarketKey    string `json:"market_key" validate:"required"`
	SelectionKey string `json:"selection_key" validate:"required"`
}

// BetFilter represents filters for querying bets
type BetFilter struct {
	UserID string
	Status BetStatus
	Page   int
	Limit  int
}
