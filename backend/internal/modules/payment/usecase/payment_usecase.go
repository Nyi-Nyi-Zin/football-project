package usecase

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"strings"
	"time"

	"betting-app/internal/modules/payment/domain"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/internal/shared/event"
	"betting-app/pkg/logger"

	"golang.org/x/crypto/bcrypt"
)

// PaymentUseCase handles payment business logic
type PaymentUseCase struct {
	txRepo     domain.TransactionRepository
	walletRepo domain.WalletRepository
	eventBus   *event.Bus
	codePepper string
	encKey     []byte
}

type SecurityOptions struct {
	CodePepper    string
	EncryptionKey string
}

// NewPaymentUseCase creates a new payment use case
func NewPaymentUseCase(
	txRepo domain.TransactionRepository,
	walletRepo domain.WalletRepository,
	eventBus *event.Bus,
	security SecurityOptions,
) *PaymentUseCase {
	pepper := strings.TrimSpace(security.CodePepper)
	if pepper == "" {
		pepper = "dev-withdrawal-pepper"
	}
	keySeed := strings.TrimSpace(security.EncryptionKey)
	if keySeed == "" {
		keySeed = "dev-withdrawal-encryption-key"
	}
	key := sha256.Sum256([]byte(keySeed))
	return &PaymentUseCase{
		txRepo:     txRepo,
		walletRepo: walletRepo,
		eventBus:   eventBus,
		codePepper: pepper,
		encKey:     key[:],
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
func (uc *PaymentUseCase) Withdraw(ctx context.Context, userID string, req *domain.WithdrawRequest) (*domain.CustomerWithdrawalCreated, error) {
	// Check idempotency
	existing, _ := uc.txRepo.FindByIdempotencyKey(ctx, req.IdempotencyKey)
	if existing != nil {
		logger.Info("Idempotent withdrawal request detected", "idempotency_key", req.IdempotencyKey)
		return &domain.CustomerWithdrawalCreated{
			Transaction:   existing,
			RequestStatus: string(domain.WithdrawalRequestPending),
		}, nil
	}

	// Get current balance
	currentBalance, err := uc.walletRepo.GetBalance(ctx, userID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Wallet not found")
	}

	if currentBalance < req.Amount {
		return nil, apperrors.NewBadRequestError("Insufficient balance")
	}
	if strings.TrimSpace(req.Currency) == "" {
		req.Currency = "USD"
	}
	if strings.TrimSpace(req.PaymentMethod) == "" {
		req.PaymentMethod = "manual_agent"
	}

	agentID, err := uc.txRepo.FindLeastLoadedActiveAgentID(ctx)
	if err != nil || strings.TrimSpace(agentID) == "" {
		return nil, apperrors.NewBadRequestError("No active agent available to process this withdrawal")
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

	code, err := uc.generateVerificationCode()
	if err != nil {
		return nil, fmt.Errorf("usecase.Withdraw: generate code: %w", err)
	}
	codeHash, err := hashCode(code)
	if err != nil {
		return nil, fmt.Errorf("usecase.Withdraw: hash code: %w", err)
	}

	encryptedAccountDetails, err := uc.encryptSensitive(req.AccountDetails)
	if err != nil {
		return nil, fmt.Errorf("usecase.Withdraw: encrypt account details: %w", err)
	}

	reqRecord := &domain.WithdrawalRequest{
		TransactionID:           tx.ID,
		CustomerID:              userID,
		AgentID:                 agentID,
		VerificationCodeHash:    codeHash,
		CodeLookupHash:          uc.lookupHash(code),
		AccountDetailsEncrypted: encryptedAccountDetails,
		Status:                  domain.WithdrawalRequestPending,
	}
	if err := uc.txRepo.CreateWithdrawalRequest(ctx, reqRecord); err != nil {
		return nil, fmt.Errorf("usecase.Withdraw: create withdrawal request: %w", err)
	}
	_ = uc.txRepo.CreateWithdrawalAuditLog(ctx, &domain.WithdrawalAuditLog{
		TransactionID:       tx.ID,
		WithdrawalRequestID: &reqRecord.ID,
		ActorUserID:         &userID,
		ActorRole:           "customer",
		Action:              "withdrawal_requested",
		Details: domain.JSONMap{
			"status":     string(domain.WithdrawalRequestPending),
			"agent_id":   agentID,
			"amount":     req.Amount,
			"currency":   req.Currency,
			"created_at": time.Now().UTC(),
		},
	})

	return &domain.CustomerWithdrawalCreated{
		Transaction:      tx,
		VerificationCode: code,
		AssignedAgentID:  agentID,
		RequestStatus:    string(domain.WithdrawalRequestPending),
	}, nil
}

// GetBalance returns the user's wallet balance
func (uc *PaymentUseCase) GetBalance(ctx context.Context, userID string) (float64, error) {
	balance, err := uc.walletRepo.GetBalance(ctx, userID)
	if err != nil {
		return 0, apperrors.NewNotFoundError("Wallet not found")
	}
	return balance, nil
}

// GetWallet returns the user's full wallet
func (uc *PaymentUseCase) GetWallet(ctx context.Context, userID string) (*domain.Wallet, error) {
	wallet, err := uc.walletRepo.FindByUserID(ctx, userID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Wallet not found")
	}
	return wallet, nil
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
			Currency: "MMK",
			Status:   "active",
		}
		return uc.walletRepo.Create(ctx, wallet)
	}
	return nil
}

func (uc *PaymentUseCase) GetAllTransactions(ctx context.Context, filter domain.TransactionFilter, page, limit int) ([]*domain.Transaction, int64, error) {
	txs, total, err := uc.txRepo.ListAll(ctx, filter, page, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.GetAllTransactions: %w", err)
	}
	return txs, total, nil
}

func (uc *PaymentUseCase) AdminAdjustBalance(ctx context.Context, req *domain.AdminBalanceAdjustmentRequest) (*domain.Transaction, error) {
	currentBalance, err := uc.walletRepo.GetBalance(ctx, req.UserID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Wallet not found")
	}

	sign := 1.0
	txType := domain.TransactionDeposit
	action := strings.ToLower(strings.TrimSpace(req.Action))
	if action == "debit" {
		sign = -1.0
		txType = domain.TransactionRefund
		if currentBalance < req.Amount {
			return nil, apperrors.NewBadRequestError("Insufficient balance for debit adjustment")
		}
	}

	tx := &domain.Transaction{
		UserID:         req.UserID,
		Type:           txType,
		Amount:         req.Amount,
		Currency:       req.Currency,
		Status:         domain.TransactionCompleted,
		IdempotencyKey: fmt.Sprintf("admin-adjust-%s-%s-%d", req.UserID, req.PerformedBy, time.Now().UnixNano()),
		Description:    fmt.Sprintf("Admin %s adjustment: %s", action, req.Reason),
		BalanceBefore:  currentBalance,
		BalanceAfter:   currentBalance + (sign * req.Amount),
	}
	if err := uc.txRepo.Create(ctx, tx); err != nil {
		return nil, fmt.Errorf("usecase.AdminAdjustBalance: create transaction: %w", err)
	}

	if err := uc.walletRepo.UpdateBalance(ctx, req.UserID, sign*req.Amount); err != nil {
		return nil, fmt.Errorf("usecase.AdminAdjustBalance: update wallet: %w", err)
	}

	return tx, nil
}

func (uc *PaymentUseCase) ApproveWithdrawal(ctx context.Context, txID, adminID string) (*domain.Transaction, error) {
	tx, err := uc.txRepo.FindByID(ctx, txID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Withdrawal request not found")
	}
	if tx.Type != domain.TransactionWithdraw {
		return nil, apperrors.NewBadRequestError("Transaction is not a withdrawal request")
	}
	if tx.Status != domain.TransactionPending {
		return nil, apperrors.NewBadRequestError("Only pending withdrawals can be approved")
	}

	currentBalance, err := uc.walletRepo.GetBalance(ctx, tx.UserID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Wallet not found")
	}
	if currentBalance < tx.Amount {
		return nil, apperrors.NewBadRequestError("Insufficient user balance")
	}

	if err := uc.walletRepo.UpdateBalance(ctx, tx.UserID, -tx.Amount); err != nil {
		return nil, fmt.Errorf("usecase.ApproveWithdrawal: update balance: %w", err)
	}
	ref := fmt.Sprintf("approved-by:%s", adminID)
	if err := uc.txRepo.UpdateStatusAndReference(ctx, tx.ID, domain.TransactionCompleted, ref); err != nil {
		return nil, fmt.Errorf("usecase.ApproveWithdrawal: update status: %w", err)
	}
	tx.Status = domain.TransactionCompleted
	tx.Reference = ref
	now := time.Now().UTC()
	_ = uc.txRepo.UpdateWithdrawalRequestStatus(ctx, tx.ID, domain.WithdrawalRequestApproved, &now)
	_ = uc.txRepo.CreateWithdrawalAuditLog(ctx, &domain.WithdrawalAuditLog{
		TransactionID: tx.ID,
		ActorUserID:   &adminID,
		ActorRole:     "admin",
		Action:        "withdrawal_approved_admin",
		Details: domain.JSONMap{
			"reference": ref,
		},
	})

	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.PaymentWithdraw,
		Payload: map[string]interface{}{
			"user_id": tx.UserID,
			"amount":  tx.Amount,
			"tx_id":   tx.ID,
		},
	})

	return tx, nil
}

