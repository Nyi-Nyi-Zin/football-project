package repository

import (
	"context"
	"fmt"

	"betting-app/internal/modules/payment/domain"

	"gorm.io/gorm"
)

// Transaction repository

type postgresTransactionRepo struct {
	db *gorm.DB
}

// NewPostgresTransactionRepo creates a new PostgreSQL transaction repository
func NewPostgresTransactionRepo(db *gorm.DB) domain.TransactionRepository {
	return &postgresTransactionRepo{db: db}
}

func (r *postgresTransactionRepo) Create(ctx context.Context, tx *domain.Transaction) error {
	if err := r.db.WithContext(ctx).Create(tx).Error; err != nil {
		return fmt.Errorf("transactionRepo.Create: %w", err)
	}
	return nil
}

func (r *postgresTransactionRepo) FindByID(ctx context.Context, id string) (*domain.Transaction, error) {
	var tx domain.Transaction
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&tx).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindByID: %w", err)
	}
	return &tx, nil
}

func (r *postgresTransactionRepo) FindByIdempotencyKey(ctx context.Context, key string) (*domain.Transaction, error) {
	var tx domain.Transaction
	if err := r.db.WithContext(ctx).Where("idempotency_key = ?", key).First(&tx).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindByIdempotencyKey: %w", err)
	}
	return &tx, nil
}

func (r *postgresTransactionRepo) FindByUser(ctx context.Context, userID string, page, limit int) ([]*domain.Transaction, int64, error) {
	var txs []*domain.Transaction
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Transaction{}).Where("user_id = ?", userID)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.FindByUser: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := query.Offset(offset).Limit(limit).Order("created_at DESC").Find(&txs).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.FindByUser: find: %w", err)
	}

	return txs, total, nil
}

func (r *postgresTransactionRepo) UpdateStatus(ctx context.Context, txID string, status domain.TransactionStatus) error {
	result := r.db.WithContext(ctx).Model(&domain.Transaction{}).
		Where("id = ?", txID).
		Update("status", status)
	if result.Error != nil {
		return fmt.Errorf("transactionRepo.UpdateStatus: %w", result.Error)
	}
	return nil
}

// Wallet repository

type postgresWalletRepo struct {
	db *gorm.DB
}

// NewPostgresWalletRepo creates a new PostgreSQL wallet repository
func NewPostgresWalletRepo(db *gorm.DB) domain.WalletRepository {
	return &postgresWalletRepo{db: db}
}

func (r *postgresWalletRepo) Create(ctx context.Context, wallet *domain.Wallet) error {
	if err := r.db.WithContext(ctx).Create(wallet).Error; err != nil {
		return fmt.Errorf("walletRepo.Create: %w", err)
	}
	return nil
}

func (r *postgresWalletRepo) FindByUserID(ctx context.Context, userID string) (*domain.Wallet, error) {
	var wallet domain.Wallet
	if err := r.db.WithContext(ctx).Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		return nil, fmt.Errorf("walletRepo.FindByUserID: %w", err)
	}
	return &wallet, nil
}

func (r *postgresWalletRepo) UpdateBalance(ctx context.Context, userID string, amount float64) error {
	result := r.db.WithContext(ctx).
		Model(&domain.Wallet{}).
		Where("user_id = ?", userID).
		Update("balance", gorm.Expr("balance + ?", amount))
	if result.Error != nil {
		return fmt.Errorf("walletRepo.UpdateBalance: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		// Auto-create wallet with $1000 starter bonus if missing
		newWallet := domain.Wallet{
			UserID:   userID,
			Balance:  1000.0 + amount,
			Currency: "USD",
			Status:   "active",
		}
		return r.db.WithContext(ctx).Create(&newWallet).Error
	}
	return nil
}

func (r *postgresWalletRepo) GetBalance(ctx context.Context, userID string) (float64, error) {
	var wallet domain.Wallet
	if err := r.db.WithContext(ctx).Select("balance").Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			// Auto-create wallet with $1000 starter bonus
			newWallet := domain.Wallet{
				UserID:   userID,
				Balance:  1000.0,
				Currency: "USD",
				Status:   "active",
			}
			r.db.WithContext(ctx).Create(&newWallet)
			return 1000.0, nil
		}
		return 0, fmt.Errorf("walletRepo.GetBalance: %w", err)
	}
	return wallet.Balance, nil
}
