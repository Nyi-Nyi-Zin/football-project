package main

import (
	"context"
	"fmt"
	"sync"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"gorm.io/gorm/schema"

	bettingDomain "betting-app/internal/modules/betting/domain"
	notificationDomain "betting-app/internal/modules/notification/domain"
	oddsDomain "betting-app/internal/modules/odds/domain"
	paymentDomain "betting-app/internal/modules/payment/domain"
	userDomain "betting-app/internal/modules/user/domain"
)

type sqlCaptureLogger struct {
	logger.Interface
	mu       sync.Mutex
	captured []string
}

func (l *sqlCaptureLogger) Trace(
	ctx context.Context,
	begin time.Time,
	fc func() (sql string, rowsAffected int64),
	err error,
) {
	sql, _ := fc()
	if sql != "" {
		l.mu.Lock()
		l.captured = append(l.captured, sql)
		l.mu.Unlock()
	}
}

func (l *sqlCaptureLogger) Drain() []string {
	l.mu.Lock()
	defer l.mu.Unlock()
	result := make([]string, len(l.captured))
	copy(result, l.captured)
	l.captured = l.captured[:0]
	return result
}

func main() {
	// ── Step 1: Real DB connection (diff ရှာဖို့) ──────────────────
	realDB, err := gorm.Open(postgres.Open(
		"host=localhost user=postgres dbname=bet password=12345 sslmode=disable",
	), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
		NamingStrategy: schema.NamingStrategy{
			SingularTable: false,
		},
	})
	if err != nil {
		panic(fmt.Sprintf("DB connect failed: %v", err))
	}

	// ── Step 2: DryRun DB (SQL generate ဖို့) ─────────────────────
	capLogger := &sqlCaptureLogger{
		Interface: logger.Default.LogMode(logger.Silent),
	}
	dryDB, _ := gorm.Open(postgres.New(postgres.Config{
		PreferSimpleProtocol: true,
		DSN:                  "host=localhost user=postgres dbname=bet password=12345 sslmode=disable",
	}), &gorm.Config{
		DryRun: true,
		Logger: capLogger,
		NamingStrategy: schema.NamingStrategy{
			SingularTable: false,
		},
	})

	entities := []interface{}{
		&userDomain.User{},
		&bettingDomain.Match{},
		&bettingDomain.Bet{},
		&notificationDomain.Notification{},
		&oddsDomain.Odds{},
		&paymentDomain.Transaction{},
		&paymentDomain.Wallet{},
		&paymentDomain.WithdrawalRequest{},
		&paymentDomain.WithdrawalAuditLog{},
	}

	upStatements := []string{}
	downStatements := []string{}

	realMigrator := realDB.Migrator()
	dryMigrator := dryDB.Migrator()

	for _, entity := range entities {
		// Table မရှိသေးရင် → CREATE TABLE အပြည့်
	if !realMigrator.HasTable(entity) {
    dryMigrator.CreateTable(entity)
    stmts := capLogger.Drain()
    upStatements = append(upStatements, stmts...)

    stmt := &gorm.Statement{DB: realDB}
    stmt.Parse(entity)
    downStatements = append(downStatements,
        fmt.Sprintf("DROP TABLE IF EXISTS %s CASCADE;", stmt.Schema.Table),
    )
    continue
}

		// Table ရှိပြီးသား → Column တစ်ခုချင်း diff စစ်တယ်
		stmt := &gorm.Statement{DB: realDB}
		stmt.Parse(entity)

		for _, field := range stmt.Schema.Fields {
			if field.DBName == "" {
				continue
			}
			if !realMigrator.HasColumn(entity, field.DBName) {
				// Column မရှိသေးဘူး → ALTER TABLE ADD COLUMN
				dryMigrator.AddColumn(entity, field.DBName)
				stmts := capLogger.Drain()
				upStatements = append(upStatements, stmts...)
				downStatements = append(downStatements,
					fmt.Sprintf(
						"ALTER TABLE %s DROP COLUMN IF EXISTS %s;",
						stmt.Schema.Table,
						field.DBName,
					),
				)
			}
		}
	}

	// ── Output ────────────────────────────────────────────────────
	if len(upStatements) == 0 {
		fmt.Println("-- No schema changes detected.")
		return
	}

	fmt.Println("-- +goose Up")
	for _, s := range upStatements {
		fmt.Printf("%s;\n", s)
	}

	fmt.Println("\n-- +goose Down")
	// Down က reverse order
	for i := len(downStatements) - 1; i >= 0; i-- {
		fmt.Println(downStatements[i])
	}
}