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

func (r *postgresTransactionRepo) ListAgentCustomerTransactions(ctx context.Context, agentID, customerID string, page, limit int) ([]*domain.Transaction, int64, error) {
	var txs []*domain.Transaction
	var total int64

	query := r.db.WithContext(ctx).Model(&domain.Transaction{}).Where(
		"((user_id = ? AND (from_user_id = ? OR to_user_id = ?)) OR (user_id = ? AND from_user_id = ? AND to_user_id = ?))",
		customerID, agentID, agentID, agentID, agentID, customerID,
	)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAgentCustomerTransactions: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := query.Offset(offset).Limit(limit).Order("created_at DESC").Find(&txs).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAgentCustomerTransactions: find: %w", err)
	}
	return txs, total, nil
}

func (r *postgresTransactionRepo) GetAgentDashboardStats(ctx context.Context, agentID string) (int, float64, float64, int, error) {
	var row struct {
		PendingPayouts     int     `gorm:"column:pending_payouts"`
		TodayDeposits      float64 `gorm:"column:today_deposits"`
		TodayPayouts       float64 `gorm:"column:today_payouts"`
		RecentTransactions int     `gorm:"column:recent_transactions"`
	}

	err := r.db.WithContext(ctx).Raw(`
		SELECT
			(SELECT COUNT(*) FROM payments.withdrawal_requests
			 WHERE agent_id = ? AND status = 'pending') AS pending_payouts,
			COALESCE((SELECT SUM(amount) FROM payments.transactions
			 WHERE user_id = ? AND type = ? AND status = ?
			 AND created_at >= CURRENT_DATE), 0) AS today_deposits,
			COALESCE((SELECT SUM(amount) FROM payments.transactions
			 WHERE user_id = ? AND type = ? AND status = ?
			 AND created_at >= CURRENT_DATE), 0) AS today_payouts,
			(SELECT COUNT(*) FROM payments.transactions WHERE user_id = ?) AS recent_transactions
	`,
		agentID,
		agentID, domain.TransactionAgentCustomerDeposit, domain.TransactionCompleted,
		agentID, domain.TransactionAgentPayout, domain.TransactionCompleted,
		agentID,
	).Scan(&row).Error
	if err != nil {
		return 0, 0, 0, 0, fmt.Errorf("transactionRepo.GetAgentDashboardStats: %w", err)
	}
	return row.PendingPayouts, row.TodayDeposits, row.TodayPayouts, row.RecentTransactions, nil
}

func (r *postgresTransactionRepo) GetAgentEarningsSummary(ctx context.Context, agentID string, from, to time.Time) (*domain.AgentEarningsSummary, error) {
	var summary domain.AgentEarningsSummary
	if err := r.db.WithContext(ctx).Raw(`
		SELECT
			COALESCE(MAX(currency), 'MMK') AS currency,
			COUNT(*) FILTER (WHERE type = ? AND status = ?) AS deposit_count,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS deposit_amount,
			COUNT(*) FILTER (WHERE type = ? AND status = ?) AS payout_count,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS payout_amount
		FROM payments.transactions
		WHERE user_id = ? AND created_at >= ? AND created_at < ?
	`,
		domain.TransactionAgentCustomerDeposit, domain.TransactionCompleted,
		domain.TransactionAgentCustomerDeposit, domain.TransactionCompleted,
		domain.TransactionAgentPayout, domain.TransactionCompleted,
		domain.TransactionAgentPayout, domain.TransactionCompleted,
		agentID, from, to,
	).Scan(&summary).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.GetAgentEarningsSummary: %w", err)
	}

	if err := r.db.WithContext(ctx).Raw(`
		SELECT COUNT(*)
		FROM payments.withdrawal_requests
		WHERE agent_id = ? AND status = ?
	`, agentID, domain.WithdrawalRequestPending).Scan(&summary.PendingPayoutCount).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.GetAgentEarningsSummary: pending payouts: %w", err)
	}

	summary.From = from
	summary.To = to
	summary.PeriodDays = int(to.Sub(from).Hours() / 24)
	summary.NetSettlement = summary.PayoutAmount - summary.DepositAmount
	return &summary, nil
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

