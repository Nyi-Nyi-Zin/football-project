package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"betting-app/internal/app"
	bettingDomain "betting-app/internal/modules/betting/domain"
	bettingHandler "betting-app/internal/modules/betting/handler"
	bettingRepo "betting-app/internal/modules/betting/repository"
	bettingUsecase "betting-app/internal/modules/betting/usecase"
	notificationDomain "betting-app/internal/modules/notification/domain"
	notificationHandler "betting-app/internal/modules/notification/handler"
	notificationRepo "betting-app/internal/modules/notification/repository"
	notificationUsecase "betting-app/internal/modules/notification/usecase"
	oddsDomain "betting-app/internal/modules/odds/domain"
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

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		panic("Failed to load config: " + err.Error())
	}

	// Initialize logger
	logger.Init(cfg.App.Env)
	defer logger.Sync()

	logger.Info("Starting betting app server",
		"env", cfg.App.Env,
		"port", cfg.Server.Port,
	)

	// Connect to PostgreSQL
	db, err := database.Connect(cfg.Database.URL, cfg.App.Env)
	if err != nil {
		logger.Fatal("Failed to connect to database", "error", err)
	}
	defer database.Close(db)

	// Create schemas
	if err := database.CreateSchemas(db); err != nil {
		logger.Fatal("Failed to create schemas", "error", err)
	}

	// Auto-migrate tables
	if err := db.AutoMigrate(
		&userDomain.User{},
		&bettingDomain.Match{},
		&bettingDomain.Bet{},
		&bettingDomain.BetSlip{},
		&bettingDomain.BetLeg{},
		&paymentDomain.Transaction{},
		&paymentDomain.Wallet{},
		&paymentDomain.WithdrawalRequest{},
		&paymentDomain.WithdrawalAuditLog{},
		&oddsDomain.Odds{},
		&oddsDomain.OddsHistory{},
		&notificationDomain.Notification{},
	); err != nil {
		logger.Fatal("Failed to auto-migrate", "error", err)
	}
	logger.Info("Database migration completed")

	// Seed admin user
	if err := database.SeedAdmin(db); err != nil {
		logger.Fatal("Failed to seed admin user", "error", err)
	}

	// Connect to Redis
	redisClient, err := cache.Connect(cfg.Redis.URL)
	if err != nil {
		logger.Error("Failed to connect to Redis, dropping cache", "error", err)
		redisClient = &cache.RedisClient{Client: nil}
	} else {
		defer redisClient.Close()
	}

	// Initialize JWT manager
	jwtExpiry, _ := time.ParseDuration(cfg.JWT.Expiry)
	refreshExpiry, _ := time.ParseDuration(cfg.JWT.RefreshExpiry)
	jwtManager := jwtpkg.NewManager(cfg.JWT.Secret, jwtExpiry, refreshExpiry)

	// Initialize event bus
	eventBus := event.NewBus()

	// --- Wire up modules ---

	// User module
	userRepository := userRepo.NewPostgresUserRepo(db)
	userUC := userUsecase.NewUserUseCase(userRepository, jwtManager, eventBus)
	userH := userHandler.NewUserHandler(userUC)

	// Payment module
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
	)
	paymentH := paymentHandler.NewPaymentHandler(paymentUC)

	// User provider adapter for betting module (cross-module communication via interface)
	userProviderAdapter := &UserProviderAdapter{
		userRepo:   userRepository,
		walletRepo: walletRepository,
	}

	// Odds module
	oddsRepository := oddsRepo.NewPostgresOddsRepo(db)
	oddsUC := oddsUsecase.NewOddsUseCase(oddsRepository, eventBus)
	oddsH := oddsHandler.NewOddsHandler(oddsUC)

	// Betting module
	betRepository := bettingRepo.NewPostgresBetRepo(db)
	matchRepository := bettingRepo.NewPostgresMatchRepo(db)
	bettingUC := bettingUsecase.NewBettingUseCase(betRepository, matchRepository, oddsRepository, userProviderAdapter, eventBus)
	bettingH := bettingHandler.NewBettingHandler(bettingUC)

	// External odds data sync
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

	// Notification module
	notifRepository := notificationRepo.NewPostgresNotificationRepo(db)
	notifUC := notificationUsecase.NewNotificationUseCase(notifRepository, eventBus)
	notifH := notificationHandler.NewNotificationHandler(notifUC)

	// Register event handlers
	registerEventHandlers(eventBus, notifUC)

	// Create Echo instance and register routes
	e := echo.New()
	e.HideBanner = true

	app.RegisterRoutes(e, jwtManager, redisClient, userH, bettingH, paymentH, oddsH, notifH)

	// Graceful shutdown
	go func() {
		addr := fmt.Sprintf(":%s", cfg.Server.Port)
		logger.Info("Server starting", "address", addr)
		if err := e.Start(addr); err != nil && err != http.ErrServerClosed {
			logger.Fatal("Server failed to start", "error", err)
		}
	}()

	// Wait for interrupt signal
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

// UserProviderAdapter adapts user/payment repos to the BettingModule's UserProvider interface
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

// registerEventHandlers wires up cross-module event handlers
func registerEventHandlers(bus *event.Bus, notifUC *notificationUsecase.NotificationUseCase) {
	// When a user registers, send a welcome notification
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

	// When a bet is placed, notify the user
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

	// When a deposit is made, notify the user
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
