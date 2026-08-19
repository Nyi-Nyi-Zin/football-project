package usecase

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"math"
	"sort"
	"strings"
	"time"

	auditDomain "betting-app/internal/modules/audit/domain"
	"betting-app/internal/modules/payment/domain"
	apperrors "betting-app/internal/shared/errors"
	"betting-app/internal/shared/event"
	"betting-app/pkg/logger"

	"golang.org/x/crypto/bcrypt"
)

// PaymentUseCase handles payment business logic
type PaymentUseCase struct {
	txRepo           domain.TransactionRepository
	walletRepo       domain.WalletRepository
	auditRepo        auditDomain.AuditRepository
	eventBus         *event.Bus
	codePepper       string
	encKey           []byte
	verificationProv domain.UserVerificationProvider // KYC gate for withdrawals
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
	verificationProv ...domain.UserVerificationProvider,
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
		txRepo:           txRepo,
		walletRepo:       walletRepo,
		eventBus:         eventBus,
		codePepper:       pepper,
		encKey:           key[:],
		verificationProv: firstVerificationProvider(verificationProv),
	}
}

// SetAuditRepository enables append-only Admin audit records without changing
// the existing PaymentUseCase constructor contract used by older callers/tests.
func (uc *PaymentUseCase) SetAuditRepository(repo auditDomain.AuditRepository) {
	uc.auditRepo = repo
}

func firstVerificationProvider(providers []domain.UserVerificationProvider) domain.UserVerificationProvider {
	if len(providers) == 0 {
		return nil
	}
	return providers[0]
}

// ─── Withdrawal Guard ────────────────────────────────────────────────────────

// checkWithdrawalEligibility enforces KYC verification and AML turnover rules
// before allowing a withdrawal to proceed. Returns nil if the user is eligible,
// or an *AppError with a specific remediation message.
func (uc *PaymentUseCase) checkWithdrawalEligibility(ctx context.Context, userID string) error {
	// 1. KYC / Verification gate
	if uc.verificationProv != nil {
		vs, err := uc.verificationProv.GetVerificationStatus(ctx, userID)
		if err != nil {
			return apperrors.NewBadRequestError("Unable to verify account status. Please complete your profile.")
		}

		if !vs.IsEmailVerified {
			return apperrors.NewForbiddenError(
				"Email verification required. Please verify your email address in your profile settings before withdrawing.",
			)
		}
		if !vs.IsPhoneVerified {
			return apperrors.NewForbiddenError(
				"Phone verification required. Please verify your phone number in your profile settings before withdrawing.",
			)
		}
		if domain.KYCStatus(vs.KYCStatus) != domain.KYCStatusApproved {
			switch domain.KYCStatus(vs.KYCStatus) {
			case domain.KYCStatusPending:
				return apperrors.NewForbiddenError(
					"KYC verification pending. Please submit your National ID and verification image in your profile, then wait for admin approval.",
				)
			case domain.KYCStatusRejected:
				return apperrors.NewForbiddenError(
					"KYC verification was rejected. Please re-submit valid documents in your profile settings.",
				)
			default:
				return apperrors.NewForbiddenError(
					"KYC verification required. Please complete identity verification in your profile before withdrawing.",
				)
			}
		}
	}

	// 2. AML Turnover gate
	requiredTurnover, currentTurnover, err := uc.walletRepo.GetTurnover(ctx, userID)
	if err != nil {
		// If wallet doesn't exist yet turnover is effectively 0/0 — allow.
		logger.Warn("GetTurnover failed during withdrawal check, skipping turnover gate", "user_id", userID, "error", err)
	} else if currentTurnover < requiredTurnover {
		remaining := requiredTurnover - currentTurnover
		return apperrors.NewForbiddenError(
			fmt.Sprintf(
				"Wagering requirement not met. You must wager %.2f more before withdrawing. Place bets with odds ≥ 1.30 to fulfil this requirement.",
				remaining,
			),
		)
	}

	return nil
}

