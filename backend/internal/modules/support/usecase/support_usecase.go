package usecase

import (
	"context"
	"errors"
	"strings"
	"time"

	"betting-app/internal/modules/support/domain"
	apperrors "betting-app/internal/shared/errors"
	"gorm.io/gorm"
)

type SupportUseCase struct {
	repo domain.SupportRepository
}

func NewSupportUseCase(repo domain.SupportRepository) *SupportUseCase {
	return &SupportUseCase{repo: repo}
}

func (uc *SupportUseCase) CreateTicket(ctx context.Context, requesterID string, req *domain.CreateTicketRequest) (*domain.SupportTicket, error) {
	req.Subject = strings.TrimSpace(req.Subject)
	req.Category = strings.TrimSpace(req.Category)
	req.Description = strings.TrimSpace(req.Description)
	if req.Priority == "" {
		req.Priority = domain.TicketPriorityNormal
	}
	if req.Subject == "" || req.Category == "" || req.Description == "" {
		return nil, apperrors.NewValidationError("Ticket fields are required", nil)
	}
	ticket := &domain.SupportTicket{
		RequesterID: requesterID,
		Subject:     req.Subject,
		Category:    req.Category,
		Priority:    req.Priority,
		Status:      domain.TicketStatusOpen,
		Description: req.Description,
	}
	if err := uc.repo.CreateTicket(ctx, ticket); err != nil {
		return nil, err
	}
	return ticket, nil
}

func (uc *SupportUseCase) ListTickets(ctx context.Context, requesterID, role string, page, limit int) ([]*domain.SupportTicket, int64, error) {
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 50 {
		limit = 20
	}
	return uc.repo.ListTickets(ctx, requesterID, role, page, limit)
}

func (uc *SupportUseCase) GetTicket(ctx context.Context, ticketID, requesterID, role string) (*domain.SupportTicket, error) {
	ticket, err := uc.repo.FindTicket(ctx, ticketID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.NewNotFoundError("Support ticket not found")
		}
		return nil, err
	}
	if role != "admin" && ticket.RequesterID != requesterID {
		return nil, apperrors.NewForbiddenError("You cannot access this support ticket")
	}
	return ticket, nil
}

func (uc *SupportUseCase) ListMessages(ctx context.Context, ticketID, requesterID, role string) ([]*domain.SupportMessage, error) {
	if _, err := uc.GetTicket(ctx, ticketID, requesterID, role); err != nil {
		return nil, err
	}
	return uc.repo.ListMessages(ctx, ticketID)
}

func (uc *SupportUseCase) AddMessage(ctx context.Context, ticketID, authorID, role string, req *domain.AddMessageRequest) (*domain.SupportMessage, error) {
	if _, err := uc.GetTicket(ctx, ticketID, authorID, role); err != nil {
		return nil, err
	}
	body := strings.TrimSpace(req.Body)
	if body == "" {
		return nil, apperrors.NewValidationError("Message body is required", nil)
	}
	message := &domain.SupportMessage{TicketID: ticketID, AuthorID: authorID, AuthorRole: role, Body: body}
	if err := uc.repo.CreateMessage(ctx, message); err != nil {
		return nil, err
	}
	return message, nil
}

func (uc *SupportUseCase) UpdateStatus(ctx context.Context, ticketID, actorID string, status domain.TicketStatus) (*domain.SupportTicket, error) {
	ticket, err := uc.GetTicket(ctx, ticketID, actorID, "admin")
	if err != nil {
		return nil, err
	}
	var resolvedAt *time.Time
	if status == domain.TicketStatusResolved || status == domain.TicketStatusClosed {
		now := time.Now().UTC()
		resolvedAt = &now
	}
	if err := uc.repo.UpdateStatus(ctx, ticketID, status, &actorID, resolvedAt); err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, apperrors.NewNotFoundError("Support ticket not found")
		}
		return nil, err
	}
	ticket.Status = status
	ticket.AssignedTo = &actorID
	ticket.ResolvedAt = resolvedAt
	return ticket, nil
}
