package repository

import (
	"context"
	"fmt"
	"strings"

	"betting-app/internal/modules/user/domain"

	"gorm.io/gorm"
)

type postgresUserRepo struct {
	db *gorm.DB
}

// NewPostgresUserRepo creates a new PostgreSQL user repository
func NewPostgresUserRepo(db *gorm.DB) domain.UserRepository {
	return &postgresUserRepo{db: db}
}

func (r *postgresUserRepo) Create(ctx context.Context, user *domain.User) error {
	if err := r.db.WithContext(ctx).Create(user).Error; err != nil {
		return fmt.Errorf("userRepo.Create: %w", err)
	}
	return nil
}

func (r *postgresUserRepo) FindByID(ctx context.Context, id string) (*domain.User, error) {
	var user domain.User
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&user).Error; err != nil {
		return nil, fmt.Errorf("userRepo.FindByID: %w", err)
	}
	return &user, nil
}

func (r *postgresUserRepo) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
	var user domain.User
	if err := r.db.WithContext(ctx).Where("email = ?", email).First(&user).Error; err != nil {
		return nil, fmt.Errorf("userRepo.FindByEmail: %w", err)
	}
	return &user, nil
}

func (r *postgresUserRepo) FindByUsername(ctx context.Context, username string) (*domain.User, error) {
	var user domain.User
	if err := r.db.WithContext(ctx).Where("username = ?", username).First(&user).Error; err != nil {
		return nil, fmt.Errorf("userRepo.FindByUsername: %w", err)
	}
	return &user, nil
}

func (r *postgresUserRepo) Update(ctx context.Context, user *domain.User) error {
	if err := r.db.WithContext(ctx).Save(user).Error; err != nil {
		return fmt.Errorf("userRepo.Update: %w", err)
	}
	return nil
}