// ─── Deposit ─────────────────────────────────────────────────────────────────

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

	// ── AML: Increment required_turnover (1:1 ratio) ──
	if err := uc.walletRepo.IncrementRequiredTurnover(ctx, userID, req.Amount); err != nil {
		logger.Error("Failed to increment required turnover on deposit",
			"user_id", userID, "amount", req.Amount, "error", err)
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

// ─── Withdraw ────────────────────────────────────────────────────────────────

// Withdraw removes funds from a user's wallet
func (uc *PaymentUseCase) Withdraw(ctx context.Context, userID string, req *domain.WithdrawRequest) (*domain.CustomerWithdrawalCreated, error) {
	// ── WITHDRAWAL GUARD: KYC + Turnover check ──
	if err := uc.checkWithdrawalEligibility(ctx, userID); err != nil {
		return nil, err
	}

	// Check idempotency
	existing, _ := uc.txRepo.FindByIdempotencyKey(ctx, req.IdempotencyKey)
	if existing != nil {
		logger.Info("Idempotent withdrawal request detected", "idempotency_key", req.IdempotencyKey)
		return &domain.CustomerWithdrawalCreated{
			Transaction:   existing,
			RequestStatus: string(domain.WithdrawalRequestPending),
		}, nil
	}

	// Reserve the amount immediately so concurrent bets and withdrawal requests
	// cannot spend funds that are already promised to an agent.
	currentBalance, err := uc.walletRepo.GetBalance(ctx, userID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Wallet not found")
	}
	if err := uc.walletRepo.ReserveBalance(ctx, userID, req.Amount); err != nil {
		if errors.Is(err, domain.ErrInsufficientAvailableBalance) {
			return nil, apperrors.NewBadRequestError("Insufficient available balance")
		}
		return nil, fmt.Errorf("usecase.Withdraw: reserve balance: %w", err)
	}
	if strings.TrimSpace(req.Currency) == "" {
		req.Currency = "MMK"
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
		BalanceAfter:   currentBalance,
	}

	if err := uc.txRepo.Create(ctx, tx); err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		return nil, fmt.Errorf("usecase.Withdraw: create transaction: %w", err)
	}

	code, err := uc.generateVerificationCode()
	if err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		return nil, fmt.Errorf("usecase.Withdraw: generate code: %w", err)
	}
	codeHash, err := hashCode(code)
	if err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		return nil, fmt.Errorf("usecase.Withdraw: hash code: %w", err)
	}

	encryptedAccountDetails, err := uc.encryptSensitive(req.AccountDetails)
	if err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
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
		Code:                    code,
		ExpiresAt:               timePtr(time.Now().Add(24 * time.Hour)),
	}
	if err := uc.txRepo.CreateWithdrawalRequest(ctx, reqRecord); err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		_ = uc.txRepo.UpdateStatus(ctx, tx.ID, domain.TransactionCancelled)
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

// GetWallet returns the user's full wallet and bootstraps a zero-balance wallet when needed.
func (uc *PaymentUseCase) GetWallet(ctx context.Context, userID string) (*domain.Wallet, error) {
	wallet, err := uc.walletRepo.FindByUserID(ctx, userID)
	if err == nil && wallet != nil {
		return wallet, nil
	}

	if ensureErr := uc.EnsureWallet(ctx, userID); ensureErr != nil {
		return nil, fmt.Errorf("usecase.GetWallet: ensure wallet: %w", ensureErr)
	}

	wallet, err = uc.walletRepo.FindByUserID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetWallet: load ensured wallet: %w", err)
	}
	return wallet, nil
}

// GetReservedBalanceTotal returns funds currently held for pending withdrawals.
func (uc *PaymentUseCase) GetReservedBalanceTotal(ctx context.Context) (float64, error) {
	wallets, err := uc.walletRepo.ListAll(ctx)
	if err != nil {
		return 0, fmt.Errorf("usecase.GetReservedBalanceTotal: %w", err)
	}
	var total float64
	for _, wallet := range wallets {
		if wallet != nil {
			total += wallet.ReservedBalance
		}
	}
	return roundMoney(total), nil
}

// GetAgentCustomerActivity returns only activity shared between an Agent and customer.
func (uc *PaymentUseCase) GetAgentCustomerActivity(ctx context.Context, agentID, customerID string) (*domain.AgentCustomerActivity, error) {
	transactions, _, err := uc.txRepo.ListAgentCustomerTransactions(ctx, agentID, customerID, 1, 50)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentCustomerActivity: transactions: %w", err)
	}
	withdrawals, _, err := uc.txRepo.ListAgentCustomerWithdrawals(ctx, agentID, customerID, 1, 50)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentCustomerActivity: withdrawals: %w", err)
	}
	if len(transactions) == 0 && len(withdrawals) == 0 {
		return nil, apperrors.NewNotFoundError("Customer is not connected to this Agent")
	}
	return &domain.AgentCustomerActivity{
		Transactions: transactions,
		Withdrawals:  withdrawals,
	}, nil
}

// GetAgentDashboardSummary returns agent-scoped wallet and daily operation metrics.
func (uc *PaymentUseCase) GetAgentDashboardSummary(ctx context.Context, agentID string) (*domain.AgentDashboardSummary, error) {
	wallet, err := uc.GetWallet(ctx, agentID)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentDashboardSummary: wallet: %w", err)
	}

	pending, todayDeposits, todayPayouts, recent, err := uc.txRepo.GetAgentDashboardStats(ctx, agentID)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentDashboardSummary: stats: %w", err)
	}

	return &domain.AgentDashboardSummary{
		AvailableBalance:   roundMoney(wallet.Balance - wallet.ReservedBalance),
		ReservedBalance:    roundMoney(wallet.ReservedBalance),
		Currency:           wallet.Currency,
		PendingPayouts:     pending,
		TodayDeposits:      roundMoney(todayDeposits),
		TodayPayouts:       roundMoney(todayPayouts),
		RecentTransactions: recent,
	}, nil
}