func (uc *PaymentUseCase) RejectWithdrawal(ctx context.Context, txID, adminID, reason string) (*domain.Transaction, error) {
	tx, err := uc.txRepo.FindByID(ctx, txID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Withdrawal request not found")
	}
	if tx.Type != domain.TransactionWithdraw {
		return nil, apperrors.NewBadRequestError("Transaction is not a withdrawal request")
	}
	if tx.Status != domain.TransactionPending {
		return nil, apperrors.NewBadRequestError("Only pending withdrawals can be rejected")
	}

	reason = strings.TrimSpace(reason)
	ref := fmt.Sprintf("rejected-by:%s", adminID)
	if reason != "" {
		ref = fmt.Sprintf("%s;reason:%s", ref, reason)
	}
	if err := uc.txRepo.UpdateStatusAndReference(ctx, tx.ID, domain.TransactionCancelled, ref); err != nil {
		return nil, fmt.Errorf("usecase.RejectWithdrawal: update status: %w", err)
	}
	tx.Status = domain.TransactionCancelled
	tx.Reference = ref
	_ = uc.txRepo.UpdateWithdrawalRequestStatus(ctx, tx.ID, domain.WithdrawalRequestRejected, nil)
	_ = uc.txRepo.CreateWithdrawalAuditLog(ctx, &domain.WithdrawalAuditLog{
		TransactionID: tx.ID,
		ActorUserID:   &adminID,
		ActorRole:     "admin",
		Action:        "withdrawal_rejected_admin",
		Details: domain.JSONMap{
			"reason": reason,
		},
	})

	return tx, nil
}

