package database

import (
	"fmt"

	"betting-app/pkg/logger"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"
)

// DB holds the database connection
var DB *gorm.DB

// Connect initializes the database connection pool
func Connect(databaseURL string, env string) (*gorm.DB, error) {
	var logLevel gormlogger.LogLevel
	if env == "production" {
		logLevel = gormlogger.Silent
	} else {
		logLevel = gormlogger.Info
	}

	db, err := gorm.Open(postgres.Open(databaseURL), &gorm.Config{
		Logger: gormlogger.Default.LogMode(logLevel),
	})
	if err != nil {
		return nil, fmt.Errorf("database.Connect: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("database.Connect: get sql.DB: %w", err)
	}

	// Connection pool settings
	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(10)

	DB = db
	logger.Info("Database connected successfully")
	return db, nil
}

// CreateSchemas creates the schema-per-module if they don't exist
func CreateSchemas(db *gorm.DB) error {
	schemas := []string{"users", "betting", "payments", "odds", "notifications"}
	for _, schema := range schemas {
		sql := fmt.Sprintf("CREATE SCHEMA IF NOT EXISTS %s", schema)
		if err := db.Exec(sql).Error; err != nil {
			return fmt.Errorf("database.CreateSchemas: %s: %w", schema, err)
		}
	}
	logger.Info("All database schemas created/verified")
	return nil
}

// Close closes the database connection
func Close(db *gorm.DB) {
	sqlDB, err := db.DB()
	if err != nil {
		logger.Error("database.Close: get sql.DB failed", "error", err)
		return
	}
	if err := sqlDB.Close(); err != nil {
		logger.Error("database.Close: close failed", "error", err)
	}
}