// GetAgentEarningsSummary returns settled agent ledger activity for a bounded reporting period.
func (uc *PaymentUseCase) GetAgentEarningsSummary(ctx context.Context, agentID string, days int) (*domain.AgentEarningsSummary, error) {
	if days < 1 {
		days = 30
	}
	if days > 90 {
		days = 90
	}
	to := time.Now().UTC()
	from := to.AddDate(0, 0, -days)
	summary, err := uc.txRepo.GetAgentEarningsSummary(ctx, agentID, from, to)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentEarningsSummary: %w", err)
	}
	if summary.Currency == "" {
		summary.Currency = "MMK"
	}
	return summary, nil
}

// GetAgentCommissionStatement applies the configured Agent commission rule to settled activity.
func (uc *PaymentUseCase) GetAgentCommissionStatement(ctx context.Context, agentID string, days int) (*domain.AgentCommissionStatement, error) {
	summary, err := uc.GetAgentEarningsSummary(ctx, agentID, days)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentCommissionStatement: earnings: %w", err)
	}
	rule, err := uc.txRepo.GetAgentCommissionRule(ctx, agentID)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentCommissionStatement: rule: %w", err)
	}
	if rule == nil {
		rule = &domain.AgentCommissionRule{Currency: "MMK"}
	}
	depositCommission := summary.DepositAmount * float64(rule.DepositRateBPS) / 10000
	payoutCommission := summary.PayoutAmount * float64(rule.PayoutRateBPS) / 10000
	commission := depositCommission + payoutCommission
	grossSettlement := summary.NetSettlement
	statement := &domain.AgentCommissionStatement{
		AgentEarningsSummary: summary,
		DepositRateBPS:       rule.DepositRateBPS,
		PayoutRateBPS:        rule.PayoutRateBPS,
		DepositRatePercent:   float64(rule.DepositRateBPS) / 100,
		PayoutRatePercent:    float64(rule.PayoutRateBPS) / 100,
		DepositCommission:    roundMoney(depositCommission),
		PayoutCommission:     roundMoney(payoutCommission),
		CommissionAmount:     roundMoney(commission),
		GrossSettlement:      roundMoney(grossSettlement),
		NetAfterCommission:   roundMoney(grossSettlement + commission),
	}
	if rule.Currency != "" {
		statement.Currency = rule.Currency
	}
	return statement, nil
}

// GetAgentCommissionRule returns the active rule or the explicit zero-rate default.
func (uc *PaymentUseCase) GetAgentCommissionRule(ctx context.Context, agentID string) (*domain.AgentCommissionRule, error) {
	rule, err := uc.txRepo.GetAgentCommissionRule(ctx, agentID)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentCommissionRule: %w", err)
	}
	if rule == nil {
		rule = &domain.AgentCommissionRule{AgentID: agentID, Currency: "MMK", Active: true}
	}
	return rule, nil
}

// UpdateAgentCommissionRule applies an administrator-owned commission rule.
func (uc *PaymentUseCase) UpdateAgentCommissionRule(ctx context.Context, req *domain.UpdateAgentCommissionRuleRequest, adminID string) (*domain.AgentCommissionRule, error) {
	currency := strings.TrimSpace(req.Currency)
	if currency == "" {
		currency = "MMK"
	}
	rule := &domain.AgentCommissionRule{
		AgentID:        req.AgentID,
		DepositRateBPS: req.DepositRateBPS,
		PayoutRateBPS:  req.PayoutRateBPS,
		Currency:       currency,
		Active:         true,
		UpdatedBy:      adminID,
	}
	if err := uc.txRepo.UpsertAgentCommissionRule(ctx, rule); err != nil {
		return nil, fmt.Errorf("usecase.UpdateAgentCommissionRule: %w", err)
	}
	return rule, nil
}

