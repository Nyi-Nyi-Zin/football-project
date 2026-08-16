package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"time"

	"betting-app/internal/app"
	bettingHandler "betting-app/internal/modules/betting/handler"
	bettingRepo "betting-app/internal/modules/betting/repository"
	bettingUsecase "betting-app/internal/modules/betting/usecase"
	notificationDomain "betting-app/internal/modules/notification/domain"
	notificationHandler "betting-app/internal/modules/notification/handler"
	notificationRepo "betting-app/internal/modules/notification/repository"
	notificationUsecase "betting-app/internal/modules/notification/usecase"
	oddsHandler "betting-app/internal/modules/odds/handler"
	oddsRepo "betting-app/internal/modules/odds/repository"
	oddsUsecase "betting-app/internal/modules/odds/usecase"
	paymentDomain "betting-app/internal/modules/payment/domain"
	paymentHandler "betting-app/internal/modules/payment/handler"
	paymentRepo "betting-app/internal/modules/payment/repository"
	paymentUsecase "betting-app/internal/modules/payment/usecase"
	userDomain "betting-app/internal/modules/user/domain"
	userHandler "betting-app/internal/modules/user/handler"
	userRepo "betting-app/internal/modules/user/repository"
	userUsecase "betting-app/internal/modules/user/usecase"
	"betting-app/internal/services"
	"betting-app/internal/shared/cache"
	"betting-app/internal/shared/database"
	"betting-app/internal/shared/event"
	"betting-app/pkg/config"
	jwtpkg "betting-app/pkg/jwt"
	"betting-app/pkg/logger"

	"github.com/labstack/echo/v4"
)

// migrationsDir resolves the migrations folder regardless of where the binary
// is invoked from. Priority:
//  1. MIGRATIONS_DIR env variable  (override for Docker / CI)
//  2. Path relative to this source file (works with `go run`)
//  3. Path relative to the compiled binary (works in production)
func migrationsDir() string {
	if dir := os.Getenv("MIGRATIONS_DIR"); dir != "" {
		return dir
	}

	// __file__ trick: works when using `go run`
	_, filename, _, ok := runtime.Caller(0)
	if ok {
		// filename = .../backend/cmd/server/main.go
		// migrations = .../backend/migrations
		return filepath.Join(filepath.Dir(filename), "..", "..", "migrations")
	}

	// Fallback: relative to compiled binary location
	exe, err := os.Executable()
	if err == nil {
		return filepath.Join(filepath.Dir(exe), "migrations")
	}

	// Last resort default
	return "migrations"
}

