package usecase

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"betting-app/internal/modules/payment/domain"
	"betting-app/internal/shared/event"
)

type fakeTxRepo struct {
	txByID           map[string]*domain.Transaction
	withdrawalByID   map[string]*domain.WithdrawalRequest
	withdrawalByKey  map[string]*domain.WithdrawalRequest
	leastLoadedAgent string
}

func newFakeTxRepo() *fakeTxRepo {
	return &fakeTxRepo{
		txByID:          map[string]*domain.Transaction{},
		withdrawalByID:  map[string]*domain.WithdrawalRequest{},
		withdrawalByKey: map[string]*domain.WithdrawalRequest{},
	}
}

func (f *fakeTxRepo) Create(_ context.Context, tx *domain.Transaction) error {
	if tx.ID == "" {
		tx.ID = fmt.Sprintf("tx-%d", len(f.txByID)+1)
	}
	f.txByID[tx.ID] = tx
	return nil
}

func (f *fakeTxRepo) FindByID(_ context.Context, id string) (*domain.Transaction, error) {
	return f.txByID[id], nil
}

func (f *fakeTxRepo) FindByIdempotencyKey(_ context.Context, _ string) (*domain.Transaction, error) {
	return nil, nil
}

func (f *fakeTxRepo) FindByUser(_ context.Context, _ string, _ int, _ int) ([]*domain.Transaction, int64, error) {
	return nil, 0, nil
}

func (f *fakeTxRepo) ListAgentCustomerTransactions(_ context.Context, _, _ string, _ int, _ int) ([]*domain.Transaction, int64, error) {
	return nil, 0, nil
}

func (f *fakeTxRepo) GetAgentDashboardStats(_ context.Context, _ string) (int, float64, float64, int, error) {
	return 0, 0, 0, 0, nil
}

func (f *fakeTxRepo) GetAgentEarningsSummary(_ context.Context, _ string, from, to time.Time) (*domain.AgentEarningsSummary, error) {
	return &domain.AgentEarningsSummary{From: from, To: to, PeriodDays: int(to.Sub(from).Hours() / 24), Currency: "MMK"}, nil
}

func (f *fakeTxRepo) ListAll(_ context.Context, _ domain.TransactionFilter, _ int, _ int) ([]*domain.Transaction, int64, error) {
	return nil, 0, nil
}

func (f *fakeTxRepo) GetReconciliationTotals(_ context.Context) (*domain.ReconciliationTotals, error) {
	return &domain.ReconciliationTotals{}, nil
}

func (f *fakeTxRepo) ListLedgerBalances(_ context.Context) ([]*domain.UserLedgerBalance, error) {
	return nil, nil
}

func (f *fakeTxRepo) UpdateStatus(_ context.Context, _ string, _ domain.TransactionStatus) error {
	return nil
}

func (f *fakeTxRepo) UpdateSettlement(_ context.Context, txID string, status domain.TransactionStatus, reference string, balanceBefore, balanceAfter float64) error {
	tx := f.txByID[txID]
	tx.Status = status
	tx.Reference = reference
	tx.BalanceBefore = balanceBefore
	tx.BalanceAfter = balanceAfter
	return nil
}

func (f *fakeTxRepo) UpdateStatusAndReference(_ context.Context, txID string, status domain.TransactionStatus, reference string) error {
	tx := f.txByID[txID]
	tx.Status = status
	tx.Reference = reference
	return nil
}

func (f *fakeTxRepo) FindLeastLoadedActiveAgentID(_ context.Context) (string, error) {
	return f.leastLoadedAgent, nil
}

func (f *fakeTxRepo) CreateWithdrawalRequest(_ context.Context, req *domain.WithdrawalRequest) error {
	if req.ID == "" {
		req.ID = "wr-1"
	}
	f.withdrawalByID[req.ID] = req
	key := req.AgentID + ":" + req.CodeLookupHash
	f.withdrawalByKey[key] = req
	return nil
}

func (f *fakeTxRepo) FindPendingWithdrawalByAgentAndLookup(_ context.Context, agentID, lookupHash string) (*domain.WithdrawalRequest, error) {
	return f.withdrawalByKey[agentID+":"+lookupHash], nil
}

func (f *fakeTxRepo) ListAssignedWithdrawals(_ context.Context, _ string, _ domain.WithdrawalRequestStatus, _ int, _ int) ([]*domain.WithdrawalRequest, int64, error) {
	return nil, 0, nil
}

