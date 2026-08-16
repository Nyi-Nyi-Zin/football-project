package services

import (
	"context"
	"fmt"
	"math"
	"time"

	bettingDomain "betting-app/internal/modules/betting/domain"
	oddsDomain "betting-app/internal/modules/odds/domain"
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

// ExecuteCashOut revalidates a short-lived quote and atomically credits the
// quoted amount, writes a cash-out ledger entry, and closes the active bet.
func (s *AtomicSettlementService) ExecuteCashOut(ctx context.Context, userID, betID string, quote *bettingDomain.CashOutQuote) (*bettingDomain.CashOutQuote, error) {
	if quote == nil || quote.BetID != betID || quote.QuotedAmount <= 0 {
		return nil, fmt.Errorf("cash-out: invalid quote")
	}
	if quote.ExpiresAt.Before(time.Now().UTC()) {
		return nil, bettingDomain.ErrCashOutQuoteExpired
	}

	result := *quote
	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var bet bettingDomain.Bet
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ?", betID).First(&bet).Error; err != nil {
			return fmt.Errorf("cash-out: find bet: %w", err)
		}
		if bet.UserID != userID {
			return fmt.Errorf("cash-out: user does not own bet")
		}
		if bet.BetType != bettingDomain.BetTypeSingle || bet.Status != bettingDomain.BetStatusActive {
			return fmt.Errorf("cash-out: bet is not active")
		}

		var match bettingDomain.Match
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ?", bet.MatchID).First(&match).Error; err != nil {
			return fmt.Errorf("cash-out: find match: %w", err)
		}
		if match.Status != bettingDomain.MatchStatusLive {
			return fmt.Errorf("cash-out: match is not live")
		}

		var odds oddsDomain.Odds
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("match_id = ? AND is_active = ?", bet.MatchID, true).
			Order("updated_at DESC").First(&odds).Error; err != nil {
			return fmt.Errorf("cash-out: current odds unavailable: %w", err)
		}
		currentOdds, ok := cashOutSelectionOdds(&odds, bet.MarketKey, bet.Selection)
		if !ok || currentOdds <= 1 || bet.Odds <= 1 {
			return fmt.Errorf("cash-out: current odds unavailable")
		}

		amount := bet.Stake * (currentOdds / bet.Odds) * 0.95
		amount = math.Max(0, math.Min(amount, bet.PotentialPayout))
		amount = roundCashOutAmount(amount)
		if amount <= 0 || math.Abs(currentOdds-quote.CurrentOdds) > 0.01 ||
			math.Abs(amount-quote.QuotedAmount) > 0.01 || math.Abs(bet.Odds-quote.OriginalOdds) > 0.01 {
			return bettingDomain.ErrCashOutQuoteChanged
		}

		if err := applyWalletCredit(tx, bet.UserID, amount, paymentDomain.TransactionCashOut,
			fmt.Sprintf("cashout:bet:%s", bet.ID), bet.ID, "Cash-out payout"); err != nil {
			return err
		}
		if err := markBetSettled(tx, bet.ID, bettingDomain.BetStatusSettled); err != nil {
			return err
		}

		result.QuotedAmount = amount
		result.CurrentOdds = currentOdds
		result.Status = "executed"
		return nil
	})
	if err != nil {
		return nil, err
	}
	return &result, nil
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

func cashOutSelectionOdds(odds *oddsDomain.Odds, marketKey, selectionKey string) (float64, bool) {
	if odds == nil || odds.HomeOdds <= 1 || odds.AwayOdds <= 1 {
		return 0, false
	}

	homeProb := 1 / odds.HomeOdds
	awayProb := 1 / odds.AwayOdds
	drawProb := 0.0
	if odds.DrawOdds > 1 {
		drawProb = 1 / odds.DrawOdds
	}
	totalProb := homeProb + awayProb + drawProb
	if totalProb <= 0 {
		return 0, false
	}
	homeProb /= totalProb
	awayProb /= totalProb
	drawProb /= totalProb

	bttsYesProb := clampCashOutProbability(0.42 + math.Abs(homeProb-awayProb)*0.12 + drawProb*0.28)
	bttsNoProb := clampCashOutProbability(1 - bttsYesProb)
	over25Prob := clampCashOutProbability(0.45 + (1-drawProb)*0.20)
	under25Prob := clampCashOutProbability(1 - over25Prob)

	var value float64
	switch marketKey {
	case "match_result":
		switch selectionKey {
		case "w1":
			value = 1 / homeProb
		case "x":
			value = 1 / drawProb
		case "w2":
			value = 1 / awayProb
		default:
			return 0, false
		}
	case "double_chance":
		switch selectionKey {
		case "1x":
			value = 1 / clampCashOutProbability(homeProb+drawProb)
		case "12":
			value = 1 / clampCashOutProbability(homeProb+awayProb)
		case "x2":
			value = 1 / clampCashOutProbability(drawProb+awayProb)
		default:
			return 0, false
		}
	case "draw_no_bet":
		switch selectionKey {
		case "home_dnb":
			value = (homeProb + awayProb) / clampCashOutProbability(homeProb)
		case "away_dnb":
			value = (homeProb + awayProb) / clampCashOutProbability(awayProb)
		default:
			return 0, false
		}
	case "btts":
		switch selectionKey {
		case "btts_yes":
			value = 1 / bttsYesProb
		case "btts_no":
			value = 1 / bttsNoProb
		default:
			return 0, false
		}
	case "total_goals_2_5":
		switch selectionKey {
		case "over_2_5":
			value = 1 / over25Prob
		case "under_2_5":
			value = 1 / under25Prob
		default:
			return 0, false
		}
	default:
		return 0, false
	}
	return roundCashOutOdds(value), true
}

func clampCashOutProbability(value float64) float64 {
	return math.Max(0.08, math.Min(0.92, value))
}

func roundCashOutOdds(value float64) float64 {
	if math.IsNaN(value) || math.IsInf(value, 0) || value < 1.01 {
		return 1.01
	}
	return math.Round(value*100) / 100
}

func roundCashOutAmount(value float64) float64 {
	return math.Round(value*100) / 100
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
