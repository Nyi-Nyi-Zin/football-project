package domain

import "context"

// TransactionRepository defines the interface for transaction data access
type TransactionRepository interface {
	Create(ctx context.Context, tx *Transaction) error
	FindByID(ctx context.Context, id string) (*Transaction, error)
	FindByIdempotencyKey(ctx context.Context, key string) (*Transaction, error)
	FindByUser(ctx context.Context, userID string, page, limit int) ([]*Transaction, int64, error)
	UpdateStatus(ctx context.Context, txID string, status TransactionStatus) error
}

// WalletRepository defines the interface for wallet data access
type WalletRepository interface {
	Create(ctx context.Context, wallet *Wallet) error
	FindByUserID(ctx context.Context, userID string) (*Wallet, error)
	UpdateBalance(ctx context.Context, userID string, amount float64) error
	GetBalance(ctx context.Context, userID string) (float64, error)
}