func (f *fakeTxRepo) ListAgentCustomerWithdrawals(_ context.Context, _, _ string, _ int, _ int) ([]*domain.WithdrawalRequest, int64, error) {
	return nil, 0, nil
}

func (f *fakeTxRepo) ExpireWithdrawalRequest(_ context.Context, requestID string, expiredAt time.Time) (bool, error) {
	for _, req := range f.withdrawalByID {
		if (req.ID == requestID || req.TransactionID == requestID) && req.Status == domain.WithdrawalRequestPending {
			req.Status = domain.WithdrawalRequestExpired
			req.CancelledAt = &expiredAt
			return true, nil
		}
	}
	return false, nil
}

func (f *fakeTxRepo) UpdateWithdrawalRequestStatus(_ context.Context, requestID string, status domain.WithdrawalRequestStatus, verifiedAt *time.Time) error {
	req := f.withdrawalByID[requestID]
	if req == nil {
		return nil
	}
	req.Status = status
	req.VerifiedAt = verifiedAt
	return nil
}

func (f *fakeTxRepo) CreateWithdrawalAuditLog(_ context.Context, _ *domain.WithdrawalAuditLog) error {
	return nil
}

func (f *fakeTxRepo) ListCustomerWithdrawals(_ context.Context, customerID string, _ domain.WithdrawalRequestStatus, _ int, _ int) ([]*domain.WithdrawalRequest, int64, error) {
	items := make([]*domain.WithdrawalRequest, 0)
	for _, req := range f.withdrawalByID {
		if req.CustomerID == customerID {
			items = append(items, req)
		}
	}
	return items, int64(len(items)), nil
}

func (f *fakeTxRepo) FindAgentLocations(_ context.Context) ([]string, error) {
	return []string{"Yangon"}, nil
}

func (f *fakeTxRepo) FindAgentsByLocation(_ context.Context, _ string) ([]*domain.AgentInfo, error) {
	return []*domain.AgentInfo{{
		ID:       "agent-1",
		FullName: "Yangon Agent",
		Region:   "Yangon Region",
		Township: "Tamwe",
		Location: "Tamwe",
	}}, nil
}

func (f *fakeTxRepo) FindAgentRegions(_ context.Context) ([]string, error) {
	return []string{"Yangon Region"}, nil
}

func (f *fakeTxRepo) FindAgentTownships(_ context.Context, _ string) ([]string, error) {
	return []string{"Tamwe"}, nil
}

func (f *fakeTxRepo) FindAgentsByRegionTownship(_ context.Context, _, _ string) ([]*domain.AgentInfo, error) {
	return []*domain.AgentInfo{{
		ID:       "agent-1",
		FullName: "Yangon Agent",
		Region:   "Yangon Region",
		Township: "Tamwe",
		Location: "Tamwe",
	}}, nil
}

func (f *fakeTxRepo) FindWithdrawalRequestByCode(_ context.Context, code string) (*domain.WithdrawalRequest, error) {
	return f.withdrawalByKey[code], nil
}

func (f *fakeTxRepo) FindWithdrawalRequestByID(_ context.Context, requestID string) (*domain.WithdrawalRequest, error) {
	if req := f.withdrawalByID[requestID]; req != nil {
		return req, nil
	}
	for _, req := range f.withdrawalByID {
		if req.TransactionID == requestID {
			return req, nil
		}
	}
	return nil, nil
}

func (f *fakeTxRepo) ApproveWithdrawalRequest(_ context.Context, requestID string, approvedAt time.Time) error {
	req := f.withdrawalByID[requestID]
	if req != nil {
		req.Status = domain.WithdrawalRequestApproved
		req.ApprovedAt = &approvedAt
	}
	return nil
}

func (f *fakeTxRepo) CancelWithdrawalRequest(_ context.Context, requestID string, cancelledAt time.Time) error {
	req := f.withdrawalByID[requestID]
	if req != nil {
		req.Status = domain.WithdrawalRequestRejected
		req.CancelledAt = &cancelledAt
	}
	return nil
}

type fakeWalletRepo struct {
	balances map[string]float64
	reserved map[string]float64
}