func (r *postgresTransactionRepo) GetReconciliationTotals(ctx context.Context) (*domain.ReconciliationTotals, error) {
	var totals domain.ReconciliationTotals
	err := r.db.WithContext(ctx).Raw(`
		SELECT
			COUNT(*) AS total_transactions,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS total_deposits,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS total_withdrawals,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS total_bet_wins,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS total_refunds,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS total_cash_outs,
			COALESCE(SUM(CASE WHEN status = ? THEN balance_after - balance_before ELSE 0 END), 0) AS total_ledger_change,
			COUNT(*) FILTER (WHERE type = ? AND status = ?) AS pending_withdrawals
		FROM payments.transactions
	`,
		domain.TransactionDeposit, domain.TransactionCompleted,
		domain.TransactionWithdraw, domain.TransactionCompleted,
		domain.TransactionBetWin, domain.TransactionCompleted,
		domain.TransactionRefund, domain.TransactionCompleted,
		domain.TransactionCashOut, domain.TransactionCompleted,
		domain.TransactionCompleted,
		domain.TransactionWithdraw, domain.TransactionPending,
	).Scan(&totals).Error
	if err != nil {
		return nil, fmt.Errorf("transactionRepo.GetReconciliationTotals: %w", err)
	}
	totals.NetCashFlow = totals.TotalDeposits + totals.TotalBetWins + totals.TotalRefunds + totals.TotalCashOuts - totals.TotalWithdrawals
	return &totals, nil
}

func (r *postgresTransactionRepo) ListLedgerBalances(ctx context.Context) ([]*domain.UserLedgerBalance, error) {
	var balances []*domain.UserLedgerBalance
	if err := r.db.WithContext(ctx).Raw(`
		SELECT user_id, COALESCE(SUM(balance_after - balance_before), 0) AS ledger_balance
		FROM payments.transactions
		WHERE status = ?
		GROUP BY user_id
		ORDER BY user_id
	`, domain.TransactionCompleted).Scan(&balances).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.ListLedgerBalances: %w", err)
	}
	return balances, nil
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

func (r *postgresTransactionRepo) UpdateSettlement(ctx context.Context, txID string, status domain.TransactionStatus, reference string, balanceBefore, balanceAfter float64) error {
	result := r.db.WithContext(ctx).Model(&domain.Transaction{}).
		Where("id = ?", txID).
		Updates(map[string]interface{}{
			"status":         status,
			"reference":      reference,
			"balance_before": balanceBefore,
			"balance_after":  balanceAfter,
		})
	if result.Error != nil {
		return fmt.Errorf("transactionRepo.UpdateSettlement: %w", result.Error)
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
		Table("payments.withdrawal_requests AS withdrawal_requests").
		Joins("LEFT JOIN users.accounts AS customer ON customer.id = withdrawal_requests.customer_id").
		Where("withdrawal_requests.agent_id = ?", agentID)
	if status != "" {
		query = query.Where("withdrawal_requests.status = ?", status)
	}
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAssignedWithdrawals: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := query.Select("withdrawal_requests.*, customer.full_name AS customer_name").
		Offset(offset).Limit(limit).Order("withdrawal_requests.created_at DESC").Find(&reqs).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAssignedWithdrawals: find: %w", err)
	}
	return reqs, total, nil
}

