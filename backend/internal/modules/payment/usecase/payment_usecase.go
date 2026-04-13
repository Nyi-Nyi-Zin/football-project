package usecase

import (
	"context"
	"fmt"

	"betting-app/internal/modules/payment/domain"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/internal/shared/event"
	"betting-app/pkg/logger"
)

// PaymentUseCase handles payment business logic
type PaymentUseCase struct {
	txRepo     domain.TransactionRepository
	walletRepo domain.WalletRepository
	eventBus   *event.Bus
}

// NewPaymentUseCase creates a new payment use case
func NewPaymentUseCase(
	txRepo domain.TransactionRepository,
	walletRepo domain.WalletRepository,
	eventBus *event.Bus,
) *PaymentUseCase {
	return &PaymentUseCase{
		txRepo:     txRepo,
		walletRepo: walletRepo,
		eventBus:   eventBus,
	}
}

// Deposit adds funds to a user's wallet
func (uc *PaymentUseCase) Deposit(ctx context.Context, userID string, req *domain.DepositRequest) (*domain.Transaction, error) {
	// Check idempotency — if we've seen this key before, return the existing transaction
	existing, _ := uc.txRepo.FindByIdempotencyKey(ctx, req.IdempotencyKey)
	if existing != nil {
		logger.Info("Idempotent deposit request detected", "idempotency_key", req.IdempotencyKey)
		return existing, nil
	}

	// Get current balance
	currentBalance, err := uc.walletRepo.GetBalance(ctx, userID)
	if err != nil {
		// If wallet doesn't exist, create it
		wallet := &domain.Wallet{
			UserID:   userID,
			Balance:  0,
			Currency: req.Currency,
			Status:   "active",
		}
		if createErr := uc.walletRepo.Create(ctx, wallet); createErr != nil {
			return nil, fmt.Errorf("usecase.Deposit: create wallet: %w", createErr)
		}
		currentBalance = 0
	}

	// Create transaction record
	tx := &domain.Transaction{
		UserID:         userID,
		Type:           domain.TransactionDeposit,
		Amount:         req.Amount,
		Currency:       req.Currency,
		Status:         domain.TransactionPending,
		IdempotencyKey: req.IdempotencyKey,
		Description:    fmt.Sprintf("Deposit via %s", req.PaymentMethod),
		BalanceBefore:  currentBalance,
		BalanceAfter:   currentBalance + req.Amount,
	}

	if err := uc.txRepo.Create(ctx, tx); err != nil {
		return nil, fmt.Errorf("usecase.Deposit: create transaction: %w", err)
	}

	// Update wallet balance
	if err := uc.walletRepo.UpdateBalance(ctx, userID, req.Amount); err != nil {
		_ = uc.txRepo.UpdateStatus(ctx, tx.ID, domain.TransactionFailed)
		return nil, fmt.Errorf("usecase.Deposit: update balance: %w", err)
	}

	// Mark transaction as completed
	_ = uc.txRepo.UpdateStatus(ctx, tx.ID, domain.TransactionCompleted)
	tx.Status = domain.TransactionCompleted

	// Publish event
	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.PaymentDeposit,
		Payload: map[string]interface{}{
			"user_id": userID,
			"amount":  req.Amount,
			"tx_id":   tx.ID,
		},
	})

	return tx, nil
}

// Withdraw removes funds from a user's wallet
func (uc *PaymentUseCase) Withdraw(ctx context.Context, userID string, req *domain.WithdrawRequest) (*domain.Transaction, error) {
	// Check idempotency
	existing, _ := uc.txRepo.FindByIdempotencyKey(ctx, req.IdempotencyKey)
	if existing != nil {
		logger.Info("Idempotent withdrawal request detected", "idempotency_key", req.IdempotencyKey)
		return existing, nil
	}

	// Get current balance
	currentBalance, err := uc.walletRepo.GetBalance(ctx, userID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Wallet not found")
	}

	if currentBalance < req.Amount {
		return nil, apperrors.NewBadRequestError("Insufficient balance")
	}

	// Create transaction record
	tx := &domain.Transaction{
		UserID:         userID,
		Type:           domain.TransactionWithdraw,
		Amount:         req.Amount,
		Currency:       req.Currency,
		Status:         domain.TransactionPending,
		IdempotencyKey: req.IdempotencyKey,
		Description:    fmt.Sprintf("Withdrawal to %s", req.PaymentMethod),
		BalanceBefore:  currentBalance,
		BalanceAfter:   currentBalance - req.Amount,
	}

	if err := uc.txRepo.Create(ctx, tx); err != nil {
		return nil, fmt.Errorf("usecase.Withdraw: create transaction: %w", err)
	}

	// Deduct wallet balance
	if err := uc.walletRepo.UpdateBalance(ctx, userID, -req.Amount); err != nil {
		_ = uc.txRepo.UpdateStatus(ctx, tx.ID, domain.TransactionFailed)
		return nil, fmt.Errorf("usecase.Withdraw: update balance: %w", err)
	}

	_ = uc.txRepo.UpdateStatus(ctx, tx.ID, domain.TransactionCompleted)
	tx.Status = domain.TransactionCompleted

	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.PaymentWithdraw,
		Payload: map[string]interface{}{
			"user_id": userID,
			"amount":  req.Amount,
			"tx_id":   tx.ID,
		},
	})

	return tx, nil
}

// GetBalance returns the user's wallet balance
func (uc *PaymentUseCase) GetBalance(ctx context.Context, userID string) (float64, error) {
	balance, err := uc.walletRepo.GetBalance(ctx, userID)
	if err != nil {
		return 0, apperrors.NewNotFoundError("Wallet not found")
	}
	return balance, nil
}

// GetTransactions returns paginated transactions for a user
func (uc *PaymentUseCase) GetTransactions(ctx context.Context, userID string, page, limit int) ([]*domain.Transaction, int64, error) {
	txs, total, err := uc.txRepo.FindByUser(ctx, userID, page, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.GetTransactions: %w", err)
	}
	return txs, total, nil
}

// EnsureWallet creates a wallet for a user if one doesn't exist
func (uc *PaymentUseCase) EnsureWallet(ctx context.Context, userID string) error {
	_, err := uc.walletRepo.FindByUserID(ctx, userID)
	if err != nil {
		wallet := &domain.Wallet{
			UserID:   userID,
			Balance:  0,
			Currency: "USD",
			Status:   "active",
		}
		return uc.walletRepo.Create(ctx, wallet)
	}
	return nil
}
