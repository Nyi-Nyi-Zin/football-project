package repository

import (
	"context"
	"fmt"
	"time"

	"betting-app/internal/modules/support/domain"
	"gorm.io/gorm"
)

type postgresSupportRepo struct {
	db *gorm.DB
}

func NewPostgresSupportRepo(db *gorm.DB) domain.SupportRepository {
	return &postgresSupportRepo{db: db}
}

func (r *postgresSupportRepo) CreateTicket(ctx context.Context, ticket *domain.SupportTicket) error {
	if err := r.db.WithContext(ctx).Create(ticket).Error; err != nil {
		return fmt.Errorf("supportRepo.CreateTicket: %w", err)
	}
	return nil
}

func (r *postgresSupportRepo) FindTicket(ctx context.Context, ticketID string) (*domain.SupportTicket, error) {
	var ticket domain.SupportTicket
	if err := r.db.WithContext(ctx).Where("id = ?", ticketID).First(&ticket).Error; err != nil {
		return nil, fmt.Errorf("supportRepo.FindTicket: %w", err)
	}
	return &ticket, nil
}

func (r *postgresSupportRepo) ListTickets(ctx context.Context, requesterID, role string, page, limit int) ([]*domain.SupportTicket, int64, error) {
	var tickets []*domain.SupportTicket
	query := r.db.WithContext(ctx).Model(&domain.SupportTicket{})
	if role != "admin" {
		query = query.Where("requester_id = ?", requesterID)
	}
	var total int64
	if err := query.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("supportRepo.ListTickets: count: %w", err)
	}
	offset := (page - 1) * limit
	if err := query.Order("updated_at DESC").Offset(offset).Limit(limit).Find(&tickets).Error; err != nil {
		return nil, 0, fmt.Errorf("supportRepo.ListTickets: find: %w", err)
	}
	return tickets, total, nil
}

func (r *postgresSupportRepo) CreateMessage(ctx context.Context, message *domain.SupportMessage) error {
	if err := r.db.WithContext(ctx).Create(message).Error; err != nil {
		return fmt.Errorf("supportRepo.CreateMessage: %w", err)
	}
	return nil
}

func (r *postgresSupportRepo) ListMessages(ctx context.Context, ticketID string) ([]*domain.SupportMessage, error) {
	var messages []*domain.SupportMessage
	if err := r.db.WithContext(ctx).Where("ticket_id = ?", ticketID).Order("created_at ASC").Find(&messages).Error; err != nil {
		return nil, fmt.Errorf("supportRepo.ListMessages: %w", err)
	}
	return messages, nil
}

func (r *postgresSupportRepo) UpdateStatus(ctx context.Context, ticketID string, status domain.TicketStatus, assignedTo *string, resolvedAt *time.Time) error {
	result := r.db.WithContext(ctx).Model(&domain.SupportTicket{}).Where("id = ?", ticketID).Updates(map[string]interface{}{
		"status":      status,
		"assigned_to": assignedTo,
		"resolved_at": resolvedAt,
	})
	if result.Error != nil {
		return fmt.Errorf("supportRepo.UpdateStatus: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}
