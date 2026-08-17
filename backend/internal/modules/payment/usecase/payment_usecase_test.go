package usecase

import (
	"context"
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
		tx.ID = "tx-1"
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

func (f *fakeTxRepo) FindAgentLocations(_ context.Context) ([]string, error) {
	return []string{"Yangon"}, nil
}

func (f *fakeTxRepo) FindAgentsByLocation(_ context.Context, _ string) ([]*domain.AgentInfo, error) {
	return []*domain.AgentInfo{{
		ID:       "agent-1",
		FullName: "Yangon Agent",
		Location: "Yangon",
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
		Location:       "Yangon",
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
