package domain

import (
	"context"
	"time"
)

// TransactionRepository defines the interface for transaction data access
type TransactionRepository interface {
	Create(ctx context.Context, tx *Transaction) error
	FindByID(ctx context.Context, id string) (*Transaction, error)
	FindByIdempotencyKey(ctx context.Context, key string) (*Transaction, error)
	FindByUser(ctx context.Context, userID string, page, limit int) ([]*Transaction, int64, error)
	ListAll(ctx context.Context, filter TransactionFilter, page, limit int) ([]*Transaction, int64, error)
	GetReconciliationTotals(ctx context.Context) (*ReconciliationTotals, error)
	ListLedgerBalances(ctx context.Context) ([]*UserLedgerBalance, error)
	UpdateStatus(ctx context.Context, txID string, status TransactionStatus) error
	UpdateStatusAndReference(ctx context.Context, txID string, status TransactionStatus, reference string) error
	UpdateSettlement(ctx context.Context, txID string, status TransactionStatus, reference string, balanceBefore, balanceAfter float64) error
	FindLeastLoadedActiveAgentID(ctx context.Context) (string, error)
	CreateWithdrawalRequest(ctx context.Context, req *WithdrawalRequest) error
	FindPendingWithdrawalByAgentAndLookup(ctx context.Context, agentID, lookupHash string) (*WithdrawalRequest, error)
	ListAssignedWithdrawals(ctx context.Context, agentID string, status WithdrawalRequestStatus, page, limit int) ([]*WithdrawalRequest, int64, error)
	ListCustomerWithdrawals(ctx context.Context, customerID string, status WithdrawalRequestStatus, page, limit int) ([]*WithdrawalRequest, int64, error)
	UpdateWithdrawalRequestStatus(ctx context.Context, requestID string, status WithdrawalRequestStatus, verifiedAt *time.Time) error
	CreateWithdrawalAuditLog(ctx context.Context, audit *WithdrawalAuditLog) error

	// New methods for location-based withdrawal flow
	FindAgentLocations(ctx context.Context) ([]string, error)
	FindAgentsByLocation(ctx context.Context, location string) ([]*AgentInfo, error)
	FindWithdrawalRequestByCode(ctx context.Context, code string) (*WithdrawalRequest, error)
	FindWithdrawalRequestByID(ctx context.Context, requestID string) (*WithdrawalRequest, error)
	ApproveWithdrawalRequest(ctx context.Context, requestID string, approvedAt time.Time) error
	CancelWithdrawalRequest(ctx context.Context, requestID string, cancelledAt time.Time) error
}

// AgentInfo represents minimal agent information for withdrawal flow
type AgentInfo struct {
	ID         string `json:"id"`
	Username   string `json:"username"`
	FullName   string `json:"full_name"`
	Location   string `json:"location"`
	CustomCode string `json:"custom_code"`
}

// WalletRepository defines the interface for wallet data access
type WalletRepository interface {
	Create(ctx context.Context, wallet *Wallet) error
	FindByUserID(ctx context.Context, userID string) (*Wallet, error)
	ListAll(ctx context.Context) ([]*Wallet, error)
	UpdateBalance(ctx context.Context, userID string, amount float64) error
	GetBalance(ctx context.Context, userID string) (float64, error)
	ReserveBalance(ctx context.Context, userID string, amount float64) error
	ReleaseReservedBalance(ctx context.Context, userID string, amount float64) error
	SettleReservedTransfer(ctx context.Context, fromUserID, toUserID string, amount float64) error

	// AML / Turnover tracking
	IncrementRequiredTurnover(ctx context.Context, userID string, amount float64) error
	IncrementCurrentTurnover(ctx context.Context, userID string, amount float64) error
	GetTurnover(ctx context.Context, userID string) (required float64, current float64, err error)
}
