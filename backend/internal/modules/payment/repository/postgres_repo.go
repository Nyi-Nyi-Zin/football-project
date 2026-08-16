package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

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

func (r *postgresTransactionRepo) ListAll(ctx context.Context, filter domain.TransactionFilter, page, limit int) ([]*domain.Transaction, int64, error) {
	var txs []*domain.Transaction
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Transaction{})
	if strings.TrimSpace(filter.UserID) != "" {
		query = query.Where("user_id = ?", filter.UserID)
	}
	if filter.Type != "" {
		query = query.Where("type = ?", filter.Type)
	}
	if filter.Status != "" {
		query = query.Where("status = ?", filter.Status)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAll: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := query.Offset(offset).Limit(limit).Order("created_at DESC").Find(&txs).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAll: find: %w", err)
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

func (r *postgresTransactionRepo) UpdateStatusAndReference(ctx context.Context, txID string, status domain.TransactionStatus, reference string) error {
	result := r.db.WithContext(ctx).Model(&domain.Transaction{}).
		Where("id = ?", txID).
		Updates(map[string]interface{}{
			"status":    status,
			"reference": reference,
		})
	if result.Error != nil {
		return fmt.Errorf("transactionRepo.UpdateStatusAndReference: %w", result.Error)
	}
	return nil
}

func (r *postgresTransactionRepo) FindLeastLoadedActiveAgentID(ctx context.Context) (string, error) {
	type row struct {
		ID string
	}
	var result row
	err := r.db.WithContext(ctx).Raw(`
		SELECT u.id
		FROM users.accounts u
		LEFT JOIN payments.withdrawal_requests wr
			ON wr.agent_id = u.id AND wr.status = ?
		WHERE u.role = 'agent' AND u.status = 'active'
		GROUP BY u.id, u.created_at
		ORDER BY COUNT(wr.id) ASC, u.created_at ASC
		LIMIT 1
	`, domain.WithdrawalRequestPending).Scan(&result).Error
	if err != nil {
		return "", fmt.Errorf("transactionRepo.FindLeastLoadedActiveAgentID: %w", err)
	}
	if strings.TrimSpace(result.ID) == "" {
		return "", gorm.ErrRecordNotFound
	}
	return result.ID, nil
}

func (r *postgresTransactionRepo) CreateWithdrawalRequest(ctx context.Context, req *domain.WithdrawalRequest) error {
	if err := r.db.WithContext(ctx).Create(req).Error; err != nil {
		return fmt.Errorf("transactionRepo.CreateWithdrawalRequest: %w", err)
	}
	return nil
}

func (r *postgresTransactionRepo) FindPendingWithdrawalByAgentAndLookup(ctx context.Context, agentID, lookupHash string) (*domain.WithdrawalRequest, error) {
	var req domain.WithdrawalRequest
	if err := r.db.WithContext(ctx).
		Where("agent_id = ? AND code_lookup_hash = ? AND status = ?", agentID, lookupHash, domain.WithdrawalRequestPending).
		First(&req).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindPendingWithdrawalByAgentAndLookup: %w", err)
	}
	return &req, nil
}

func (r *postgresTransactionRepo) ListAssignedWithdrawals(ctx context.Context, agentID string, status domain.WithdrawalRequestStatus, page, limit int) ([]*domain.WithdrawalRequest, int64, error) {
	var reqs []*domain.WithdrawalRequest
	var total int64

	query := r.db.WithContext(ctx).
		Model(&domain.WithdrawalRequest{}).
		Where("agent_id = ?", agentID)
	if status != "" {
		query = query.Where("status = ?", status)
	}
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAssignedWithdrawals: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := query.Offset(offset).Limit(limit).Order("created_at DESC").Find(&reqs).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAssignedWithdrawals: find: %w", err)
	}
	return reqs, total, nil
}

func (r *postgresTransactionRepo) UpdateWithdrawalRequestStatus(ctx context.Context, requestID string, status domain.WithdrawalRequestStatus, verifiedAt *time.Time) error {
	updates := map[string]interface{}{"status": status}
	if verifiedAt != nil {
		updates["verified_at"] = *verifiedAt
	}
	result := r.db.WithContext(ctx).Model(&domain.WithdrawalRequest{}).
		Where("id = ? OR transaction_id = ?", requestID, requestID).
		Updates(updates)
	if result.Error != nil {
		return fmt.Errorf("transactionRepo.UpdateWithdrawalRequestStatus: %w", result.Error)
	}
	return nil
}

