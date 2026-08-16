package domain

import "testing"

func TestEvaluateBetSettlement(t *testing.T) {
	home := 2
	away := 1
	finished := Match{Status: MatchStatusFinished, HomeScore: &home, AwayScore: &away}

	tests := []struct {
		name      string
		market    string
		selection string
		status    BetStatus
		payout    float64
		isSettled bool
	}{
		{
			name:      "home win",
			market:    "match_result",
			selection: "w1",
			status:    BetStatusWon,
			payout:    220,
			isSettled: true,
		},
		{
			name:      "away win loses",
			market:    "match_result",
			selection: "w2",
			status:    BetStatusLost,
			payout:    0,
			isSettled: true,
		},
		{
			name:      "double chance home or draw",
			market:    "double_chance",
			selection: "1x",
			status:    BetStatusWon,
			payout:    180,
			isSettled: true,
		},
		{
			name:      "draw no bet away is void on draw",
			market:    "draw_no_bet",
			selection: "away_dnb",
			status:    BetStatusCancelled,
			payout:    100,
			isSettled: true,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			match := finished
			if test.name == "draw no bet away is void on draw" {
				homeScore := 1
				awayScore := 1
				match.HomeScore = &homeScore
				match.AwayScore = &awayScore
			}
			bet := &Bet{
				MarketKey:       test.market,
				Selection:       test.selection,
				Stake:           100,
				PotentialPayout: test.payout,
			}
			decision, err := EvaluateBetSettlement(&match, bet)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if decision.Status != test.status {
				t.Fatalf("status = %q, want %q", decision.Status, test.status)
			}
			if decision.Payout != test.payout {
				t.Fatalf("payout = %v, want %v", decision.Payout, test.payout)
			}
			if decision.IsSettled != test.isSettled {
				t.Fatalf("isSettled = %v, want %v", decision.IsSettled, test.isSettled)
			}
		})
	}
}

func TestEvaluateBetSettlementUnfinishedMatch(t *testing.T) {
	home := 3
	away := 0
	match := &Match{Status: MatchStatusLive, HomeScore: &home, AwayScore: &away}
	bet := &Bet{Status: BetStatusActive, MarketKey: "match_result", Selection: "w1"}

	decision, err := EvaluateBetSettlement(match, bet)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if decision.IsSettled {
		t.Fatal("live match must not be settled")
	}
	if decision.Status != BetStatusActive {
		t.Fatalf("status = %q, want %q", decision.Status, BetStatusActive)
	}
}