// GetAgentReconciliation returns a wallet-versus-ledger snapshot for a bounded period.
func (uc *PaymentUseCase) GetAgentReconciliation(ctx context.Context, agentID string, days int) (*domain.AgentReconciliationReport, error) {
	if days < 1 {
		days = 30
	}
	if days > 90 {
		days = 90
	}
	to := time.Now().UTC()
	from := to.AddDate(0, 0, -days)
	report, err := uc.txRepo.GetAgentReconciliation(ctx, agentID, from, to)
	if err != nil {
		return nil, fmt.Errorf("usecase.GetAgentReconciliation: %w", err)
	}
	if report.Currency == "" {
		report.Currency = "MMK"
	}
	report.WalletBalance = roundMoney(report.WalletBalance)
	report.ReservedBalance = roundMoney(report.ReservedBalance)
	report.AvailableBalance = roundMoney(report.AvailableBalance)
	report.LedgerChange = roundMoney(report.LedgerChange)
	report.Difference = roundMoney(report.Difference)
	report.DepositAmount = roundMoney(report.DepositAmount)
	report.PayoutAmount = roundMoney(report.PayoutAmount)
	report.NetSettlement = roundMoney(report.NetSettlement)
	return report, nil
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
	wallet, err := uc.walletRepo.FindByUserID(ctx, userID)
	if err == nil && wallet != nil {
		return nil
	}
	if err != nil || wallet == nil {
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

func (uc *PaymentUseCase) ReconcileWallets(ctx context.Context) (*domain.WalletReconciliationReport, error) {
	totals, err := uc.txRepo.GetReconciliationTotals(ctx)
	if err != nil {
		return nil, fmt.Errorf("usecase.ReconcileWallets: totals: %w", err)
	}
	wallets, err := uc.walletRepo.ListAll(ctx)
	if err != nil {
		return nil, fmt.Errorf("usecase.ReconcileWallets: wallets: %w", err)
	}
	ledgerBalances, err := uc.txRepo.ListLedgerBalances(ctx)
	if err != nil {
		return nil, fmt.Errorf("usecase.ReconcileWallets: ledger: %w", err)
	}

	walletByUser := make(map[string]*domain.Wallet, len(wallets))
	userIDs := make(map[string]struct{}, len(wallets)+len(ledgerBalances))
	for _, wallet := range wallets {
		walletByUser[wallet.UserID] = wallet
		userIDs[wallet.UserID] = struct{}{}
	}
	ledgerByUser := make(map[string]float64, len(ledgerBalances))
	for _, row := range ledgerBalances {
		ledgerByUser[row.UserID] = row.LedgerBalance
		userIDs[row.UserID] = struct{}{}
	}

	orderedUserIDs := make([]string, 0, len(userIDs))
	for userID := range userIDs {
		orderedUserIDs = append(orderedUserIDs, userID)
	}
	sort.Strings(orderedUserIDs)

	report := &domain.WalletReconciliationReport{
		GeneratedAt: time.Now().UTC(),
		Totals:      totals,
		Users:       make([]*domain.WalletReconciliationRow, 0, len(orderedUserIDs)),
	}
	for _, userID := range orderedUserIDs {
		wallet := walletByUser[userID]
		walletBalance := 0.0
		reservedBalance := 0.0
		currency := ""
		if wallet != nil {
			walletBalance = wallet.Balance
			reservedBalance = wallet.ReservedBalance
			currency = wallet.Currency
		}
		ledgerBalance := ledgerByUser[userID]
		difference := roundMoney(walletBalance - ledgerBalance)
		row := &domain.WalletReconciliationRow{
			UserID:           userID,
			Currency:         currency,
			WalletBalance:    roundMoney(walletBalance),
			ReservedBalance:  roundMoney(reservedBalance),
			AvailableBalance: roundMoney(walletBalance - reservedBalance),
			LedgerBalance:    roundMoney(ledgerBalance),
			Difference:       difference,
			Reconciled:       math.Abs(difference) <= 0.01,
		}

		report.Users = append(report.Users, row)
		if row.Reconciled {
			report.ReconciledUsers++
		} else {
			report.DiscrepancyUsers++
		}
	}
	return report, nil
}

func roundMoney(value float64) float64 {
	return math.Round(value*100) / 100
}

func (uc *PaymentUseCase) AgentDepositToCustomer(ctx context.Context, req *domain.AgentCustomerDepositRequest) (*domain.Transaction, error) {
	if req.PerformedBy == "" || req.PerformedBy == req.CustomerID {
		return nil, apperrors.NewBadRequestError("A valid Agent account and different customer are required")
	}

	agentBalanceBefore, err := uc.walletRepo.GetBalance(ctx, req.PerformedBy)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Agent wallet not found")
	}
	customerBalanceBefore, err := uc.walletRepo.GetBalance(ctx, req.CustomerID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Customer wallet not found")
	}

	if err := uc.walletRepo.TransferBalance(ctx, req.PerformedBy, req.CustomerID, req.Amount); err != nil {
		if errors.Is(err, domain.ErrInsufficientAvailableBalance) {
			return nil, apperrors.NewBadRequestError("Insufficient available Agent balance")
		}
		return nil, fmt.Errorf("usecase.AgentDepositToCustomer: transfer balance: %w", err)
	}

	const currency = "MMK"
	fromUserID := req.PerformedBy
	toUserID := req.CustomerID
	customerTx := &domain.Transaction{
		UserID:         req.CustomerID,
		Type:           domain.TransactionDeposit,
		Amount:         req.Amount,
		Currency:       currency,
		Status:         domain.TransactionCompleted,
		IdempotencyKey: fmt.Sprintf("agent-deposit-customer-%s-%s-%d", req.CustomerID, req.PerformedBy, time.Now().UnixNano()),
		Description:    fmt.Sprintf("Agent deposit by %s", req.PerformedBy),
		FromUserID:     &fromUserID,
		ToUserID:       &toUserID,
		BalanceBefore:  customerBalanceBefore,
		BalanceAfter:   customerBalanceBefore + req.Amount,
	}
	if err := uc.txRepo.Create(ctx, customerTx); err != nil {
		return nil, fmt.Errorf("usecase.AgentDepositToCustomer: create customer transaction: %w", err)
	}

	agentTx := &domain.Transaction{
		UserID:         req.PerformedBy,
		Type:           domain.TransactionAgentCustomerDeposit,
		Amount:         req.Amount,
		Currency:       currency,
		Status:         domain.TransactionCompleted,
		IdempotencyKey: fmt.Sprintf("agent-deposit-agent-%s-%s-%d", req.PerformedBy, req.CustomerID, time.Now().UnixNano()),
		Description:    fmt.Sprintf("Customer deposit to %s", req.CustomerID),
		FromUserID:     &fromUserID,
		ToUserID:       &toUserID,
		BalanceBefore:  agentBalanceBefore,
		BalanceAfter:   agentBalanceBefore - req.Amount,
	}
	if err := uc.txRepo.Create(ctx, agentTx); err != nil {
		return nil, fmt.Errorf("usecase.AgentDepositToCustomer: create Agent transaction: %w", err)
	}

	return customerTx, nil
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

	if uc.auditRepo != nil {
		metadata := fmt.Sprintf(`{"amount":%.2f,"currency":%q,"action":%q,"reason":%q,"balance_before":%.2f,"balance_after":%.2f,"transaction_id":%q}`,
			req.Amount, req.Currency, action, req.Reason, currentBalance, tx.BalanceAfter, tx.ID)
		if err := uc.auditRepo.Create(ctx, &auditDomain.AuditLog{
			ActorID:      req.PerformedBy,
			ActorRole:    "admin",
			Action:       "wallet.balance_adjusted",
			ResourceType: "wallet",
			ResourceID:   req.UserID,
			Metadata:     metadata,
		}); err != nil {
			logger.Error("Admin wallet adjustment committed but audit record failed", "user_id", req.UserID, "transaction_id", tx.ID, "error", err)
		}
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

	withdrawalReq, err := uc.txRepo.FindWithdrawalRequestByID(ctx, tx.ID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Withdrawal request details not found")
	}
	if err := uc.walletRepo.SettleReservedTransfer(ctx, tx.UserID, withdrawalReq.AgentID, tx.Amount); err != nil {
		if errors.Is(err, domain.ErrInsufficientAvailableBalance) {
			return nil, apperrors.NewBadRequestError("The held withdrawal amount is no longer available")
		}
		return nil, fmt.Errorf("usecase.ApproveWithdrawal: settle agent transfer: %w", err)
	}
	ref := fmt.Sprintf("approved-by-admin:%s", adminID)
	if err := uc.txRepo.UpdateStatusAndReference(ctx, tx.ID, domain.TransactionCompleted, ref); err != nil {
		return nil, fmt.Errorf("usecase.ApproveWithdrawal: update status: %w", err)
	}
	now := time.Now().UTC()
	_ = uc.txRepo.Create(ctx, &domain.Transaction{
		UserID:         withdrawalReq.AgentID,
		Type:           domain.TransactionAgentPayout,
		Amount:         tx.Amount,
		Currency:       tx.Currency,
		Status:         domain.TransactionCompleted,
		IdempotencyKey: fmt.Sprintf("admin-agent-payout-%s-%s", tx.ID, withdrawalReq.AgentID),
		Reference:      ref,
		Description:    "Agent payout received for customer withdrawal",
	})
	_ = uc.txRepo.UpdateWithdrawalRequestStatus(ctx, withdrawalReq.ID, domain.WithdrawalRequestApproved, &now)

	tx.Status = domain.TransactionCompleted
	tx.Reference = ref
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
			"user_id":  tx.UserID,
			"agent_id": withdrawalReq.AgentID,
			"amount":   tx.Amount,
			"currency": tx.Currency,
			"tx_id":    tx.ID,
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
	withdrawalReq, err := uc.txRepo.FindWithdrawalRequestByID(ctx, tx.ID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Withdrawal request details not found")
	}
	if err := uc.walletRepo.ReleaseReservedBalance(ctx, tx.UserID, tx.Amount); err != nil {
		return nil, fmt.Errorf("usecase.RejectWithdrawal: release reserved balance: %w", err)
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
	_ = uc.txRepo.UpdateWithdrawalRequestStatus(ctx, withdrawalReq.ID, domain.WithdrawalRequestRejected, nil)
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

func (uc *PaymentUseCase) GetCustomerWithdrawals(ctx context.Context, customerID string, status domain.WithdrawalRequestStatus, page, limit int) ([]*domain.WithdrawalRequestWithTransaction, int64, error) {
	reqs, total, err := uc.txRepo.ListCustomerWithdrawals(ctx, customerID, status, page, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.GetCustomerWithdrawals: %w", err)
	}
	items := make([]*domain.WithdrawalRequestWithTransaction, 0, len(reqs))
	for _, req := range reqs {
		tx, txErr := uc.txRepo.FindByID(ctx, req.TransactionID)
		if txErr != nil {
			return nil, 0, fmt.Errorf("usecase.GetCustomerWithdrawals: find transaction: %w", txErr)
		}
		items = append(items, &domain.WithdrawalRequestWithTransaction{
			Request:     req,
			Transaction: tx,
		})
	}
	return items, total, nil
}

func (uc *PaymentUseCase) expireWithdrawalIfNeeded(ctx context.Context, req *domain.WithdrawalRequest) (bool, error) {
	if req.ExpiresAt == nil || time.Now().UTC().Before(*req.ExpiresAt) {
		return false, nil
	}

	now := time.Now().UTC()
	expired, err := uc.txRepo.ExpireWithdrawalRequest(ctx, req.ID, now)
	if err != nil {
		return false, fmt.Errorf("usecase.expireWithdrawalIfNeeded: expire request: %w", err)
	}
	if !expired {
		return true, nil
	}

	tx, err := uc.txRepo.FindByID(ctx, req.TransactionID)
	if err != nil {
		return false, fmt.Errorf("usecase.expireWithdrawalIfNeeded: find transaction: %w", err)
	}
	if err := uc.walletRepo.ReleaseReservedBalance(ctx, tx.UserID, tx.Amount); err != nil {
		return false, fmt.Errorf("usecase.expireWithdrawalIfNeeded: release hold: %w", err)
	}
	_ = uc.txRepo.CreateWithdrawalAuditLog(ctx, &domain.WithdrawalAuditLog{
		TransactionID:       tx.ID,
		WithdrawalRequestID: &req.ID,
		ActorRole:           "system",
		Action:              "withdrawal_expired",
		Details: domain.JSONMap{
			"expired_at": now,
			"status":     string(domain.WithdrawalRequestExpired),
		},
	})
	return true, nil
}

func (uc *PaymentUseCase) GetAssignedWithdrawalsForAgent(ctx context.Context, agentID string, status domain.WithdrawalRequestStatus, page, limit int) ([]*domain.WithdrawalRequestWithTransaction, int64, error) {
	reqs, total, err := uc.txRepo.ListAssignedWithdrawals(ctx, agentID, status, page, limit)
	if err != nil {
		return nil, 0, fmt.Errorf("usecase.GetAssignedWithdrawalsForAgent: %w", err)
	}
	items := make([]*domain.WithdrawalRequestWithTransaction, 0, len(reqs))
	for _, req := range reqs {
		if _, expiryErr := uc.expireWithdrawalIfNeeded(ctx, req); expiryErr != nil {
			return nil, 0, expiryErr
		}
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
	if expired, expiryErr := uc.expireWithdrawalIfNeeded(ctx, req); expiryErr != nil {
		return nil, expiryErr
	} else if expired {
		return nil, apperrors.NewBadRequestError("Withdrawal request expired; ask the customer to submit a new request")
	}

	tx, err := uc.txRepo.FindByID(ctx, req.TransactionID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Withdrawal request not found")
	}
	if tx.Status != domain.TransactionPending {
		return nil, apperrors.NewBadRequestError("Only pending withdrawals can be processed")
	}

	agentBalanceBefore, err := uc.walletRepo.GetBalance(ctx, req.AgentID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Agent wallet not found")
	}
	if err := uc.walletRepo.SettleReservedTransfer(ctx, tx.UserID, req.AgentID, tx.Amount); err != nil {
		if errors.Is(err, domain.ErrInsufficientAvailableBalance) {
			return nil, apperrors.NewBadRequestError("The held withdrawal amount is no longer available")
		}
		return nil, fmt.Errorf("usecase.VerifyWithdrawalCode: settle agent transfer: %w", err)
	}

	ref := fmt.Sprintf("paid-by-agent:%s", agentID)
	customerBalanceAfter := tx.BalanceBefore - tx.Amount
	if err := uc.txRepo.UpdateSettlement(ctx, tx.ID, domain.TransactionCompleted, ref, tx.BalanceBefore, customerBalanceAfter); err != nil {
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

	// Keep an agent-side ledger entry for reconciliation and agent reporting.
	fromUserID := tx.UserID
	toUserID := req.AgentID
	_ = uc.txRepo.Create(ctx, &domain.Transaction{
		UserID:         req.AgentID,
		Type:           domain.TransactionAgentPayout,
		Amount:         tx.Amount,
		Currency:       tx.Currency,
		Status:         domain.TransactionCompleted,
		IdempotencyKey: fmt.Sprintf("agent-payout-%s-%s", tx.ID, req.AgentID),
		Reference:      ref,
		Description:    "Agent payout received for customer withdrawal",
		FromUserID:     &fromUserID,
		ToUserID:       &toUserID,
		BalanceBefore:  agentBalanceBefore,
		BalanceAfter:   agentBalanceBefore + tx.Amount,
	})

	tx.Status = domain.TransactionCompleted
	tx.Reference = ref
	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.PaymentWithdraw,
		Payload: map[string]interface{}{
			"user_id":  tx.UserID,
			"agent_id": req.AgentID,
			"amount":   tx.Amount,
			"currency": tx.Currency,
			"tx_id":    tx.ID,
		},
	})
	return tx, nil
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

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
	ciphertext := gcm.Seal(nonce, nonce, []byte(value), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// ─── Location-based Withdrawal Flow ─────────────────────────────────

// GetAgentLocations returns cities with at least one active registered agent.
func (uc *PaymentUseCase) GetAgentLocations(ctx context.Context) ([]string, error) {
	return uc.txRepo.FindAgentLocations(ctx)
}

// GetAgentsByLocation returns active agents for a legacy location value.
func (uc *PaymentUseCase) GetAgentsByLocation(ctx context.Context, location string) ([]*domain.AgentInfo, error) {
	return uc.txRepo.FindAgentsByLocation(ctx, location)
}

// GetAgentRegions returns Myanmar regions/states with active agents.
func (uc *PaymentUseCase) GetAgentRegions(ctx context.Context) ([]string, error) {
	return uc.txRepo.FindAgentRegions(ctx)
}

// GetAgentTownships returns townships within a selected region/state.
func (uc *PaymentUseCase) GetAgentTownships(ctx context.Context, region string) ([]string, error) {
	return uc.txRepo.FindAgentTownships(ctx, region)
}

// GetAgentsByRegionTownship returns active agents registered in one township.
func (uc *PaymentUseCase) GetAgentsByRegionTownship(ctx context.Context, region, township string) ([]*domain.AgentInfo, error) {
	return uc.txRepo.FindAgentsByRegionTownship(ctx, region, township)
}

// CreateLocationBasedWithdrawal creates a withdrawal request with region,
// township, and agent selection.
func (uc *PaymentUseCase) CreateLocationBasedWithdrawal(ctx context.Context, userID string, req *domain.CreateWithdrawalRequest, agentID string) (*domain.WithdrawalRequest, error) {
	if req.Amount <= 0 || math.IsNaN(req.Amount) || math.IsInf(req.Amount, 0) {
		return nil, apperrors.NewBadRequestError("Withdrawal amount must be a valid positive number")
	}
	if err := uc.checkWithdrawalEligibility(ctx, userID); err != nil {
		return nil, err
	}

	if strings.TrimSpace(req.Region) == "" || strings.TrimSpace(req.Township) == "" {
		return nil, apperrors.NewBadRequestError("Region and township are required")
	}

	region := strings.TrimSpace(req.Region)
	township := strings.TrimSpace(req.Township)
	selectedAgentID := strings.TrimSpace(agentID)
	if region == "" || township == "" || selectedAgentID == "" {
		return nil, apperrors.NewBadRequestError("Region, township, and agent are required")
	}

	agents, err := uc.txRepo.FindAgentsByRegionTownship(ctx, region, township)
	if err != nil {
		return nil, fmt.Errorf("paymentUseCase.CreateLocationBasedWithdrawal: find agents: %w", err)
	}
	selectedAgent := false
	for _, agent := range agents {
		if agent != nil && strings.TrimSpace(agent.ID) == selectedAgentID {
			selectedAgent = true
			break
		}
	}
	if !selectedAgent {
		return nil, apperrors.NewBadRequestError("The selected agent is not active in this township")
	}

	currentBalance, err := uc.walletRepo.GetBalance(ctx, userID)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Wallet not found")
	}

	// Reserve the requested amount immediately. The customer's total balance
	// remains unchanged until the assigned agent confirms payout, but the held
	// amount is no longer available for another withdrawal or bet.
	if err := uc.walletRepo.ReserveBalance(ctx, userID, req.Amount); err != nil {
		if errors.Is(err, domain.ErrInsufficientAvailableBalance) {
			return nil, apperrors.NewBadRequestError("Insufficient available balance")
		}
		return nil, fmt.Errorf("paymentUseCase.CreateLocationBasedWithdrawal: reserve balance: %w", err)
	}

	code, err := uc.generateVerificationCode()
	if err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		return nil, fmt.Errorf("paymentUseCase.CreateLocationBasedWithdrawal: generate code: %w", err)
	}

	// Hash the code
	codeHash, err := hashCode(code)
	if err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		return nil, fmt.Errorf("paymentUseCase.CreateLocationBasedWithdrawal: hash code: %w", err)
	}

	// Encrypt account details
	encryptedDetails, err := uc.encryptSensitive(req.AccountDetails)
	if err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		return nil, fmt.Errorf("paymentUseCase.CreateLocationBasedWithdrawal: encrypt account details: %w", err)
	}

	// Create transaction record first. Production databases may enforce a
	// non-null idempotency key even when older migrations allowed NULL, so the
	// location-based flow must provide one just like the legacy withdrawal flow.
	idempotencyKey := fmt.Sprintf("location-withdrawal-%s-%d", userID, time.Now().UnixNano())
	tx := &domain.Transaction{
		UserID:         userID,
		Type:           domain.TransactionWithdraw,
		Amount:         req.Amount,
		Currency:       "MMK",
		Status:         domain.TransactionPending,
		IdempotencyKey: idempotencyKey,
		Description:    "Withdrawal request; amount held pending agent payout",
		BalanceBefore:  currentBalance,
		BalanceAfter:   currentBalance,
	}

	if err := uc.txRepo.Create(ctx, tx); err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		return nil, fmt.Errorf("paymentUseCase.CreateLocationBasedWithdrawal: create transaction: %w", err)
	}

	// Create withdrawal request
	withdrawalReq := &domain.WithdrawalRequest{
		TransactionID:           tx.ID,
		CustomerID:              userID,
		AgentID:                 selectedAgentID,
		VerificationCodeHash:    codeHash,
		CodeLookupHash:          uc.lookupHash(code),
		AccountDetailsEncrypted: encryptedDetails,
		Status:                  domain.WithdrawalRequestPending,
		Location:                strings.TrimSpace(req.Location),
		Region:                  region,
		Township:                township,
		Code:                    code,

		ExpiresAt: timePtr(time.Now().Add(24 * time.Hour)),
	}

	if err := uc.txRepo.CreateWithdrawalRequest(ctx, withdrawalReq); err != nil {
		_ = uc.walletRepo.ReleaseReservedBalance(ctx, userID, req.Amount)
		_ = uc.txRepo.UpdateStatus(ctx, tx.ID, domain.TransactionCancelled)
		return nil, fmt.Errorf("paymentUseCase.CreateLocationBasedWithdrawal: create request: %w", err)
	}

	_ = uc.eventBus.Publish(ctx, event.Event{
		Type: event.PaymentWithdrawalRequested,
		Payload: map[string]interface{}{
			"user_id":    userID,
			"agent_id":   selectedAgentID,
			"amount":     req.Amount,
			"currency":   tx.Currency,
			"request_id": withdrawalReq.ID,
			"tx_id":      tx.ID,
		},
	})

	return withdrawalReq, nil
}

// ApproveWithdrawalByCode approves a withdrawal request using the verification code
func (uc *PaymentUseCase) ApproveWithdrawalByCode(ctx context.Context, code string) (*domain.WithdrawalRequest, error) {
	// Find withdrawal request by code
	req, err := uc.txRepo.FindWithdrawalRequestByCode(ctx, code)
	if err != nil {
		return nil, apperrors.NewNotFoundError("Invalid withdrawal code")
	}

	// Check status
	if req.Status != domain.WithdrawalRequestPending {
		return nil, apperrors.NewBadRequestError("Withdrawal request is not pending")
	}

	// Check expiration
	if req.ExpiresAt != nil && time.Now().After(*req.ExpiresAt) {
		return nil, apperrors.NewBadRequestError("Withdrawal code has expired")
	}

	// Get transaction to get amount
	tx, err := uc.txRepo.FindByID(ctx, req.TransactionID)
	if err != nil {
		return nil, fmt.Errorf("paymentUseCase.ApproveWithdrawalByCode: %w", err)
	}

	// Approve the request
	now := time.Now()
	if err := uc.txRepo.ApproveWithdrawalRequest(ctx, req.ID, now); err != nil {
		return nil, fmt.Errorf("paymentUseCase.ApproveWithdrawalByCode: %w", err)
	}

	// Update transaction status
	if err := uc.txRepo.UpdateStatus(ctx, req.TransactionID, "completed"); err != nil {
		return nil, fmt.Errorf("paymentUseCase.ApproveWithdrawalByCode: %w", err)
	}

	// Deduct from user wallet
	if err := uc.walletRepo.UpdateBalance(ctx, req.CustomerID, -tx.Amount); err != nil {
		return nil, fmt.Errorf("paymentUseCase.ApproveWithdrawalByCode: %w", err)
	}

	// Refresh the request
	req.Status = domain.WithdrawalRequestApproved
	req.ApprovedAt = &now

	return req, nil
}

// CancelWithdrawalRequest cancels a pending withdrawal request
func (uc *PaymentUseCase) CancelWithdrawalRequest(ctx context.Context, requestID, customerID string) error {
	// Find the request by its ID (or its linked transaction ID).
	req, err := uc.txRepo.FindWithdrawalRequestByID(ctx, requestID)
	if err != nil {
		return apperrors.NewNotFoundError("Withdrawal request not found")
	}

	if req.CustomerID != customerID {
		return apperrors.NewForbiddenError("You can only cancel your own withdrawal requests")
	}

	// Check status
	if req.Status != domain.WithdrawalRequestPending {
		return apperrors.NewBadRequestError("Only pending withdrawals can be cancelled")
	}

	if tx, txErr := uc.txRepo.FindByID(ctx, req.TransactionID); txErr == nil {
		if err := uc.walletRepo.ReleaseReservedBalance(ctx, req.CustomerID, tx.Amount); err != nil {
			return fmt.Errorf("paymentUseCase.CancelWithdrawalRequest: release reserved balance: %w", err)
		}
	}

	// Cancel the request
	now := time.Now()
	if err := uc.txRepo.CancelWithdrawalRequest(ctx, req.ID, now); err != nil {
		return fmt.Errorf("paymentUseCase.CancelWithdrawalRequest: %w", err)
	}

	// Update transaction status
	if err := uc.txRepo.UpdateStatus(ctx, req.TransactionID, "cancelled"); err != nil {
		return fmt.Errorf("paymentUseCase.CancelWithdrawalRequest: %w", err)
	}

	return nil
}

func timePtr(t time.Time) *time.Time {
	return &t
}
