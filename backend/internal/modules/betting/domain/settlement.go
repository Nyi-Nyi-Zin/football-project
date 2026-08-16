package domain

import "fmt"

type SettlementDecision struct {
	Status    BetStatus `json:"status"`
	Payout    float64   `json:"payout"`
	Reason    string    `json:"reason"`
	IsSettled bool      `json:"is_settled"`
}

// EvaluateBetSettlement determines the outcome of a single bet from a
// completed match. It is intentionally side-effect free so callers can preview
// or apply it inside a transaction boundary later.
func EvaluateBetSettlement(match *Match, bet *Bet) (SettlementDecision, error) {
	if match == nil || bet == nil {
		return SettlementDecision{}, fmt.Errorf("match and bet are required")
	}
	if match.Status == MatchStatusCancelled {
		return SettlementDecision{
			Status:    BetStatusCancelled,
			Payout:    bet.Stake,
			Reason:    "Match cancelled; stake should be refunded",
			IsSettled: true,
		}, nil
	}
	if match.Status != MatchStatusFinished {
		return SettlementDecision{
			Status:    bet.Status,
			Reason:    "Match is not finished",
			IsSettled: false,
		}, nil
	}
	if match.HomeScore == nil || match.AwayScore == nil {
		return SettlementDecision{}, fmt.Errorf("finished match is missing scores")
	}

	homeScore := *match.HomeScore
	awayScore := *match.AwayScore
	won, voided, err := evaluateSelection(
		bet.MarketKey,
		bet.Selection,
		homeScore,
		awayScore,
	)
	if err != nil {
		return SettlementDecision{}, err
	}
	if voided {
		return SettlementDecision{
			Status:    BetStatusCancelled,
			Payout:    bet.Stake,
			Reason:    "Selection voided by the final result",
			IsSettled: true,
		}, nil
	}
	if won {
		return SettlementDecision{
			Status:    BetStatusWon,
			Payout:    bet.PotentialPayout,
			Reason:    "Selection won",
			IsSettled: true,
		}, nil
	}
	return SettlementDecision{
		Status:    BetStatusLost,
		Payout:    0,
		Reason:    "Selection lost",
		IsSettled: true,
	}, nil
}

func evaluateSelection(marketKey, selection string, homeScore, awayScore int) (won, voided bool, err error) {
	homeWin := homeScore > awayScore
	draw := homeScore == awayScore
	awayWin := homeScore < awayScore
	totalGoals := homeScore + awayScore

	switch marketKey {
	case "match_result":
		switch selection {
		case "w1":
			return homeWin, false, nil
		case "x":
			return draw, false, nil
		case "w2":
			return awayWin, false, nil
		}
	case "double_chance":
		switch selection {
		case "1x":
			return homeWin || draw, false, nil
		case "12":
			return homeWin || awayWin, false, nil
		case "x2":
			return draw || awayWin, false, nil
		}
	case "draw_no_bet":
		switch selection {
		case "home_dnb":
			return homeWin, draw, nil
		case "away_dnb":
			return awayWin, draw, nil
		}
	case "btts":
		switch selection {
		case "btts_yes":
			return homeScore > 0 && awayScore > 0, false, nil
		case "btts_no":
			return homeScore == 0 || awayScore == 0, false, nil
		}
	case "total_goals_2_5":
		switch selection {
		case "over_2_5":
			return totalGoals > 2, false, nil
		case "under_2_5":
			return totalGoals < 3, false, nil
		}
	}

	return false, false, fmt.Errorf("unsupported market selection: %s/%s", marketKey, selection)
}
