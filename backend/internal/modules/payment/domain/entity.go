package domain

import (
	"time"
)

// TransactionType represents the type of financial transaction
type TransactionType string

const (
	TransactionDeposit  TransactionType = "deposit"
	TransactionWithdraw TransactionType = "withdraw"
	TransactionBetStake TransactionType = "bet_stake"
	TransactionBetWin   TransactionType = "bet_win"
	TransactionRefund   TransactionType = "refund"
)

// TransactionStatus represents the status of a transaction
type TransactionStatus string

const (
	TransactionPending   TransactionStatus = "pending"
	TransactionCompleted TransactionStatus = "completed"
	TransactionFailed    TransactionStatus = "failed"
	TransactionCancelled TransactionStatus = "cancelled"
)

// Transaction represents a financial transaction
type Transaction struct {
	ID             string            `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID         string            `json:"user_id" gorm:"type:uuid;not null;index"`
	Type           TransactionType   `json:"type" gorm:"not null"`
	Amount         float64           `json:"amount" gorm:"type:decimal(18,2);not null"`
	Currency       string            `json:"currency" gorm:"default:'USD'"`
	Status         TransactionStatus `json:"status" gorm:"default:'pending'"`
	IdempotencyKey string            `json:"idempotency_key" gorm:"uniqueIndex"`
	Reference      string            `json:"reference"` // external payment reference
	Description    string            `json:"description"`
	BalanceBefore  float64           `json:"balance_before" gorm:"type:decimal(18,2)"`
	BalanceAfter   float64           `json:"balance_after" gorm:"type:decimal(18,2)"`
	CreatedAt      time.Time         `json:"created_at"`
	UpdatedAt      time.Time         `json:"updated_at"`
}

// TableName overrides the table name
func (Transaction) TableName() string {
	return "payments.transactions"
}

// Wallet represents a user's wallet
type Wallet struct {
	ID        string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID    string    `json:"user_id" gorm:"type:uuid;uniqueIndex;not null"`
	Balance   float64   `json:"balance" gorm:"type:decimal(18,2);default:0"`
	Currency  string    `json:"currency" gorm:"default:'USD'"`
	Status    string    `json:"status" gorm:"default:'active'"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// TableName overrides the table name
func (Wallet) TableName() string {
	return "payments.wallets"
}

// DepositRequest represents a deposit request
type DepositRequest struct {
	Amount         float64 `json:"amount" validate:"required,gt=0"`
	Currency       string  `json:"currency" validate:"required"`
	IdempotencyKey string  `json:"idempotency_key" validate:"required"`
	PaymentMethod  string  `json:"payment_method" validate:"required"`
}

// WithdrawRequest represents a withdrawal request
type WithdrawRequest struct {
	Amount         float64 `json:"amount" validate:"required,gt=0"`
	Currency       string  `json:"currency" validate:"required"`
	IdempotencyKey string  `json:"idempotency_key" validate:"required"`
	PaymentMethod  string  `json:"payment_method" validate:"required"`
	AccountDetails string  `json:"account_details" validate:"required"`
}
