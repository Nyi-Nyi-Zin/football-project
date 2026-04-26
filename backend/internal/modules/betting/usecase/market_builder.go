package usecase

import (
	"math"

	bettingDomain "betting-app/internal/modules/betting/domain"
	oddsDomain "betting-app/internal/modules/odds/domain"
)

func buildMarkets(odds *oddsDomain.Odds) []bettingDomain.Market {
	if odds == nil || odds.HomeOdds <= 1 || odds.AwayOdds <= 1 {
		return nil
	}

	homeProb := 1 / odds.HomeOdds
	awayProb := 1 / odds.AwayOdds
	drawProb := 0.0
	if odds.DrawOdds > 1 {
		drawProb = 1 / odds.DrawOdds
	}

	totalProb := homeProb + awayProb + drawProb
	if totalProb <= 0 {
		return nil
	}

	homeProb /= totalProb
	awayProb /= totalProb
	drawProb /= totalProb

	bttsYesProb := clampProbability(0.42 + math.Abs(homeProb-awayProb)*0.12 + drawProb*0.28)
	bttsNoProb := clampProbability(1 - bttsYesProb)
	over25Prob := clampProbability(0.45 + (1-drawProb)*0.20)
	under25Prob := clampProbability(1 - over25Prob)

	return []bettingDomain.Market{
		{
			Key:  "match_result",
			Name: "Match Result",
			Selections: []bettingDomain.MarketSelection{
				{Key: "w1", Label: "W1", Odds: roundOdds(1 / homeProb)},
				{Key: "x", Label: "X", Odds: roundOdds(1 / drawProb)},
				{Key: "w2", Label: "W2", Odds: roundOdds(1 / awayProb)},
			},
		},
		{
			Key:  "double_chance",
			Name: "Double Chance",
			Selections: []bettingDomain.MarketSelection{
				{Key: "1x", Label: "1X", Odds: roundOdds(1 / clampProbability(homeProb+drawProb))},
				{Key: "12", Label: "12", Odds: roundOdds(1 / clampProbability(homeProb+awayProb))},
				{Key: "x2", Label: "X2", Odds: roundOdds(1 / clampProbability(drawProb+awayProb))},
			},
		},
		{
			Key:  "draw_no_bet",
			Name: "Draw No Bet",
			Selections: []bettingDomain.MarketSelection{
				{Key: "home_dnb", Label: "1 DNB", Odds: roundOdds((homeProb + awayProb) / clampProbability(homeProb))},
				{Key: "away_dnb", Label: "2 DNB", Odds: roundOdds((homeProb + awayProb) / clampProbability(awayProb))},
			},
		},
		{
			Key:  "btts",
			Name: "Both Teams To Score",
			Selections: []bettingDomain.MarketSelection{
				{Key: "btts_yes", Label: "Yes", Odds: roundOdds(1 / bttsYesProb)},
				{Key: "btts_no", Label: "No", Odds: roundOdds(1 / bttsNoProb)},
			},
		},
		{
			Key:  "total_goals_2_5",
			Name: "Total Goals 2.5",
			Selections: []bettingDomain.MarketSelection{
				{Key: "over_2_5", Label: "Over 2.5", Odds: roundOdds(1 / over25Prob)},
				{Key: "under_2_5", Label: "Under 2.5", Odds: roundOdds(1 / under25Prob)},
			},
		},
	}
}

func findSelection(markets []bettingDomain.Market, marketKey, selectionKey string) *bettingDomain.MarketSelection {
	for _, market := range markets {
		if market.Key != marketKey {
			continue
		}
		for _, selection := range market.Selections {
			if selection.Key == selectionKey {
				copy := selection
				return &copy
			}
		}
	}
	return nil
}

func clampProbability(value float64) float64 {
	return math.Max(0.08, math.Min(0.92, value))
}

func roundOdds(value float64) float64 {
	if math.IsNaN(value) || math.IsInf(value, 0) || value < 1.01 {
		return 1.01
	}
	return math.Round(value*100) / 100
}

// buildFallbackMarkets returns a basic set of markets with balanced odds (2.00)
// for when no odds data exists yet in the database.
func buildFallbackMarkets() []bettingDomain.Market {
	return []bettingDomain.Market{
		{
			Key:  "match_result",
			Name: "Match Result",
			Selections: []bettingDomain.MarketSelection{
				{Key: "w1", Label: "W1", Odds: 2.00},
				{Key: "x", Label: "X", Odds: 3.00},
				{Key: "w2", Label: "W2", Odds: 2.00},
			},
		},
		{
			Key:  "double_chance",
			Name: "Double Chance",
			Selections: []bettingDomain.MarketSelection{
				{Key: "1x", Label: "1X", Odds: 1.40},
				{Key: "12", Label: "12", Odds: 1.25},
				{Key: "x2", Label: "X2", Odds: 1.40},
			},
		},
		{
			Key:  "btts",
			Name: "Both Teams To Score",
			Selections: []bettingDomain.MarketSelection{
				{Key: "btts_yes", Label: "Yes", Odds: 1.80},
				{Key: "btts_no", Label: "No", Odds: 1.90},
			},
		},
		{
			Key:  "total_goals_2_5",
			Name: "Total Goals 2.5",
			Selections: []bettingDomain.MarketSelection{
				{Key: "over_2_5", Label: "Over 2.5", Odds: 1.85},
				{Key: "under_2_5", Label: "Under 2.5", Odds: 1.85},
			},
		},
	}
}
