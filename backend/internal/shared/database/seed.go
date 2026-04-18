package database

import (
	"fmt"

	userDomain "betting-app/internal/modules/user/domain"
	"betting-app/pkg/logger"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// SeedAdmin seeds a default admin user if none exists
func SeedAdmin(db *gorm.DB) error {
	var count int64
	if err := db.Model(&userDomain.User{}).Where("role = ?", "admin").Count(&count).Error; err != nil {
		return fmt.Errorf("seed.SeedAdmin: check existing admin: %w", err)
	}

	if count > 0 {
		logger.Info("Admin user already exists, skipping seed")
	} else {
		// Create default admin
		hashedPassword, err := bcrypt.GenerateFromPassword([]byte("admin123456"), 12)
		if err != nil {
			return fmt.Errorf("seed.SeedAdmin: hash password: %w", err)
		}

		admin := &userDomain.User{
			Email:        "admin@example.com",
			Username:     "admin",
			PasswordHash: string(hashedPassword),
			FullName:     "System Admin",
			Role:         "admin",
			Status:       "active",
			Balance:      0,
		}

		if err := db.Create(admin).Error; err != nil {
			return fmt.Errorf("seed.SeedAdmin: create admin: %w", err)
		}

		logger.Info("Default admin user seeded successfully", "email", admin.Email)
	}

	agentPassword, err := bcrypt.GenerateFromPassword([]byte("agent123456"), 12)
	if err != nil {
		return fmt.Errorf("seed.SeedAdmin: hash agent password: %w", err)
	}
	var agent userDomain.User
	err = db.Where("email = ?", "agent@example.com").First(&agent).Error
	if err == nil {
		agent.Username = "agent"
		agent.FullName = "Default Agent"
		agent.Role = "agent"
		agent.Status = "active"
		agent.PasswordHash = string(agentPassword)
		if saveErr := db.Save(&agent).Error; saveErr != nil {
			return fmt.Errorf("seed.SeedAdmin: update agent: %w", saveErr)
		}
		logger.Info("Default agent user updated successfully", "email", agent.Email)
		return nil
	}
	agent = userDomain.User{
		Email:        "agent@example.com",
		Username:     "agent",
		PasswordHash: string(agentPassword),
		FullName:     "Default Agent",
		Role:         "agent",
		Status:       "active",
		Balance:      0,
	}
	if err := db.Create(&agent).Error; err != nil {
		return fmt.Errorf("seed.SeedAdmin: create agent: %w", err)
	}
	logger.Info("Default agent user seeded successfully", "email", agent.Email)
	return nil
}