func (f *fakeWalletRepo) Create(_ context.Context, _ *domain.Wallet) error { return nil }
func (f *fakeWalletRepo) FindByUserID(_ context.Context, _ string) (*domain.Wallet, error) {
	return nil, nil
}
func (f *fakeWalletRepo) ListAll(_ context.Context) ([]*domain.Wallet, error) {
	wallets := make([]*domain.Wallet, 0, len(f.balances))
	for userID, balance := range f.balances {
		wallets = append(wallets, &domain.Wallet{UserID: userID, Balance: balance, ReservedBalance: f.reserved[userID], Currency: "USD"})
	}
	return wallets, nil
}
func (f *fakeWalletRepo) UpdateBalance(_ context.Context, userID string, amount float64) error {
	f.balances[userID] += amount
	return nil
}
func (f *fakeWalletRepo) GetBalance(_ context.Context, userID string) (float64, error) {
	return f.balances[userID], nil
}
func (f *fakeWalletRepo) ReserveBalance(_ context.Context, userID string, amount float64) error {
	if f.reserved == nil {
		f.reserved = map[string]float64{}
	}
	if f.balances[userID]-f.reserved[userID] < amount {
		return domain.ErrInsufficientAvailableBalance
	}
	f.reserved[userID] += amount
	return nil
}
func (f *fakeWalletRepo) ReleaseReservedBalance(_ context.Context, userID string, amount float64) error {
	f.reserved[userID] -= amount
	return nil
}
func (f *fakeWalletRepo) SettleReservedTransfer(_ context.Context, fromUserID, toUserID string, amount float64) error {
	if f.reserved[fromUserID] < amount {
		return domain.ErrInsufficientAvailableBalance
	}
	f.reserved[fromUserID] -= amount
	f.balances[fromUserID] -= amount
	f.balances[toUserID] += amount
	return nil
}
func (f *fakeWalletRepo) TransferBalance(_ context.Context, fromUserID, toUserID string, amount float64) error {
	if f.balances[fromUserID]-f.reserved[fromUserID] < amount {
		return domain.ErrInsufficientAvailableBalance
	}
	f.balances[fromUserID] -= amount
	f.balances[toUserID] += amount
	return nil
}
func (f *fakeWalletRepo) IncrementRequiredTurnover(_ context.Context, _ string, _ float64) error {
	return nil
}
func (f *fakeWalletRepo) IncrementCurrentTurnover(_ context.Context, _ string, _ float64) error {
	return nil
}
func (f *fakeWalletRepo) GetTurnover(_ context.Context, _ string) (float64, float64, error) {
	return 0, 0, nil
}

