package domain

import "time"

// AgentCommissionRule stores commission rates in basis points (100 bps = 1%).
// Rates are explicit and default to zero until an administrator configures them.
type AgentCommissionRule struct {
	ID             string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	AgentID        string    `json:"agent_id" gorm:"type:uuid;not null;uniqueIndex"`
	DepositRateBPS int       `json:"deposit_rate_bps" gorm:"not null;default:0"`
	PayoutRateBPS  int       `json:"payout_rate_bps" gorm:"not null;default:0"`
	Currency       string    `json:"currency" gorm:"type:varchar(10);not null;default:'MMK'"`
	Active         bool      `json:"active" gorm:"not null;default:true"`
	UpdatedBy      string    `json:"-" gorm:"type:uuid"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

func (AgentCommissionRule) TableName() string { return "payments.agent_commission_rules" }

// UpdateAgentCommissionRuleRequest is restricted to admin users.
type UpdateAgentCommissionRuleRequest struct {
	AgentID        string `json:"agent_id" validate:"required,uuid4"`
	DepositRateBPS int    `json:"deposit_rate_bps" validate:"gte=0,lte=10000"`
	PayoutRateBPS  int    `json:"payout_rate_bps" validate:"gte=0,lte=10000"`
	Currency       string `json:"currency" validate:"omitempty,max=10"`
}

// AgentCommissionStatement extends settled earnings with the configured rates.
type AgentCommissionStatement struct {
	*AgentEarningsSummary
	DepositRateBPS     int     `json:"deposit_rate_bps"`
	PayoutRateBPS      int     `json:"payout_rate_bps"`
	DepositRatePercent float64 `json:"deposit_rate_percent"`
	PayoutRatePercent  float64 `json:"payout_rate_percent"`
	DepositCommission  float64 `json:"deposit_commission"`
	PayoutCommission   float64 `json:"payout_commission"`
	CommissionAmount   float64 `json:"commission_amount"`
	GrossSettlement    float64 `json:"gross_settlement"`
	NetAfterCommission float64 `json:"net_after_commission"`
}