func (r *postgresTransactionRepo) ListAgentCustomerWithdrawals(ctx context.Context, agentID, customerID string, page, limit int) ([]*domain.WithdrawalRequest, int64, error) {
	var reqs []*domain.WithdrawalRequest
	var total int64

	query := r.db.WithContext(ctx).
		Table("payments.withdrawal_requests AS withdrawal_requests").
		Joins("LEFT JOIN users.accounts AS customer ON customer.id = withdrawal_requests.customer_id").
		Where("withdrawal_requests.agent_id = ? AND withdrawal_requests.customer_id = ?", agentID, customerID)
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAgentCustomerWithdrawals: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := query.Select("withdrawal_requests.*, customer.full_name AS customer_name").
		Offset(offset).Limit(limit).Order("withdrawal_requests.created_at DESC").Find(&reqs).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListAgentCustomerWithdrawals: find: %w", err)
	}
	return reqs, total, nil
}

func (r *postgresTransactionRepo) ListCustomerWithdrawals(ctx context.Context, customerID string, status domain.WithdrawalRequestStatus, page, limit int) ([]*domain.WithdrawalRequest, int64, error) {
	var reqs []*domain.WithdrawalRequest
	var total int64
	query := r.db.WithContext(ctx).
		Table("payments.withdrawal_requests AS withdrawal_requests").
		Joins("LEFT JOIN users.accounts AS agent ON agent.id = withdrawal_requests.agent_id").
		Where("withdrawal_requests.customer_id = ?", customerID)
	if status != "" {
		query = query.Where("withdrawal_requests.status = ?", status)
	}
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListCustomerWithdrawals: count: %w", err)
	}
	offset := (page - 1) * limit
	if err := query.Select("withdrawal_requests.*, agent.full_name AS agent_name").
		Offset(offset).Limit(limit).Order("withdrawal_requests.created_at DESC").Find(&reqs).Error; err != nil {
		return nil, 0, fmt.Errorf("transactionRepo.ListCustomerWithdrawals: find: %w", err)
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

func (r *postgresTransactionRepo) ExpireWithdrawalRequest(ctx context.Context, requestID string, expiredAt time.Time) (bool, error) {
	result := r.db.WithContext(ctx).Model(&domain.WithdrawalRequest{}).
		Where("(id = ? OR transaction_id = ?) AND status = ?", requestID, requestID, domain.WithdrawalRequestPending).
		Updates(map[string]interface{}{
			"status":       domain.WithdrawalRequestExpired,
			"cancelled_at": expiredAt,
		})
	if result.Error != nil {
		return false, fmt.Errorf("transactionRepo.ExpireWithdrawalRequest: %w", result.Error)
	}
	return result.RowsAffected == 1, nil
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

func (r *postgresWalletRepo) ListAll(ctx context.Context) ([]*domain.Wallet, error) {
	var wallets []*domain.Wallet
	if err := r.db.WithContext(ctx).Order("created_at ASC").Find(&wallets).Error; err != nil {
		return nil, fmt.Errorf("walletRepo.ListAll: %w", err)
	}
	return wallets, nil
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
			Currency: "MMK",
			Status:   "active",
		}
		return r.db.WithContext(ctx).Create(&newWallet).Error
	}
	return nil
}

func (r *postgresWalletRepo) ReserveBalance(ctx context.Context, userID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("walletRepo.ReserveBalance: amount must be positive")
	}
	result := r.db.WithContext(ctx).
		Model(&domain.Wallet{}).
		Where("user_id = ? AND balance - COALESCE(reserved_balance, 0) >= ?", userID, amount).
		UpdateColumn("reserved_balance", gorm.Expr("COALESCE(reserved_balance, 0) + ?", amount))
	if result.Error != nil {
		return fmt.Errorf("walletRepo.ReserveBalance: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return domain.ErrInsufficientAvailableBalance
	}
	return nil
}

func (r *postgresWalletRepo) ReleaseReservedBalance(ctx context.Context, userID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("walletRepo.ReleaseReservedBalance: amount must be positive")
	}
	result := r.db.WithContext(ctx).
		Model(&domain.Wallet{}).
		Where("user_id = ? AND reserved_balance >= ?", userID, amount).
		UpdateColumn("reserved_balance", gorm.Expr("reserved_balance - ?", amount))
	if result.Error != nil {
		return fmt.Errorf("walletRepo.ReleaseReservedBalance: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("walletRepo.ReleaseReservedBalance: reserved balance not found")
	}
	return nil
}

