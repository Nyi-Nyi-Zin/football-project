package domain

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
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

type WithdrawalRequestStatus string

const (
	WithdrawalRequestPending  WithdrawalRequestStatus = "pending"
	WithdrawalRequestApproved WithdrawalRequestStatus = "approved"
	WithdrawalRequestRejected WithdrawalRequestStatus = "rejected"
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
	Currency       string  `json:"currency"`
	IdempotencyKey string  `json:"idempotency_key" validate:"required"`
	PaymentMethod  string  `json:"payment_method"`
	AccountDetails string  `json:"account_details" validate:"required"`
}

type TransactionFilter struct {
	UserID string
	Type   TransactionType
	Status TransactionStatus
}

type AdminBalanceAdjustmentRequest struct {
	UserID      string  `json:"user_id" validate:"required,uuid4"`
	Amount      float64 `json:"amount" validate:"required,gt=0"`
	Currency    string  `json:"currency" validate:"required"`
	Action      string  `json:"action" validate:"required,oneof=credit debit"`
	Reason      string  `json:"reason" validate:"required"`
	PerformedBy string  `json:"-"`
}

type WithdrawalRequest struct {
	ID                      string                  `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	TransactionID           string                  `json:"transaction_id" gorm:"type:uuid;not null;uniqueIndex"`
	CustomerID              string                  `json:"customer_id" gorm:"type:uuid;not null;index"`
	AgentID                 string                  `json:"agent_id" gorm:"type:uuid;not null;index"`
	VerificationCodeHash    string                  `json:"-" gorm:"not null"`
	CodeLookupHash          string                  `json:"-" gorm:"not null;index"`
	AccountDetailsEncrypted string                  `json:"-" gorm:"type:text;not null"`
	Status                  WithdrawalRequestStatus `json:"status" gorm:"not null;default:'pending';index"`
	ExpiresAt               *time.Time              `json:"expires_at"`
	VerifiedAt              *time.Time              `json:"verified_at"`
	CreatedAt               time.Time               `json:"created_at"`
	UpdatedAt               time.Time               `json:"updated_at"`
}

func (WithdrawalRequest) TableName() string {
	return "payments.withdrawal_requests"
}

type JSONMap map[string]interface{}

func (m JSONMap) Value() (driver.Value, error) {
	if m == nil {
		return "{}", nil
	}
	b, err := json.Marshal(m)
	if err != nil {
		return nil, err
	}
	return string(b), nil
}

func (m *JSONMap) Scan(value interface{}) error {
	if value == nil {
		*m = JSONMap{}
		return nil
	}
	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return fmt.Errorf("unsupported type for JSONMap: %T", value)
	}
	var out map[string]interface{}
	if err := json.Unmarshal(bytes, &out); err != nil {
		return err
	}
	*m = out
	return nil
}

type WithdrawalAuditLog struct {
	ID                  string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	TransactionID       string    `json:"transaction_id" gorm:"type:uuid;not null;index"`
	WithdrawalRequestID *string   `json:"withdrawal_request_id" gorm:"type:uuid"`
	ActorUserID         *string   `json:"actor_user_id" gorm:"type:uuid"`
	ActorRole           string    `json:"actor_role" gorm:"not null"`
	Action              string    `json:"action" gorm:"not null"`
	Details             JSONMap   `json:"details" gorm:"type:jsonb"`
	CreatedAt           time.Time `json:"created_at"`
}

func (WithdrawalAuditLog) TableName() string {
	return "payments.withdrawal_audit_logs"
}

type WithdrawalRequestWithTransaction struct {
	Request     *WithdrawalRequest `json:"request"`
	Transaction *Transaction       `json:"transaction"`
}

type CustomerWithdrawalCreated struct {
	Transaction      *Transaction `json:"transaction"`
	VerificationCode string       `json:"verification_code"`
	AssignedAgentID  string       `json:"assigned_agent_id"`
	RequestStatus    string       `json:"request_status"`
}
