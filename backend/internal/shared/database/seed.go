package database

import (
	"fmt"

	userDomain "betting-app/internal/modules/user/domain"
	"betting-app/pkg/logger"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// SeedAdmin seeds the default admin and demo agent roster if they are missing.
// Existing real accounts are not deleted; only the named demo accounts are
// updated so the withdrawal selector remains deterministic in development/demo
// environments.
func SeedAdmin(db *gorm.DB) error {
	var count int64
	if err := db.Model(&userDomain.User{}).Where("role = ?", "admin").Count(&count).Error; err != nil {
		return fmt.Errorf("seed.SeedAdmin: check existing admin: %w", err)
	}

	if count > 0 {
		logger.Info("Admin user already exists, skipping seed")
	} else {
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

	if err := seedDemoAgents(db); err != nil {
		return err
	}
	return nil
}

func seedDemoAgents(db *gorm.DB) error {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte("agent123456"), 12)
	if err != nil {
		return fmt.Errorf("seed.seedDemoAgents: hash password: %w", err)
	}

	roster := []struct {
		email    string
		username string
		fullName string
		region   string
		township string
		code     string
	}{
		{"agent@example.com", "agent", "Default Agent", "Yangon Region", "Tamwe", ""},
		{"mock.agent01@example.com", "mock_agent_01", "Yangon Tamwe Agent", "Yangon Region", "Tamwe", "AGT001"},
		{"mock.agent02@example.com", "mock_agent_02", "Yangon Ahlone Agent", "Yangon Region", "Ahlone", "AGT002"},
		{"mock.agent03@example.com", "mock_agent_03", "Yangon Hlaing Agent", "Yangon Region", "Hlaing", "AGT003"},
		{"mock.agent04@example.com", "mock_agent_04", "Mandalay Chanayethazan Agent", "Mandalay Region", "Chanayethazan", "AGT004"},
		{"mock.agent05@example.com", "mock_agent_05", "Mandalay Amarapura Agent", "Mandalay Region", "Amarapura", "AGT005"},
		{"mock.agent06@example.com", "mock_agent_06", "Naypyidaw Zabuthiri Agent", "Naypyidaw Union Territory", "Zabuthiri", "AGT006"},
		{"mock.agent07@example.com", "mock_agent_07", "Taunggyi Agent", "Shan State", "Taunggyi", "AGT007"},
		{"mock.agent08@example.com", "mock_agent_08", "Mawlamyine Agent", "Mon State", "Mawlamyine", "AGT008"},
		{"mock.agent09@example.com", "mock_agent_09", "Bago Agent", "Bago Region", "Bago", "AGT009"},
		{"mock.agent10@example.com", "mock_agent_10", "Pathein Agent", "Ayeyarwady Region", "Pathein", "AGT010"},
	}

	for _, item := range roster {
		var agent userDomain.User
		findErr := db.Where("email = ?", item.email).First(&agent).Error
		if findErr == nil {
			agent.Username = item.username
			agent.FullName = item.fullName
			agent.Role = "agent"
			agent.Status = "active"
			agent.PasswordHash = string(hashedPassword)
			agent.Region = item.region
			agent.Township = item.township
			agent.Location = item.township
			if item.code == "" {
				agent.CustomCode = nil
			} else {
				code := item.code
				agent.CustomCode = &code
			}
			if err := db.Save(&agent).Error; err != nil {
				return fmt.Errorf("seed.seedDemoAgents: update %s: %w", item.email, err)
			}
			continue
		}
		if findErr != gorm.ErrRecordNotFound {
			return fmt.Errorf("seed.seedDemoAgents: find %s: %w", item.email, findErr)
		}

		customCode := (*string)(nil)
		if item.code != "" {
			customCode = &item.code
		}
		agent = userDomain.User{
			Email:        item.email,
			Username:     item.username,
			PasswordHash: string(hashedPassword),
			FullName:     item.fullName,
			Role:         "agent",
			Status:       "active",
			Balance:      0,
			Region:       item.region,
			Township:     item.township,
			Location:     item.township,
			CustomCode:   customCode,
		}
		if err := db.Create(&agent).Error; err != nil {
			return fmt.Errorf("seed.seedDemoAgents: create %s: %w", item.email, err)
		}
	}

	logger.Info("Demo agent roster seeded successfully", "count", len(roster))
	return nil
}
