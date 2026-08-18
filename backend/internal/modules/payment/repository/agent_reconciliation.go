package repository

import (
	"context"
	"fmt"
	"math"
	"time"

	"betting-app/internal/modules/payment/domain"
)

// GetAgentReconciliation returns a wallet-versus-ledger snapshot for one Agent.
func (r *postgresTransactionRepo) GetAgentReconciliation(ctx context.Context, agentID string, from, to time.Time) (*domain.AgentReconciliationReport, error) {
	var report domain.AgentReconciliationReport
	report.AgentID = agentID
	report.From = from
	report.To = to
	report.GeneratedAt = time.Now().UTC()

	var wallet struct {
		Balance         float64 `gorm:"column:balance"`
		ReservedBalance float64 `gorm:"column:reserved_balance"`
		Currency        string  `gorm:"column:currency"`
	}
	if err := r.db.WithContext(ctx).Raw(`
		SELECT balance, reserved_balance, COALESCE(currency, 'MMK') AS currency
		FROM payments.wallets
		WHERE user_id = ?
	`, agentID).Scan(&wallet).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.GetAgentReconciliation: wallet: %w", err)
	}
	report.WalletBalance = wallet.Balance
	report.ReservedBalance = wallet.ReservedBalance
	report.AvailableBalance = wallet.Balance - wallet.ReservedBalance
	report.Currency = wallet.Currency
	if report.Currency == "" {
		report.Currency = "MMK"
	}

	var period struct {
		TransactionCount int     `gorm:"column:transaction_count"`
		DepositCount     int     `gorm:"column:deposit_count"`
		DepositAmount    float64 `gorm:"column:deposit_amount"`
		PayoutCount      int     `gorm:"column:payout_count"`
		PayoutAmount     float64 `gorm:"column:payout_amount"`
		LedgerChange     float64 `gorm:"column:ledger_change"`
	}
	if err := r.db.WithContext(ctx).Raw(`
		SELECT
			COUNT(*) AS transaction_count,
			COUNT(*) FILTER (WHERE type = ? AND status = ?) AS deposit_count,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS deposit_amount,
			COUNT(*) FILTER (WHERE type = ? AND status = ?) AS payout_count,
			COALESCE(SUM(CASE WHEN type = ? AND status = ? THEN amount ELSE 0 END), 0) AS payout_amount,
			COALESCE(SUM(CASE WHEN status = ? THEN balance_after - balance_before ELSE 0 END), 0) AS ledger_change
		FROM payments.transactions
		WHERE user_id = ? AND created_at >= ? AND created_at < ?
	`,
		domain.TransactionAgentCustomerDeposit, domain.TransactionCompleted,
		domain.TransactionAgentCustomerDeposit, domain.TransactionCompleted,
		domain.TransactionAgentPayout, domain.TransactionCompleted,
		domain.TransactionAgentPayout, domain.TransactionCompleted,
		domain.TransactionCompleted,
		agentID, from, to,
	).Scan(&period).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.GetAgentReconciliation: period: %w", err)
	}

	if err := r.db.WithContext(ctx).Raw(`
		SELECT COALESCE(SUM(CASE WHEN status = ? THEN balance_after - balance_before ELSE 0 END), 0)
		FROM payments.transactions
		WHERE user_id = ?
	`, domain.TransactionCompleted, agentID).Scan(&report.LedgerChange).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.GetAgentReconciliation: ledger: %w", err)
	}

	if err := r.db.WithContext(ctx).Raw(`
		SELECT COUNT(*)
		FROM payments.withdrawal_requests
		WHERE agent_id = ? AND status = ?
	`, agentID, domain.WithdrawalRequestPending).Scan(&report.PendingPayouts).Error; err != nil {
		return nil, fmt.Errorf("transactionRepo.GetAgentReconciliation: pending: %w", err)
	}

	report.TransactionCount = period.TransactionCount
	report.DepositCount = period.DepositCount
	report.DepositAmount = period.DepositAmount
	report.PayoutCount = period.PayoutCount
	report.PayoutAmount = period.PayoutAmount
	report.NetSettlement = report.PayoutAmount - report.DepositAmount
	report.Difference = report.WalletBalance - report.LedgerChange
	report.Reconciled = math.Abs(report.Difference) < 0.01
	return &report, nil
}
