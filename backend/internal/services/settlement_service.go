package services

import (
	"context"
	"fmt"
	"time"

	bettingDomain "betting-app/internal/modules/betting/domain"
	paymentDomain "betting-app/internal/modules/payment/domain"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// AtomicSettlementService applies a single-bet settlement and its wallet
// ledger entry in one database transaction. Accumulator settlement remains a
// separate workflow because every leg must be resolved before the slip payout.
type AtomicSettlementService struct {
	db *gorm.DB
}

func NewAtomicSettlementService(db *gorm.DB) *AtomicSettlementService {
	return &AtomicSettlementService{db: db}
}

func (s *AtomicSettlementService) SettleBet(
	ctx context.Context,
	betID string,
) (*bettingDomain.SettlementDecision, error) {
	var decision *bettingDomain.SettlementDecision

	err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var bet bettingDomain.Bet
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Preload("Match").Where("id = ?", betID).First(&bet).Error; err != nil {
			return fmt.Errorf("settlement: find bet: %w", err)
		}

		if bet.Status != bettingDomain.BetStatusPending &&
			bet.Status != bettingDomain.BetStatusActive {
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
			var wallet paymentDomain.Wallet
			if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
				Where("user_id = ?", bet.UserID).First(&wallet).Error; err != nil {
				return fmt.Errorf("settlement: lock wallet: %w", err)
			}

			balanceBefore := wallet.Balance
			balanceAfter := balanceBefore + currentDecision.Payout
			if err := tx.Model(&paymentDomain.Wallet{}).
				Where("user_id = ?", bet.UserID).
				Update("balance", gorm.Expr("balance + ?", currentDecision.Payout)).Error; err != nil {
				return fmt.Errorf("settlement: credit wallet: %w", err)
			}

			txType := paymentDomain.TransactionBetWin
			if currentDecision.Status == bettingDomain.BetStatusCancelled {
				txType = paymentDomain.TransactionRefund
			}
			ledger := &paymentDomain.Transaction{
				UserID:         bet.UserID,
				Type:           txType,
				Amount:         currentDecision.Payout,
				Currency:       wallet.Currency,
				Status:         paymentDomain.TransactionCompleted,
				IdempotencyKey: fmt.Sprintf("settlement:bet:%s", bet.ID),
				Reference:      bet.ID,
				Description:    currentDecision.Reason,
				BalanceBefore:  balanceBefore,
				BalanceAfter:   balanceAfter,
			}
			if err := tx.Create(ledger).Error; err != nil {
				return fmt.Errorf("settlement: create ledger entry: %w", err)
			}
		}

		now := time.Now().UTC()
		result := tx.Model(&bettingDomain.Bet{}).
			Where("id = ? AND status IN ?", bet.ID, []bettingDomain.BetStatus{
				bettingDomain.BetStatusPending,
				bettingDomain.BetStatusActive,
			}).
			Updates(map[string]interface{}{
				"status":     currentDecision.Status,
				"settled_at": now,
			})
		if result.Error != nil {
			return fmt.Errorf("settlement: update bet: %w", result.Error)
		}
		if result.RowsAffected != 1 {
			return fmt.Errorf("settlement: bet was changed concurrently")
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return decision, nil
}
