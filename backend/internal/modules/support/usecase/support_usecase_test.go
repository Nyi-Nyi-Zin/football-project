package usecase

import (
	"context"
	"errors"
	"testing"
	"time"

	"betting-app/internal/modules/support/domain"
	apperrors "betting-app/internal/shared/errors"
)

type fakeSupportRepo struct {
	ticket  *domain.SupportTicket
	message *domain.SupportMessage
	status  domain.TicketStatus
}

func (f *fakeSupportRepo) CreateTicket(_ context.Context, ticket *domain.SupportTicket) error {
	ticket.ID = "ticket-1"
	ticket.CreatedAt = time.Now()
	ticket.UpdatedAt = ticket.CreatedAt
	f.ticket = ticket
	return nil
}
func (f *fakeSupportRepo) FindTicket(_ context.Context, _ string) (*domain.SupportTicket, error) {
	return f.ticket, nil
}
func (f *fakeSupportRepo) ListTickets(_ context.Context, _, _ string, _, _ int) ([]*domain.SupportTicket, int64, error) {
	if f.ticket == nil {
		return nil, 0, nil
	}
	return []*domain.SupportTicket{f.ticket}, 1, nil
}
func (f *fakeSupportRepo) CreateMessage(_ context.Context, message *domain.SupportMessage) error {
	message.ID = "message-1"
	f.message = message
	return nil
}
func (f *fakeSupportRepo) ListMessages(_ context.Context, _ string) ([]*domain.SupportMessage, error) {
	if f.message == nil {
		return nil, nil
	}
	return []*domain.SupportMessage{f.message}, nil
}
func (f *fakeSupportRepo) UpdateStatus(_ context.Context, _ string, status domain.TicketStatus, _ *string, _ *time.Time) error {
	f.status = status
	return nil
}

func appError(t *testing.T, err error, code string) {
	t.Helper()
	var appErr *apperrors.AppError
	if !errors.As(err, &appErr) {
		t.Fatalf("expected AppError, got %v", err)
	}
	if appErr.Code != code {
		t.Fatalf("expected error code %s, got %s", code, appErr.Code)
	}
}

func TestCreateTicketDefaultsToNormalPriority(t *testing.T) {
	repo := &fakeSupportRepo{}
	uc := NewSupportUseCase(repo)
	ticket, err := uc.CreateTicket(context.Background(), "agent-1", &domain.CreateTicketRequest{
		Subject:     "Payout help",
		Category:    "payout",
		Description: "The assigned payout needs review.",
	})
	if err != nil {
		t.Fatalf("create ticket: %v", err)
	}
	if ticket.Priority != domain.TicketPriorityNormal || ticket.Status != domain.TicketStatusOpen {
		t.Fatalf("unexpected ticket defaults: %#v", ticket)
	}
	if ticket.RequesterID != "agent-1" {
		t.Fatalf("unexpected requester: %s", ticket.RequesterID)
	}
}

func TestGetTicketRejectsOtherUsers(t *testing.T) {
	repo := &fakeSupportRepo{ticket: &domain.SupportTicket{ID: "ticket-1", RequesterID: "agent-1"}}
	uc := NewSupportUseCase(repo)
	_, err := uc.GetTicket(context.Background(), "ticket-1", "agent-2", "agent")
	appError(t, err, apperrors.CodeForbidden)
}

func TestAddMessageRequiresNonEmptyBody(t *testing.T) {
	repo := &fakeSupportRepo{ticket: &domain.SupportTicket{ID: "ticket-1", RequesterID: "agent-1"}}
	uc := NewSupportUseCase(repo)
	_, err := uc.AddMessage(context.Background(), "ticket-1", "agent-1", "agent", &domain.AddMessageRequest{Body: "   "})
	appError(t, err, apperrors.CodeValidation)
}

func TestAdminCanUpdateStatus(t *testing.T) {
	repo := &fakeSupportRepo{ticket: &domain.SupportTicket{ID: "ticket-1", RequesterID: "agent-1"}}
	uc := NewSupportUseCase(repo)
	ticket, err := uc.UpdateStatus(context.Background(), "ticket-1", "admin-1", domain.TicketStatusResolved)
	if err != nil {
		t.Fatalf("update status: %v", err)
	}
	if ticket.Status != domain.TicketStatusResolved || repo.status != domain.TicketStatusResolved {
		t.Fatalf("unexpected status: ticket=%s repo=%s", ticket.Status, repo.status)
	}
	if ticket.ResolvedAt == nil {
		t.Fatal("expected resolved timestamp")
	}
}
