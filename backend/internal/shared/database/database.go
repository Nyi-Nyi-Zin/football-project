package database

import (
	"database/sql"
	"fmt"

	"betting-app/pkg/logger"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"
)

var DB *gorm.DB

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

	sqlDB.SetMaxOpenConns(25)
	sqlDB.SetMaxIdleConns(10)

	DB = db
	logger.Info("Database connected successfully")
	return db, nil
}

// RunMigrations runs goose migrations from the given directory.
func RunMigrations(databaseURL, migrationsDir string) error {
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return fmt.Errorf("database.RunMigrations: open: %w", err)
	}
	defer db.Close()

	goose.SetBaseFS(nil)

	if err := goose.SetDialect("postgres"); err != nil {
		return fmt.Errorf("database.RunMigrations: set dialect: %w", err)
	}

	if err := goose.Up(db, migrationsDir); err != nil {
		return fmt.Errorf("database.RunMigrations: up: %w", err)
	}

	logger.Info("Database migrations completed successfully")
	return nil
}

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