func (r *postgresWalletRepo) SettleReservedTransfer(ctx context.Context, fromUserID, toUserID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("walletRepo.SettleReservedTransfer: amount must be positive")
	}
	if fromUserID == toUserID {
		return fmt.Errorf("walletRepo.SettleReservedTransfer: source and destination must differ")
	}

	db := r.db.WithContext(ctx)
	if err := db.Where("user_id = ?", toUserID).FirstOrCreate(&domain.Wallet{
		UserID:   toUserID,
		Currency: "MMK",
		Status:   "active",
	}).Error; err != nil {
		return fmt.Errorf("walletRepo.SettleReservedTransfer: ensure destination wallet: %w", err)
	}

	tx := db.Begin()
	if tx.Error != nil {
		return fmt.Errorf("walletRepo.SettleReservedTransfer: begin: %w", tx.Error)
	}
	rollback := func(err error) error {
		_ = tx.Rollback()
		return err
	}

	var wallets []domain.Wallet
	if err := tx.Set("gorm:query_option", "FOR UPDATE").
		Where("user_id IN ?", []string{fromUserID, toUserID}).
		Order("user_id ASC").Find(&wallets).Error; err != nil {
		return rollback(fmt.Errorf("walletRepo.SettleReservedTransfer: lock wallets: %w", err))
	}
	var source, destination *domain.Wallet
	for i := range wallets {
		wallet := &wallets[i]
		if wallet.UserID == fromUserID {
			source = wallet
		} else if wallet.UserID == toUserID {
			destination = wallet
		}
	}
	if source == nil || destination == nil || source.ReservedBalance < amount {
		return rollback(domain.ErrInsufficientAvailableBalance)
	}

	if err := tx.Model(&domain.Wallet{}).Where("id = ?", source.ID).Updates(map[string]interface{}{
		"balance":          gorm.Expr("balance - ?", amount),
		"reserved_balance": gorm.Expr("reserved_balance - ?", amount),
	}).Error; err != nil {
		return rollback(fmt.Errorf("walletRepo.SettleReservedTransfer: debit source: %w", err))
	}
	if err := tx.Model(&domain.Wallet{}).Where("id = ?", destination.ID).
		UpdateColumn("balance", gorm.Expr("balance + ?", amount)).Error; err != nil {
		return rollback(fmt.Errorf("walletRepo.SettleReservedTransfer: credit destination: %w", err))
	}
	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("walletRepo.SettleReservedTransfer: commit: %w", err)
	}
	return nil
}