func TestWithdrawCreatesSecureAgentRequest(t *testing.T) {
	txRepo := newFakeTxRepo()
	txRepo.leastLoadedAgent = "agent-1"
	walletRepo := &fakeWalletRepo{balances: map[string]float64{"user-1": 100}, reserved: map[string]float64{}}
	uc := NewPaymentUseCase(txRepo, walletRepo, event.NewBus(), SecurityOptions{
		CodePepper:    "pepper",
		EncryptionKey: "encryption-key",
	})

	res, err := uc.Withdraw(context.Background(), "user-1", &domain.WithdrawRequest{
		Amount:         20,
		Currency:       "USD",
		IdempotencyKey: "idem-1",
		PaymentMethod:  "agent",
		AccountDetails: "09-123456789",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.VerificationCode == "" || len(res.VerificationCode) != 6 {
		t.Fatalf("expected 6-char code, got %q", res.VerificationCode)
	}
	if res.AssignedAgentID != "agent-1" {
		t.Fatalf("expected assigned agent, got %q", res.AssignedAgentID)
	}
	req := txRepo.withdrawalByID["wr-1"]
	if req == nil {
		t.Fatal("expected withdrawal request to be created")
	}
	if strings.Contains(req.AccountDetailsEncrypted, "09-123456789") {
		t.Fatal("expected account details to be encrypted")
	}
}

func TestLocationWithdrawalHoldsThenSettlesToAgent(t *testing.T) {
	txRepo := newFakeTxRepo()
	walletRepo := &fakeWalletRepo{
		balances: map[string]float64{"user-1": 100},
		reserved: map[string]float64{},
	}
	uc := NewPaymentUseCase(txRepo, walletRepo, event.NewBus(), SecurityOptions{
		CodePepper:    "pepper",
		EncryptionKey: "encryption-key",
	})

	request, err := uc.CreateLocationBasedWithdrawal(context.Background(), "user-1", &domain.CreateWithdrawalRequest{
		Amount:         30,
		Region:         "Yangon Region",
		Township:       "Tamwe",
		Location:       "Tamwe",
		AccountDetails: "09-123456789",
	}, "agent-1")

	if err != nil {
		t.Fatalf("create location withdrawal failed: %v", err)
	}
	if walletRepo.balances["user-1"] != 100 {
		t.Fatalf("expected total balance to remain 100 while pending, got %v", walletRepo.balances["user-1"])
	}
	if walletRepo.reserved["user-1"] != 30 {
		t.Fatalf("expected 30 held while pending, got %v", walletRepo.reserved["user-1"])
	}

	if _, err := uc.VerifyWithdrawalCode(context.Background(), "agent-1", request.Code); err != nil {
		t.Fatalf("agent confirmation failed: %v", err)
	}
	if walletRepo.balances["user-1"] != 70 || walletRepo.balances["agent-1"] != 30 {
		t.Fatalf("expected customer 70 and agent 30, got customer=%v agent=%v", walletRepo.balances["user-1"], walletRepo.balances["agent-1"])
	}
	if walletRepo.reserved["user-1"] != 0 {
		t.Fatalf("expected hold to be released after settlement, got %v", walletRepo.reserved["user-1"])
	}
}

func TestVerifyWithdrawalCodeApprovesAndDeducts(t *testing.T) {
	txRepo := newFakeTxRepo()
	txRepo.leastLoadedAgent = "agent-1"
	walletRepo := &fakeWalletRepo{balances: map[string]float64{"user-1": 100}, reserved: map[string]float64{}}
	uc := NewPaymentUseCase(txRepo, walletRepo, event.NewBus(), SecurityOptions{
		CodePepper:    "pepper",
		EncryptionKey: "encryption-key",
	})

	res, err := uc.Withdraw(context.Background(), "user-1", &domain.WithdrawRequest{
		Amount:         25,
		Currency:       "USD",
		IdempotencyKey: "idem-2",
		PaymentMethod:  "agent",
		AccountDetails: "kpay-acc",
	})
	if err != nil {
		t.Fatalf("withdraw failed: %v", err)
	}

	approved, err := uc.VerifyWithdrawalCode(context.Background(), "agent-1", res.VerificationCode)
	if err != nil {
		t.Fatalf("verify failed: %v", err)
	}
	if approved.Status != domain.TransactionCompleted {
		t.Fatalf("expected completed tx status, got %s", approved.Status)
	}
	if walletRepo.balances["user-1"] != 75 {
		t.Fatalf("expected deducted balance 75, got %v", walletRepo.balances["user-1"])
	}
	if walletRepo.balances["agent-1"] != 25 {
		t.Fatalf("expected agent balance 25, got %v", walletRepo.balances["agent-1"])
	}
	if walletRepo.reserved["user-1"] != 0 {
		t.Fatalf("expected reserved balance released, got %v", walletRepo.reserved["user-1"])
	}
	req := txRepo.withdrawalByID["wr-1"]
	if req.Status != domain.WithdrawalRequestApproved {
		t.Fatalf("expected approved request status, got %s", req.Status)
	}
}

func TestAgentDepositToCustomerDebitsAgentAndCreditsCustomer(t *testing.T) {
	txRepo := newFakeTxRepo()
	walletRepo := &fakeWalletRepo{
		balances: map[string]float64{
			"agent-1":    1000,
			"customer-1": 100,
		},
		reserved: map[string]float64{},
	}
	uc := NewPaymentUseCase(txRepo, walletRepo, event.NewBus(), SecurityOptions{})

	customerTx, err := uc.AgentDepositToCustomer(context.Background(), &domain.AgentCustomerDepositRequest{
		CustomerID:  "customer-1",
		Amount:      250,
		PerformedBy: "agent-1",
	})
	if err != nil {
		t.Fatalf("AgentDepositToCustomer returned error: %v", err)
	}
	if customerTx.UserID != "customer-1" || customerTx.Type != domain.TransactionDeposit {
		t.Fatalf("unexpected customer transaction: %+v", customerTx)
	}
	if got := walletRepo.balances["agent-1"]; got != 750 {
		t.Fatalf("agent balance = %.2f, want 750", got)
	}
	if got := walletRepo.balances["customer-1"]; got != 350 {
		t.Fatalf("customer balance = %.2f, want 350", got)
	}
	if len(txRepo.txByID) != 2 {
		t.Fatalf("transaction count = %d, want 2", len(txRepo.txByID))
	}
	var agentDepositFound bool
	for _, tx := range txRepo.txByID {
		if tx.UserID == "agent-1" && tx.Type == domain.TransactionAgentCustomerDeposit && tx.Amount == 250 {
			if tx.FromUserID == nil || *tx.FromUserID != "agent-1" || tx.ToUserID == nil || *tx.ToUserID != "customer-1" {
				t.Fatalf("unexpected Agent transfer parties: %+v", tx)
			}
			agentDepositFound = true
		}
	}
	if !agentDepositFound {
		t.Fatal("expected Agent customer deposit transaction")
	}
}

func TestAgentEarningsSummaryUsesBoundedPeriod(t *testing.T) {
	uc := NewPaymentUseCase(newFakeTxRepo(), &fakeWalletRepo{balances: map[string]float64{}}, event.NewBus(), SecurityOptions{})

	defaultSummary, err := uc.GetAgentEarningsSummary(context.Background(), "agent-1", 0)
	if err != nil {
		t.Fatalf("default earnings summary: %v", err)
	}
	if defaultSummary.PeriodDays != 30 {
		t.Fatalf("default period = %d, want 30", defaultSummary.PeriodDays)
	}

	cappedSummary, err := uc.GetAgentEarningsSummary(context.Background(), "agent-1", 365)
	if err != nil {
		t.Fatalf("capped earnings summary: %v", err)
	}
	if cappedSummary.PeriodDays != 90 {
		t.Fatalf("capped period = %d, want 90", cappedSummary.PeriodDays)
	}
}

func TestExpiredWithdrawalReleasesHoldAndBlocksPayout(t *testing.T) {
	txRepo := newFakeTxRepo()
	walletRepo := &fakeWalletRepo{
		balances: map[string]float64{"customer-1": 100, "agent-1": 0},
		reserved: map[string]float64{"customer-1": 20},
	}
	uc := NewPaymentUseCase(txRepo, walletRepo, event.NewBus(), SecurityOptions{
		CodePepper:    "pepper",
		EncryptionKey: "encryption-key",
	})
	code := "ABC123"
	hash, err := hashCode(code)
	if err != nil {
		t.Fatalf("hash code: %v", err)
	}
	tx := &domain.Transaction{
		ID:       "tx-expired",
		UserID:   "customer-1",
		Type:     domain.TransactionWithdraw,
		Amount:   20,
		Currency: "MMK",
		Status:   domain.TransactionPending,
	}
	if err := txRepo.Create(context.Background(), tx); err != nil {
		t.Fatalf("create transaction: %v", err)
	}
	req := &domain.WithdrawalRequest{
		ID:                   "wr-expired",
		TransactionID:        tx.ID,
		CustomerID:           "customer-1",
		AgentID:              "agent-1",
		VerificationCodeHash: hash,
		CodeLookupHash:       uc.lookupHash(code),
		Status:               domain.WithdrawalRequestPending,
		ExpiresAt:            func() *time.Time { value := time.Now().UTC().Add(-time.Minute); return &value }(),
	}
	if err := txRepo.CreateWithdrawalRequest(context.Background(), req); err != nil {
		t.Fatalf("create request: %v", err)
	}

	_, err = uc.VerifyWithdrawalCode(context.Background(), "agent-1", code)
	if err == nil || !strings.Contains(err.Error(), "expired") {
		t.Fatalf("expected expired payout error, got %v", err)
	}
	if req.Status != domain.WithdrawalRequestExpired {
		t.Fatalf("request status = %s, want expired", req.Status)
	}
	if walletRepo.reserved["customer-1"] != 0 {
		t.Fatalf("reserved balance = %.2f, want 0", walletRepo.reserved["customer-1"])
	}
	if walletRepo.balances["customer-1"] != 100 || walletRepo.balances["agent-1"] != 0 {
		t.Fatalf("balances changed after expiry: customer=%.2f agent=%.2f", walletRepo.balances["customer-1"], walletRepo.balances["agent-1"])
	}
}