func main() {
	cfg, err := config.Load()
	if err != nil {
		panic("Failed to load config: " + err.Error())
	}

	logger.Init(cfg.App.Env)
	defer logger.Sync()

	logger.Info("Starting betting app server",
		"env", cfg.App.Env,
		"port", cfg.Server.Port,
	)

	db, err := database.Connect(cfg.Database.URL, cfg.App.Env)
	if err != nil {
		logger.Fatal("Failed to connect to database", "error", err)
	}
	defer database.Close(db)

	if err := database.RunMigrations(cfg.Database.URL, migrationsDir()); err != nil {
		logger.Fatal("Failed to run migrations", "error", err)
	}

	if err := database.SeedAdmin(db); err != nil {
		logger.Fatal("Failed to seed admin user", "error", err)
	}

	redisClient, err := cache.Connect(cfg.Redis.URL)
	if err != nil {
		logger.Error("Failed to connect to Redis, dropping cache", "error", err)
		redisClient = &cache.RedisClient{Client: nil}
	} else {
		defer redisClient.Close()
	}

	jwtExpiry, _ := time.ParseDuration(cfg.JWT.Expiry)
	refreshExpiry, _ := time.ParseDuration(cfg.JWT.RefreshExpiry)
	jwtManager := jwtpkg.NewManager(cfg.JWT.Secret, jwtExpiry, refreshExpiry)

	eventBus := event.NewBus()

	userRepository := userRepo.NewPostgresUserRepo(db)
	userUC := userUsecase.NewUserUseCase(userRepository, jwtManager, eventBus)
	userH := userHandler.NewUserHandler(userUC)

	txRepository := paymentRepo.NewPostgresTransactionRepo(db)
	walletRepository := paymentRepo.NewPostgresWalletRepo(db)
	paymentUC := paymentUsecase.NewPaymentUseCase(
		txRepository,
		walletRepository,
		eventBus,
		paymentUsecase.SecurityOptions{
			CodePepper:    cfg.Security.WithdrawalCodePepper,
			EncryptionKey: cfg.Security.WithdrawalDataKey,
		},
		nil,
	)
	paymentH := paymentHandler.NewPaymentHandler(paymentUC)

	userProviderAdapter := &UserProviderAdapter{
		userRepo:   userRepository,
		walletRepo: walletRepository,
	}

	oddsRepository := oddsRepo.NewPostgresOddsRepo(db)
	oddsUC := oddsUsecase.NewOddsUseCase(oddsRepository, eventBus)
	oddsH := oddsHandler.NewOddsHandler(oddsUC)

	betRepository := bettingRepo.NewPostgresBetRepo(db)
	matchRepository := bettingRepo.NewPostgresMatchRepo(db)
	settlementService := services.NewAtomicSettlementService(db)
	settlementService.Start(context.Background(), 30*time.Second)
	bettingUC := bettingUsecase.NewBettingUseCase(
		betRepository,
		matchRepository,
		oddsRepository,
		userProviderAdapter,
		eventBus,
		settlementService,
	)
	bettingH := bettingHandler.NewBettingHandler(bettingUC)

	openLigaInterval, parseErr := time.ParseDuration(cfg.OpenLigaDB.SyncInterval)
	if parseErr != nil {
		logger.Warn("Invalid OPENLIGADB_SYNC_INTERVAL, using default", "value", cfg.OpenLigaDB.SyncInterval, "error", parseErr)
		openLigaInterval = 6 * time.Hour
	}
	openLigaSync := services.NewOpenLigaDBSyncService(
		cfg.OpenLigaDB.Leagues,
		cfg.OpenLigaDB.Season,
		openLigaInterval,
		matchRepository,
	)
	openLigaSync.StartSync(context.Background())
	logger.Info("OpenLigaDB football fixture sync enabled", "leagues", cfg.OpenLigaDB.Leagues, "season", cfg.OpenLigaDB.Season, "interval", openLigaInterval.String())

	if cfg.TheOddsAPI.Key != "" {

		syncInterval, parseErr := time.ParseDuration(cfg.TheOddsAPI.SyncInterval)
		if parseErr != nil {
			logger.Warn("Invalid THE_ODDS_SYNC_INTERVAL, using default", "value", cfg.TheOddsAPI.SyncInterval, "error", parseErr)
			syncInterval = 30 * time.Minute
		}
		syncService := services.NewTheOddsSyncService(cfg.TheOddsAPI.Key, syncInterval, matchRepository, oddsRepository)
		syncService.StartSync(context.Background())
		logger.Info("The Odds API sync enabled", "interval", syncInterval.String())
	} else {
		logger.Info("The Odds API key is empty, skipping external odds sync")
	}

	notifRepository := notificationRepo.NewPostgresNotificationRepo(db)
	notifUC := notificationUsecase.NewNotificationUseCase(notifRepository, eventBus)
	notifH := notificationHandler.NewNotificationHandler(notifUC)

	registerEventHandlers(eventBus, notifUC)

	e := echo.New()
	e.HideBanner = true

	app.RegisterRoutes(e, jwtManager, redisClient, userH, bettingH, paymentH, oddsH, notifH)

	go func() {
		addr := fmt.Sprintf(":%s", cfg.Server.Port)
		logger.Info("Server starting", "address", addr)
		if err := e.Start(addr); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Server failed to start", "error", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := e.Shutdown(ctx); err != nil {
		logger.Fatal("Server forced to shutdown", "error", err)
	}

	logger.Info("Server exited gracefully")
}

type UserProviderAdapter struct {
	userRepo   userDomain.UserRepository
	walletRepo paymentDomain.WalletRepository
}

func (a *UserProviderAdapter) GetUserBalance(ctx context.Context, userID string) (float64, error) {
	return a.walletRepo.GetBalance(ctx, userID)
}

func (a *UserProviderAdapter) DeductBalance(ctx context.Context, userID string, amount float64) error {
	return a.walletRepo.UpdateBalance(ctx, userID, -amount)
}

func (a *UserProviderAdapter) AddBalance(ctx context.Context, userID string, amount float64) error {
	return a.walletRepo.UpdateBalance(ctx, userID, amount)
}

func registerEventHandlers(bus *event.Bus, notifUC *notificationUsecase.NotificationUseCase) {
	bus.Subscribe(event.UserRegistered, func(ctx context.Context, evt event.Event) error {
		payload := evt.Payload.(map[string]string)
		_, err := notifUC.Send(ctx, &notificationDomain.SendNotificationRequest{
			UserID:  payload["user_id"],
			Type:    notificationDomain.NotificationTypeSystem,
			Title:   "Welcome!",
			Message: "Welcome to our platform! Start betting now.",
		})
		return err
	})

	bus.Subscribe(event.BetPlaced, func(ctx context.Context, evt event.Event) error {
		payload := evt.Payload.(map[string]interface{})
		_, err := notifUC.Send(ctx, &notificationDomain.SendNotificationRequest{
			UserID:  payload["user_id"].(string),
			Type:    notificationDomain.NotificationTypeBetResult,
			Title:   "Bet Placed",
			Message: fmt.Sprintf("Your bet of $%.2f has been placed successfully.", payload["stake"].(float64)),
		})
		return err
	})

	bus.Subscribe(event.PaymentDeposit, func(ctx context.Context, evt event.Event) error {
		payload := evt.Payload.(map[string]interface{})
		_, err := notifUC.Send(ctx, &notificationDomain.SendNotificationRequest{
			UserID:  payload["user_id"].(string),
			Type:    notificationDomain.NotificationTypeDeposit,
			Title:   "Deposit Successful",
			Message: fmt.Sprintf("$%.2f has been added to your wallet.", payload["amount"].(float64)),
		})
		return err
	})
}