func (uc *PaymentUseCase) GetAssignedWithdrawalsForAgent(ctx context.Context, agentID string, status domain.WithdrawalRequestStatus, page, limit int) ([]*domain.WithdrawalRequestWithTransaction, int64, error) {
	reqs, total, err := uc.txRepo.ListAssignedWithdrawals(ctx, agentID, status, page, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.GetAssignedWithdrawalsForAgent: %w", err)
	}
	items := make([]*domain.WithdrawalRequestWithTransaction, 0, len(reqs))
	for _, req := range reqs {
		tx, txErr := uc.txRepo.FindByID(ctx, req.TransactionID)
		if txErr != nil {
			return nil, 0, fmt.Errorf("usecase.GetAssignedWithdrawalsForAgent: find tx: %w", txErr)
		}
		items = append(items, &domain.WithdrawalRequestWithTransaction{
			Request:     req,
			Transaction: tx,
		})
	}
	return items, total, nil
}

func (uc *PaymentUseCase) VerifyWithdrawalCode(ctx context.Context, agentID, code string) (*domain.Transaction, error) {
	code = strings.ToUpper(strings.TrimSpace(code))
	if len(code) != 6 {
		return nil, apperrors.NewValidationError("Validation failed", "code must be 6 characters")
	}
	req, err := uc.txRepo.FindPendingWithdrawalByAgentAndLookup(ctx, agentID, uc.lookupHash(code))
	if err != nil {
		return nil, apperrors.NewNotFoundError("Assigned withdrawal request not found for this code")
	}
	if err := compareCode(req.VerificationCodeHash, code); err != nil {
		return nil, apperrors.NewBadRequestError("Invalid verification code")
	}

	tx, err := uc.txRepo.FindByID(ctx, req.TransactionID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Withdrawal request not found")
	}
	if tx.Status != domain.TransactionPending {
		return nil, apperrors.NewBadRequestError("Only pending withdrawals can be processed")
	}

	currentBalance, err := uc.walletRepo.GetBalance(ctx, tx.UserID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Wallet not found")
	}
	if currentBalance < tx.Amount {
		return nil, apperrors.NewBadRequestError("Insufficient user balance")
	}
	if err := uc.walletRepo.UpdateBalance(ctx, tx.UserID, -tx.Amount); err != nil {
		return nil, fmt.Errorf("usecase.VerifyWithdrawalCode: update balance: %w", err)
	}

	ref := fmt.Sprintf("approved-by-agent:%s", agentID)
	if err := uc.txRepo.UpdateStatusAndReference(ctx, tx.ID, domain.TransactionCompleted, ref); err != nil {
		return nil, fmt.Errorf("usecase.VerifyWithdrawalCode: update transaction: %w", err)
	}
	now := time.Now().UTC()
	if err := uc.txRepo.UpdateWithdrawalRequestStatus(ctx, req.ID, domain.WithdrawalRequestApproved, &now); err != nil {
		return nil, fmt.Errorf("usecase.VerifyWithdrawalCode: update request status: %w", err)
	}
	_ = uc.txRepo.CreateWithdrawalAuditLog(ctx, &domain.WithdrawalAuditLog{
		TransactionID:       tx.ID,
		WithdrawalRequestID: &req.ID,
		ActorUserID:         &agentID,
		ActorRole:           "agent",
		Action:              "withdrawal_approved_agent_code",
		Details: domain.JSONMap{
			"verified_at": now,
			"status":      string(domain.WithdrawalRequestApproved),
		},
	})

	tx.Status = domain.TransactionCompleted
	tx.Reference = ref
	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.PaymentWithdraw,
		Payload: map[string]interface{}{
			"user_id": tx.UserID,
			"amount":  tx.Amount,
			"tx_id":   tx.ID,
		},
	})
	return tx, nil
}

func (uc *PaymentUseCase) generateVerificationCode() (string, error) {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	const codeLen = 6
	b := make([]byte, codeLen)
	if _, err := io.ReadFull(rand.Reader, b); err != nil {
		return "", err
	}
	for i := range b {
		b[i] = alphabet[int(b[i])%len(alphabet)]
	}
	return string(b), nil
}

func (uc *PaymentUseCase) lookupHash(code string) string {
	sum := sha256.Sum256([]byte(uc.codePepper + ":" + code))
	return hex.EncodeToString(sum[:])
}

func hashCode(code string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(code), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}

func compareCode(hash, code string) error {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(code))
}

func (uc *PaymentUseCase) encryptSensitive(value string) (string, error) {
	block, err := aes.NewCipher(uc.encKey)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}
	ciphertext := gcm.Seal(nil, nonce, []byte(value), nil)
	raw := append(nonce, ciphertext...)
	return base64.StdEncoding.EncodeToString(raw), nil
}
