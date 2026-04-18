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

func (f *fakeTxRepo) UpdateStatus(_ context.Context, _ string, _ domain.TransactionStatus) error {
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

type fakeWalletRepo struct {
	balances map[string]float64
}

func (f *fakeWalletRepo) Create(_ context.Context, _ *domain.Wallet) error { return nil }
func (f *fakeWalletRepo) FindByUserID(_ context.Context, _ string) (*domain.Wallet, error) {
	return nil, nil
}
func (f *fakeWalletRepo) UpdateBalance(_ context.Context, userID string, amount float64) error {
	f.balances[userID] += amount
	return nil
}
func (f *fakeWalletRepo) GetBalance(_ context.Context, userID string) (float64, error) {
	return f.balances[userID], nil
}

func TestWithdrawCreatesSecureAgentRequest(t *testing.T) {
	txRepo := newFakeTxRepo()
	txRepo.leastLoadedAgent = "agent-1"
	walletRepo := &fakeWalletRepo{balances: map[string]float64{"user-1": 100}}
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

func TestVerifyWithdrawalCodeApprovesAndDeducts(t *testing.T) {
	txRepo := newFakeTxRepo()
	txRepo.leastLoadedAgent = "agent-1"
	walletRepo := &fakeWalletRepo{balances: map[string]float64{"user-1": 100}}
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
	req := txRepo.withdrawalByID["wr-1"]
	if req.Status != domain.WithdrawalRequestApproved {
		t.Fatalf("expected approved request status, got %s", req.Status)
	}
}