func (r *postgresTransactionRepo) CreateWithdrawalAuditLog(ctx context.Context, audit *domain.WithdrawalAuditLog) error {
	if err := r.db.WithContext(ctx).Create(audit).Error; err != nil {
		return fmt.Errorf("transactionRepo.CreateWithdrawalAuditLog: %w", err)
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
		// Missing wallets start at zero; only the explicit delta is credited.
		newWallet := domain.Wallet{
			UserID:   userID,
			Balance:  amount,
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
			// Missing wallets are initialized with zero balance.
			newWallet := domain.Wallet{
				UserID:   userID,
				Balance:  0,
				Currency: "USD",
				Status:   "active",
			}
			if createErr := r.db.WithContext(ctx).Create(&newWallet).Error; createErr != nil {
				return 0, fmt.Errorf("walletRepo.GetBalance: create wallet: %w", createErr)
			}
			return 0, nil
		}
		return 0, fmt.Errorf("walletRepo.GetBalance: %w", err)
	}
	return wallet.Balance, nil
}

func (r *postgresWalletRepo) IncrementRequiredTurnover(ctx context.Context, userID string, amount float64) error {
	result := r.db.WithContext(ctx).
		Model(&domain.Wallet{}).
		Where("user_id = ?", userID).
		Update("required_turnover", gorm.Expr("required_turnover + ?", amount))
	if result.Error != nil {
		return fmt.Errorf("walletRepo.IncrementRequiredTurnover: %w", result.Error)
	}
	return nil
}

func (r *postgresWalletRepo) IncrementCurrentTurnover(ctx context.Context, userID string, amount float64) error {
	result := r.db.WithContext(ctx).
		Model(&domain.Wallet{}).
		Where("user_id = ?", userID).
		Update("current_turnover", gorm.Expr("current_turnover + ?", amount))
	if result.Error != nil {
		return fmt.Errorf("walletRepo.IncrementCurrentTurnover: %w", result.Error)
	}
	return nil
}

func (r *postgresWalletRepo) GetTurnover(ctx context.Context, userID string) (float64, float64, error) {
	var wallet domain.Wallet
	if err := r.db.WithContext(ctx).
		Select("required_turnover, current_turnover").
		Where("user_id = ?", userID).
		First(&wallet).Error; err != nil {
		return 0, 0, fmt.Errorf("walletRepo.GetTurnover: %w", err)
	}
	return wallet.RequiredTurnover, wallet.CurrentTurnover, nil
}

// ─── Location-based Withdrawal Flow ─────────────────────────────────

func (r *postgresTransactionRepo) FindAgentsByLocation(ctx context.Context, location string) ([]*domain.AgentInfo, error) {
	var agents []*domain.AgentInfo
	if err := r.db.WithContext(ctx).
		Table("users.accounts").
		Select("id, username, full_name, location, custom_code").
		Where("role = ? AND location = ? AND status = ?", "agent", location, "active").
		Find(&agents).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindAgentsByLocation: %w", err)
	}
	return agents, nil
}

func (r *postgresTransactionRepo) FindWithdrawalRequestByCode(ctx context.Context, code string) (*domain.WithdrawalRequest, error) {
	var req domain.WithdrawalRequest
	if err := r.db.WithContext(ctx).
		Where("code = ?", code).
		First(&req).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindWithdrawalRequestByCode: %w", err)
	}
	return &req, nil
}

func (r *postgresTransactionRepo) ApproveWithdrawalRequest(ctx context.Context, requestID string, approvedAt time.Time) error {
	if err := r.db.WithContext(ctx).
		Model(&domain.WithdrawalRequest{}).
		Where("id = ?", requestID).
		Updates(map[string]interface{}{
			"status":      domain.WithdrawalRequestApproved,
			"approved_at": approvedAt,
		}).Error; err != nil {
		return fmt.Errorf("transactionRepo.ApproveWithdrawalRequest: %w", err)
	}
	return nil
}

func (r *postgresTransactionRepo) CancelWithdrawalRequest(ctx context.Context, requestID string, cancelledAt time.Time) error {
	if err := r.db.WithContext(ctx).
		Model(&domain.WithdrawalRequest{}).
		Where("id = ?", requestID).
		Updates(map[string]interface{}{
			"status":       domain.WithdrawalRequestRejected,
			"cancelled_at": cancelledAt,
		}).Error; err != nil {
		return fmt.Errorf("transactionRepo.CancelWithdrawalRequest: %w", err)
	}
	return nil
}