func (r *postgresWalletRepo) TransferBalance(ctx context.Context, fromUserID, toUserID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("walletRepo.TransferBalance: amount must be positive")
	}
	if fromUserID == toUserID {
		return fmt.Errorf("walletRepo.TransferBalance: source and destination must differ")
	}

	db := r.db.WithContext(ctx)
	if err := db.Where("user_id = ?", toUserID).FirstOrCreate(&domain.Wallet{
		UserID:   toUserID,
		Currency: "MMK",
		Status:   "active",
	}).Error; err != nil {
		return fmt.Errorf("walletRepo.TransferBalance: ensure destination wallet: %w", err)
	}

	tx := db.Begin()
	if tx.Error != nil {
		return fmt.Errorf("walletRepo.TransferBalance: begin: %w", tx.Error)
	}
	rollback := func(err error) error {
		_ = tx.Rollback()
		return err
	}

	var wallets []domain.Wallet
	if err := tx.Set("gorm:query_option", "FOR UPDATE").
		Where("user_id IN ?", []string{fromUserID, toUserID}).
		Order("user_id ASC").Find(&wallets).Error; err != nil {
		return rollback(fmt.Errorf("walletRepo.TransferBalance: lock wallets: %w", err))
	}

	var source, destination *domain.Wallet
	for i := range wallets {
		wallet := &wallets[i]
		if wallet.UserID == fromUserID {
			source = wallet
		} else if wallet.UserID == toUserID {
			destination = wallet
		}
	}
	if source == nil || destination == nil {
		return rollback(domain.ErrInsufficientAvailableBalance)
	}
	if source.Balance-source.ReservedBalance < amount {
		return rollback(domain.ErrInsufficientAvailableBalance)
	}

	if err := tx.Model(&domain.Wallet{}).Where("id = ?", source.ID).
		UpdateColumn("balance", gorm.Expr("balance - ?", amount)).Error; err != nil {
		return rollback(fmt.Errorf("walletRepo.TransferBalance: debit source: %w", err))
	}
	if err := tx.Model(&domain.Wallet{}).Where("id = ?", destination.ID).
		UpdateColumn("balance", gorm.Expr("balance + ?", amount)).Error; err != nil {
		return rollback(fmt.Errorf("walletRepo.TransferBalance: credit destination: %w", err))
	}
	if err := tx.Commit().Error; err != nil {
		return fmt.Errorf("walletRepo.TransferBalance: commit: %w", err)
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
				Currency: "MMK",
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

func (r *postgresTransactionRepo) FindAgentLocations(ctx context.Context) ([]string, error) {
	var locations []string
	if err := r.db.WithContext(ctx).
		Table("users.accounts").
		Where("role = ? AND status = ? AND location IS NOT NULL AND TRIM(location) <> ''", "agent", "active").
		Distinct("location").
		Order("location ASC").
		Pluck("location", &locations).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindAgentLocations: %w", err)
	}
	return locations, nil
}

func (r *postgresTransactionRepo) FindAgentsByLocation(ctx context.Context, location string) ([]*domain.AgentInfo, error) {
	var agents []*domain.AgentInfo
	if err := r.db.WithContext(ctx).
		Table("users.accounts").
		Select("id, username, full_name, region, township, location, custom_code").
		Where("role = ? AND location = ? AND status = ?", "agent", location, "active").
		Find(&agents).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindAgentsByLocation: %w", err)
	}
	return agents, nil
}

func (r *postgresTransactionRepo) FindAgentRegions(ctx context.Context) ([]string, error) {
	var regions []string
	if err := r.db.WithContext(ctx).
		Table("users.accounts").
		Where("role = ? AND status = ? AND region IS NOT NULL AND TRIM(region) <> ''", "agent", "active").
		Distinct("region").
		Order("region ASC").
		Pluck("region", &regions).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindAgentRegions: %w", err)
	}
	return regions, nil
}

func (r *postgresTransactionRepo) FindAgentTownships(ctx context.Context, region string) ([]string, error) {
	var townships []string
	if err := r.db.WithContext(ctx).
		Table("users.accounts").
		Where("role = ? AND status = ? AND region = ? AND township IS NOT NULL AND TRIM(township) <> ''", "agent", "active", region).
		Distinct("township").
		Order("township ASC").
		Pluck("township", &townships).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindAgentTownships: %w", err)
	}
	return townships, nil
}

func (r *postgresTransactionRepo) FindAgentsByRegionTownship(ctx context.Context, region, township string) ([]*domain.AgentInfo, error) {
	var agents []*domain.AgentInfo
	if err := r.db.WithContext(ctx).
		Table("users.accounts").
		Select("id, username, full_name, region, township, location, custom_code").
		Where("role = ? AND status = ? AND region = ? AND township = ?", "agent", "active", region, township).
		Order("full_name ASC").
		Find(&agents).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindAgentsByRegionTownship: %w", err)
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

func (r *postgresTransactionRepo) FindWithdrawalRequestByID(ctx context.Context, requestID string) (*domain.WithdrawalRequest, error) {
	var req domain.WithdrawalRequest
	if err := r.db.WithContext(ctx).
		Where("id = ? OR transaction_id = ?", requestID, requestID).
		First(&req).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.FindWithdrawalRequestByID: %w", err)
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
