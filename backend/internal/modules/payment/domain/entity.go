package domain

import (
	"context"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"time"
)

// TransactionType represents the type of financial transaction
type TransactionType string

var ErrInsufficientAvailableBalance = errors.New("insufficient available balance")

const (
	TransactionDeposit              TransactionType = "deposit"
	TransactionWithdraw             TransactionType = "withdraw"
	TransactionBetStake             TransactionType = "bet_stake"
	TransactionBetWin               TransactionType = "bet_win"
	TransactionCashOut              TransactionType = "cash_out"
	TransactionRefund               TransactionType = "refund"
	TransactionAgentPayout          TransactionType = "agent_payout"
	TransactionAgentCustomerDeposit TransactionType = "agent_customer_deposit"
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
	WithdrawalRequestExpired  WithdrawalRequestStatus = "expired"
)

// Transaction represents a financial transaction
type Transaction struct {
	ID             string            `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID         string            `json:"user_id" gorm:"type:uuid;not null;index"`
	Type           TransactionType   `json:"type" gorm:"not null"`
	Amount         float64           `json:"amount" gorm:"type:decimal(18,2);not null"`
	Currency       string            `json:"currency" gorm:"default:'MMK'"`
	Status         TransactionStatus `json:"status" gorm:"default:'pending'"`
	IdempotencyKey string            `json:"idempotency_key" gorm:"uniqueIndex"`
	Reference      string            `json:"reference"` // external payment reference
	Description    string            `json:"description"`
	FromUserID     *string           `json:"from_user_id,omitempty" gorm:"type:uuid;index"`
	ToUserID       *string           `json:"to_user_id,omitempty" gorm:"type:uuid;index"`
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
	ID               string    `json:"id" gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
	UserID           string    `json:"user_id" gorm:"type:uuid;uniqueIndex;not null"`
	Balance          float64   `json:"balance" gorm:"type:decimal(18,2);default:0"`
	ReservedBalance  float64   `json:"reserved_balance" gorm:"type:decimal(18,2);default:0"`
	Currency         string    `json:"currency" gorm:"default:'MMK'"`
	Status           string    `json:"status" gorm:"default:'active'"`
	RequiredTurnover float64   `json:"required_turnover" gorm:"type:decimal(18,2);default:0"`
	CurrentTurnover  float64   `json:"current_turnover" gorm:"type:decimal(18,2);default:0"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

// TableName overrides the table name
func (Wallet) TableName() string {
	return "payments.wallets"
}

// KYCStatus mirrors the user module's KYC status enum for cross-module use.
type KYCStatus string

const (
	KYCStatusPending  KYCStatus = "pending"
	KYCStatusApproved KYCStatus = "approved"
	KYCStatusRejected KYCStatus = "rejected"
)

// UserVerificationStatus holds the verification state needed by the WithdrawalGuard.
type UserVerificationStatus struct {
	IsEmailVerified bool
	IsPhoneVerified bool
	KYCStatus       KYCStatus
}

// UserVerificationProvider is the interface the payment module uses to query
// user verification state from the user module without direct imports.
type UserVerificationProvider interface {
	GetVerificationStatus(ctx context.Context, userID string) (*UserVerificationStatus, error)
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

type AgentDashboardSummary struct {
	AvailableBalance   float64 `json:"available_balance"`
	ReservedBalance    float64 `json:"reserved_balance"`
	Currency           string  `json:"currency"`
	PendingPayouts     int     `json:"pending_payouts"`
	TodayDeposits      float64 `json:"today_deposits"`
	TodayPayouts       float64 `json:"today_payouts"`
	RecentTransactions int     `json:"recent_transactions"`
}

type AgentCustomerActivity struct {
	Transactions []*Transaction       `json:"transactions"`
	Withdrawals  []*WithdrawalRequest `json:"withdrawals"`
}

type AgentEarningsSummary struct {
	PeriodDays         int       `json:"period_days"`
	From               time.Time `json:"from"`
	To                 time.Time `json:"to"`
	Currency           string    `json:"currency"`
	DepositCount       int       `json:"deposit_count"`
	DepositAmount      float64   `json:"deposit_amount"`
	PayoutCount        int       `json:"payout_count"`
	PayoutAmount       float64   `json:"payout_amount"`
	NetSettlement      float64   `json:"net_settlement"`
	PendingPayoutCount int       `json:"pending_payout_count"`
}

type ReconciliationTotals struct {
	TotalTransactions  int64   `json:"total_transactions"`
	TotalDeposits      float64 `json:"total_deposits"`
	TotalWithdrawals   float64 `json:"total_withdrawals"`
	TotalBetWins       float64 `json:"total_bet_wins"`
	TotalRefunds       float64 `json:"total_refunds"`
	TotalCashOuts      float64 `json:"total_cash_outs"`
	NetCashFlow        float64 `json:"net_cash_flow"`
	TotalLedgerChange  float64 `json:"total_ledger_change"`
	PendingWithdrawals int64   `json:"pending_withdrawals"`
}

type UserLedgerBalance struct {
	UserID        string  `json:"user_id"`
	LedgerBalance float64 `json:"ledger_balance"`
}

type WalletReconciliationRow struct {
	UserID           string  `json:"user_id"`
	Currency         string  `json:"currency"`
	WalletBalance    float64 `json:"wallet_balance"`
	ReservedBalance  float64 `json:"reserved_balance"`
	AvailableBalance float64 `json:"available_balance"`
	LedgerBalance    float64 `json:"ledger_balance"`
	Difference       float64 `json:"difference"`
	Reconciled       bool    `json:"reconciled"`
}

type WalletReconciliationReport struct {
	GeneratedAt      time.Time                  `json:"generated_at"`
	Totals           *ReconciliationTotals      `json:"totals"`
	Users            []*WalletReconciliationRow `json:"users"`
	ReconciledUsers  int                        `json:"reconciled_users"`
	DiscrepancyUsers int                        `json:"discrepancy_users"`
}

// AgentReconciliationReport is a commission-ready settlement snapshot.
// Commission is intentionally not calculated until the business rate is defined.
type AgentReconciliationReport struct {
	GeneratedAt      time.Time `json:"generated_at"`
	From             time.Time `json:"from"`
	To               time.Time `json:"to"`
	AgentID          string    `json:"agent_id"`
	Currency         string    `json:"currency"`
	WalletBalance    float64   `json:"wallet_balance"`
	ReservedBalance  float64   `json:"reserved_balance"`
	AvailableBalance float64   `json:"available_balance"`
	LedgerChange     float64   `json:"ledger_change"`
	Difference       float64   `json:"difference"`
	Reconciled       bool      `json:"reconciled"`
	DepositCount     int       `json:"deposit_count"`
	DepositAmount    float64   `json:"deposit_amount"`
	PayoutCount      int       `json:"payout_count"`
	PayoutAmount     float64   `json:"payout_amount"`
	NetSettlement    float64   `json:"net_settlement"`
	PendingPayouts   int       `json:"pending_payouts"`
	TransactionCount int       `json:"transaction_count"`
}

type AdminBalanceAdjustmentRequest struct {
	UserID      string  `json:"user_id" validate:"required,uuid4"`
	Amount      float64 `json:"amount" validate:"required,gt=0"`
	Currency    string  `json:"currency" validate:"required"`
	Action      string  `json:"action" validate:"required,oneof=credit debit"`
	Reason      string  `json:"reason" validate:"required"`
	PerformedBy string  `json:"-"`
}

type AgentCustomerDepositRequest struct {
	CustomerID  string  `json:"customer_id" validate:"required,uuid4"`
	Amount      float64 `json:"amount" validate:"required,gt=0"`
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
	Location                string                  `json:"location" gorm:"type:varchar(100)"`
	Region                  string                  `json:"region" gorm:"type:varchar(100)"`
	Township                string                  `json:"township" gorm:"type:varchar(100)"`
	Code                    string                  `json:"code" gorm:"type:varchar(10)"`
	AgentName               string                  `json:"agent_name,omitempty" gorm:"-"`
	CustomerName            string                  `json:"customer_name,omitempty" gorm:"-"`
	ApprovedAt              *time.Time              `json:"approved_at"`
	CancelledAt             *time.Time              `json:"cancelled_at"`
}

func (WithdrawalRequest) TableName() string {
	return "payments.withdrawal_requests"
}

// CreateWithdrawalRequest represents a request to create a withdrawal
type CreateWithdrawalRequest struct {
	Amount         float64 `json:"amount" validate:"required,gt=0"`
	Region         string  `json:"region" validate:"required,max=100"`
	Township       string  `json:"township" validate:"required,max=100"`
	Location       string  `json:"location" validate:"required,max=100"`
	AccountDetails string  `json:"account_details" validate:"required"`
}

// ApproveWithdrawalRequest represents a request to approve a withdrawal
type ApproveWithdrawalRequest struct {
	Code string `json:"code" validate:"required"`
}

// CancelWithdrawalRequest represents a request to cancel a withdrawal
type CancelWithdrawalRequest struct {
	Reason string `json:"reason"`
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
