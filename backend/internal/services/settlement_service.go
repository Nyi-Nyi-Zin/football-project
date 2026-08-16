package services

import (
	"context"
	"fmt"
	"time"

	bettingDomain "betting-app/internal/modules/betting/domain"
	paymentDomain "betting-app/internal/modules/payment/domain"
	"betting-app/pkg/logger"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// AtomicSettlementService applies single bets and accumulator slips together
// with their wallet ledger entries inside one database transaction.
type AtomicSettlementService struct {
	db *gorm.DB
}

func NewAtomicSettlementService(db *gorm.DB) *AtomicSettlementService {
	return &AtomicSettlementService{db: db}
}

func (s *AtomicSettlementService) SettleBet(ctx context.Context, betID string) (*bettingDomain.SettlementDecision, error) {
	var decision *bettingDomain.SettlementDecision

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var bet bettingDomain.Bet
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Preload("Match").Where("id = ?", betID).First(&bet).Error; err != nil {
			return fmt.Errorf("settlement: find bet: %w", err)
		}

		if bet.Status != bettingDomain.BetStatusPending && bet.Status != bettingDomain.BetStatusActive {
			decision = &bettingDomain.SettlementDecision{
				Status:    bet.Status,
				Reason:    "Bet has already been settled or cancelled",
				IsSettled: true,
			}
			return nil
		}

		currentDecision, err := bettingDomain.EvaluateBetSettlement(bet.Match, &bet)
		if err != nil {
			return fmt.Errorf("settlement: evaluate bet: %w", err)
		}
		decision = &currentDecision
		if !currentDecision.IsSettled {
			return nil
		}

		if currentDecision.Payout > 0 {
			txType := paymentDomain.TransactionBetWin
			if currentDecision.Status == bettingDomain.BetStatusCancelled {
				txType = paymentDomain.TransactionRefund
			}
			if err := applyWalletCredit(tx, bet.UserID, currentDecision.Payout, txType,
				fmt.Sprintf("settlement:bet:%s", bet.ID), bet.ID, currentDecision.Reason); err != nil {
				return err
			}
		}
		return markBetSettled(tx, bet.ID, currentDecision.Status)
	})
	if err != nil {
		return nil, err
	}
	return decision, nil
}

// SettleBetSlip settles an accumulator once a losing leg is known or all legs
// have finished. If a leg is voided, this conservative implementation refunds
// the full stake after all legs are resolved rather than recalculating odds.
func (s *AtomicSettlementService) SettleBetSlip(ctx context.Context, slipID string) (*bettingDomain.SettlementDecision, error) {
	var decision *bettingDomain.SettlementDecision

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var slip bettingDomain.BetSlip
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Preload("Legs.Match").Where("id = ?", slipID).First(&slip).Error; err != nil {
			return fmt.Errorf("settlement: find slip: %w", err)
		}

		if slip.Status != bettingDomain.BetStatusPending && slip.Status != bettingDomain.BetStatusActive {
			decision = &bettingDomain.SettlementDecision{
				Status:    slip.Status,
				Reason:    "Bet slip has already been settled or cancelled",
				IsSettled: true,
			}
			return nil
		}
		if len(slip.Legs) == 0 {
			return fmt.Errorf("settlement: bet slip has no legs")
		}

		allResolved := true
		hasLoss := false
		hasVoid := false
		for _, leg := range slip.Legs {
			legDecision, err := bettingDomain.EvaluateBetSettlement(leg.Match, &bettingDomain.Bet{
				MarketKey: leg.MarketKey,
				Selection: leg.SelectionKey,
			})
			if err != nil {
				return fmt.Errorf("settlement: evaluate slip leg: %w", err)
			}
			if !legDecision.IsSettled {
				allResolved = false
			}
			if legDecision.Status == bettingDomain.BetStatusLost {
				hasLoss = true
			}
			if legDecision.Status == bettingDomain.BetStatusCancelled {
				hasVoid = true
			}
		}

		if !hasLoss && !allResolved {
			decision = &bettingDomain.SettlementDecision{
				Status:    slip.Status,
				Reason:    "Accumulator has unresolved legs",
				IsSettled: false,
			}
			return nil
		}

		status := bettingDomain.BetStatusWon
		payout := slip.PotentialPayout
		reason := "All accumulator legs won"
		if hasLoss {
			status = bettingDomain.BetStatusLost
			payout = 0
			reason = "Accumulator lost because one or more legs lost"
		} else if hasVoid {
			status = bettingDomain.BetStatusCancelled
			payout = slip.Stake
			reason = "Accumulator refunded because one or more legs were voided"
		}

		decision = &bettingDomain.SettlementDecision{
			Status:    status,
			Payout:    payout,
			Reason:    reason,
			IsSettled: true,
		}
		if payout > 0 {
			txType := paymentDomain.TransactionBetWin
			if status == bettingDomain.BetStatusCancelled {
				txType = paymentDomain.TransactionRefund
			}
			if err := applyWalletCredit(tx, slip.UserID, payout, txType,
				fmt.Sprintf("settlement:slip:%s", slip.ID), slip.ID, reason); err != nil {
				return err
			}
		}
		return markSlipSettled(tx, slip.ID, status)
	})
	if err != nil {
		return nil, err
	}
	return decision, nil
}