func (r *postgresUserRepo) UpdateStatus(ctx context.Context, userID, status string) error {
	result := r.db.WithContext(ctx).
		Model(&domain.User{}).
		Where("id = ?", userID).
		Update("status", status)
	if result.Error != nil {
		return fmt.Errorf("userRepo.UpdateStatus: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (r *postgresUserRepo) UpdateBalance(ctx context.Context, userID string, amount float64) error {
	result := r.db.WithContext(ctx).
		Model(&domain.User{}).
		Where("id = ?", userID).
		Update("balance", gorm.Expr("balance + ?", amount))
	if result.Error != nil {
		return fmt.Errorf("userRepo.UpdateBalance: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("userRepo.UpdateBalance: user not found")
	}
	return nil
}

func (r *postgresUserRepo) List(ctx context.Context, page, limit int) ([]*domain.User, int64, error) {
	var users []*domain.User
	var total int64

	offset := (page - 1) * limit

	if err := r.db.WithContext(ctx).Model(&domain.User{}).Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("userRepo.List: count: %w", err)
	}

	if err := r.db.WithContext(ctx).Offset(offset).Limit(limit).Find(&users).Error; err != nil {
		return nil, 0, fmt.Errorf("userRepo.List: find: %w", err)
	}

	return users, total, nil
}

func (r *postgresUserRepo) ListFiltered(ctx context.Context, query, status string, page, limit int) ([]*domain.User, int64, error) {
	var users []*domain.User
	var total int64

	dbQuery := r.db.WithContext(ctx).Model(&domain.User{})
	if strings.TrimSpace(query) != "" {
		like := "%" + strings.ToLower(strings.TrimSpace(query)) + "%"
		dbQuery = dbQuery.Where(
			"LOWER(id::text) LIKE ? OR LOWER(email) LIKE ? OR LOWER(username) LIKE ? OR LOWER(full_name) LIKE ?",
			like, like, like, like,
		)
	}
	if strings.TrimSpace(status) != "" {
		dbQuery = dbQuery.Where("status = ?", status)
	}

	if err := dbQuery.Count(&total).Error; err != nil {
		return nil, 0, fmt.Errorf("userRepo.ListFiltered: count: %w", err)
	}

	offset := (page - 1) * limit
	if err := dbQuery.Offset(offset).Limit(limit).Order("created_at DESC").Find(&users).Error; err != nil {
		return nil, 0, fmt.Errorf("userRepo.ListFiltered: find: %w", err)
	}

	return users, total, nil
}

func (r *postgresUserRepo) CountByStatus(ctx context.Context, status string) (int64, error) {
	var total int64
	query := r.db.WithContext(ctx).Model(&domain.User{})
	if strings.TrimSpace(status) != "" {
		query = query.Where("status = ?", status)
	}
	if err := query.Count(&total).Error; err != nil {
		return 0, fmt.Errorf("userRepo.CountByStatus: %w", err)
	}
	return total, nil
}

func (r *postgresUserRepo) CountPendingWithdrawalsByAgent(ctx context.Context, agentID string) (int, error) {
	var total int64
	if err := r.db.WithContext(ctx).
		Table("payments.withdrawal_requests").
		Where("agent_id = ? AND status = ?", agentID, "pending").
		Count(&total).Error; err != nil {
		return 0, fmt.Errorf("userRepo.CountPendingWithdrawalsByAgent: %w", err)
	}
	return int(total), nil
}

// ─── KYC / Verification ─────────────────────────────────────────────────────

func (r *postgresUserRepo) SetEmailVerified(ctx context.Context, userID string, verified bool) error {
	result := r.db.WithContext(ctx).
		Model(&domain.User{}).
		Where("id = ?", userID).
		Update("is_email_verified", verified)
	if result.Error != nil {
		return fmt.Errorf("userRepo.SetEmailVerified: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("userRepo.SetEmailVerified: user not found")
	}
	return nil
}

func (r *postgresUserRepo) SetPhoneVerified(ctx context.Context, userID string, verified bool) error {
	result := r.db.WithContext(ctx).
		Model(&domain.User{}).
		Where("id = ?", userID).
		Update("is_phone_verified", verified)
	if result.Error != nil {
		return fmt.Errorf("userRepo.SetPhoneVerified: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("userRepo.SetPhoneVerified: user not found")
	}
	return nil
}

func (r *postgresUserRepo) UpdateKYCSubmission(ctx context.Context, userID, nationalID, kycImageURL string) error {
	result := r.db.WithContext(ctx).
		Model(&domain.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"national_id":   nationalID,
			"kyc_image_url": kycImageURL,
			"kyc_status":    domain.KYCStatusPending,
		})
	if result.Error != nil {
		return fmt.Errorf("userRepo.UpdateKYCSubmission: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("userRepo.UpdateKYCSubmission: user not found")
	}
	return nil
}

func (r *postgresUserRepo) UpdateKYCStatus(ctx context.Context, userID string, status domain.KYCStatus) error {
	result := r.db.WithContext(ctx).
		Model(&domain.User{}).
		Where("id = ?", userID).
		Update("kyc_status", status)
	if result.Error != nil {
		return fmt.Errorf("userRepo.UpdateKYCStatus: %w", result.Error)
	}
	if result.RowsAffected == 0 {
		return fmt.Errorf("userRepo.UpdateKYCStatus: user not found")
	}
	return nil
}

func (r *postgresUserRepo) GetVerificationStatus(ctx context.Context, userID string) (*domain.UserVerificationStatus, error) {
	var user domain.User
	if err := r.db.WithContext(ctx).
		Select("is_email_verified, is_phone_verified, kyc_status").
		Where("id = ?", userID).
		First(&user).Error; err != nil {
		return nil, fmt.Errorf("userRepo.GetVerificationStatus: %w", err)
	}
	return &domain.UserVerificationStatus{
		IsEmailVerified: user.IsEmailVerified,
		IsPhoneVerified: user.IsPhoneVerified,
		KYCStatus:       user.KYCStatus,
	}, nil
}

// NRC Reference Data Methods

func (r *postgresUserRepo) FindNRCRegionByID(ctx context.Context, id int) (*domain.NRCRegion, error) {
	var region domain.NRCRegion
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&region).Error; err != nil {
		return nil, fmt.Errorf("userRepo.FindNRCRegionByID: %w", err)
	}
	return &region, nil
}

func (r *postgresUserRepo) FindNRCTownshipByID(ctx context.Context, id int) (*domain.NRCTownship, error) {
	var township domain.NRCTownship
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&township).Error; err != nil {
		return nil, fmt.Errorf("userRepo.FindNRCTownshipByID: %w", err)
	}
	return &township, nil
}

func (r *postgresUserRepo) FindNRCTypeByID(ctx context.Context, id int) (*domain.NRCType, error) {
	var nrcType domain.NRCType
	if err := r.db.WithContext(ctx).Where("id = ?", id).First(&nrcType).Error; err != nil {
		return nil, fmt.Errorf("userRepo.FindNRCTypeByID: %w", err)
	}
	return &nrcType, nil
}