// RunOnce settles every single bet linked to a finished/cancelled match and
// attempts all pending accumulator slips. It is safe to call repeatedly because
// row locks and pending/active status guards make settlement idempotent.
func (s *AtomicSettlementService) RunOnce(ctx context.Context) (int, error) {
	settled := 0
	var betIDs []string
	if err := s.db.WithContext(ctx).
		Table("betting.bets AS b").
		Joins("JOIN betting.matches AS m ON m.id = b.match_id").
		Where("b.status IN ? AND m.status IN ?", []bettingDomain.BetStatus{
			bettingDomain.BetStatusPending,
			bettingDomain.BetStatusActive,
		}, []bettingDomain.MatchStatus{
			bettingDomain.MatchStatusFinished,
			bettingDomain.MatchStatusCancelled,
		}).
		Pluck("b.id", &betIDs).Error; err != nil {
		return 0, fmt.Errorf("settlement worker: find bets: %w", err)
	}
	for _, betID := range betIDs {
		decision, err := s.SettleBet(ctx, betID)
		if err != nil {
			return settled, err
		}
		if decision != nil && decision.IsSettled {
			settled++
		}
	}

	var slipIDs []string
	if err := s.db.WithContext(ctx).
		Table("betting.bet_slips").
		Where("status IN ?", []bettingDomain.BetStatus{
			bettingDomain.BetStatusPending,
			bettingDomain.BetStatusActive,
		}).
		Pluck("id", &slipIDs).Error; err != nil {
		return settled, fmt.Errorf("settlement worker: find slips: %w", err)
	}
	for _, slipID := range slipIDs {
		decision, err := s.SettleBetSlip(ctx, slipID)
		if err != nil {
			return settled, err
		}
		if decision != nil && decision.IsSettled {
			settled++
		}
	}
	return settled, nil
}

func (s *AtomicSettlementService) Start(ctx context.Context, interval time.Duration) {
	if interval <= 0 {
		interval = 30 * time.Second
	}
	go func() {
		s.runWorkerCycle(ctx)
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				s.runWorkerCycle(ctx)
			}
		}
	}()
}

func (s *AtomicSettlementService) runWorkerCycle(ctx context.Context) {
	settled, err := s.RunOnce(ctx)
	if err != nil {
		logger.Error("Settlement worker cycle failed", "error", err)
		return
	}
	if settled > 0 {
		logger.Info("Settlement worker cycle completed", "settled_count", settled)
	}
}

func applyWalletCredit(
	tx *gorm.DB,
	userID string,
	amount float64,
	txType paymentDomain.TransactionType,
	idempotencyKey string,
	reference string,
	description string,
) error {
	var wallet paymentDomain.Wallet
	if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
		Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		return fmt.Errorf("settlement: lock wallet: %w", err)
	}
	balanceBefore := wallet.Balance
	balanceAfter := balanceBefore + amount
	if err := tx.Model(&paymentDomain.Wallet{}).
		Where("user_id = ?", userID).
		Update("balance", gorm.Expr("balance + ?", amount)).Error; err != nil {
		return fmt.Errorf("settlement: credit wallet: %w", err)
	}
	ledger := &paymentDomain.Transaction{
		UserID:         userID,
		Type:           txType,
		Amount:         amount,
		Currency:       wallet.Currency,
		Status:         paymentDomain.TransactionCompleted,
		IdempotencyKey: idempotencyKey,
		Reference:      reference,
		Description:    description,
		BalanceBefore:  balanceBefore,
		BalanceAfter:   balanceAfter,
	}
	if err := tx.Create(ledger).Error; err != nil {
		return fmt.Errorf("settlement: create ledger entry: %w", err)
	}
	return nil
}

func markBetSettled(tx *gorm.DB, betID string, status bettingDomain.BetStatus) error {
	result := tx.Model(&bettingDomain.Bet{}).
		Where("id = ? AND status IN ?", betID, []bettingDomain.BetStatus{
			bettingDomain.BetStatusPending,
			bettingDomain.BetStatusActive,
		}).
		Updates(map[string]interface{}{"status": status, "settled_at": time.Now().UTC()})
	if result.Error != nil {
		return fmt.Errorf("settlement: update bet: %w", result.Error)
	}
	if result.RowsAffected != 1 {
		return fmt.Errorf("settlement: bet was changed concurrently")
	}
	return nil
}

func markSlipSettled(tx *gorm.DB, slipID string, status bettingDomain.BetStatus) error {
	result := tx.Model(&bettingDomain.BetSlip{}).
		Where("id = ? AND status IN ?", slipID, []bettingDomain.BetStatus{
			bettingDomain.BetStatusPending,
			bettingDomain.BetStatusActive,
		}).
		Updates(map[string]interface{}{"status": status, "settled_at": time.Now().UTC()})
	if result.Error != nil {
		return fmt.Errorf("settlement: update bet slip: %w", result.Error)
	}
	if result.RowsAffected != 1 {
		return fmt.Errorf("settlement: bet slip was changed concurrently")
	}
	return nil
}
