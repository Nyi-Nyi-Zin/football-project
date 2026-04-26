package services

import (
	"context"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	bettingDomain "betting-app/internal/modules/betting/domain"
	oddsDomain "betting-app/internal/modules/odds/domain"
	"betting-app/pkg/logger"
	"betting-app/pkg/theoddsapi"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

var trackedLeagueKeys = []string{
	"soccer_epl",
	"soccer_spain_la_liga",
	"soccer_france_ligue_one",
	"soccer_uefa_champs_league",
	"soccer_germany_bundesliga",
	"soccer_italy_serie_a",
}

var leagueDisplayNames = map[string]string{
	"soccer_epl":                "Premier League",
	"soccer_spain_la_liga":      "LaLiga",
	"soccer_france_ligue_one":   "Ligue 1",
	"soccer_uefa_champs_league": "Champions League",
	"soccer_germany_bundesliga": "Bundesliga",
	"soccer_italy_serie_a":      "Serie A",
}

type TheOddsSyncService struct {
	client        *theoddsapi.Client
	matchRepo     bettingDomain.MatchRepository
	oddsRepo      oddsDomain.OddsRepository
	syncInterval  time.Duration
	leagueKeys    []string
}

func NewTheOddsSyncService(apiKey string, syncInterval time.Duration, matchRepo bettingDomain.MatchRepository, oddsRepo oddsDomain.OddsRepository) *TheOddsSyncService {
	if syncInterval <= 0 {
		syncInterval = 30 * time.Minute
	}

	return &TheOddsSyncService{
		client:       theoddsapi.NewClient(apiKey),
		matchRepo:    matchRepo,
		oddsRepo:     oddsRepo,
		syncInterval: syncInterval,
		leagueKeys:   trackedLeagueKeys,
	}
}

func (s *TheOddsSyncService) StartSync(ctx context.Context) {
	go s.syncAll(ctx)

	ticker := time.NewTicker(s.syncInterval)
	go func() {
		for {
			select {
			case <-ctx.Done():
				ticker.Stop()
				return
			case <-ticker.C:
				s.syncAll(ctx)
			}
		}
	}()
}

func (s *TheOddsSyncService) syncAll(ctx context.Context) {
	from := time.Now().UTC().Format(time.RFC3339)
	to := time.Now().AddDate(0, 0, 7).UTC().Format(time.RFC3339)

	logger.Info("Starting The Odds API sync", "league_count", len(s.leagueKeys), "from", from, "to", to)

	totalEvents := 0
	totalMatchesUpserted := 0
	totalOddsUpserted := 0

	for _, leagueKey := range s.leagueKeys {
		events, err := s.client.FetchLeagueOdds(leagueKey, from, to)
		if err != nil {
			logger.Error("The Odds API fetch failed", "league_key", leagueKey, "error", err)
			continue
		}

		totalEvents += len(events)
		for _, event := range events {
			match, created, err := s.upsertMatch(ctx, leagueKey, event)
			if err != nil {
				logger.Error("Failed to upsert match from The Odds API", "league_key", leagueKey, "event_id", event.ID, "error", err)
				continue
			}
			if created {
				totalMatchesUpserted++
			}

			odds, ok := extractBestH2HOdds(event)
			if !ok {
				continue
			}

			changed, err := s.upsertOdds(ctx, match.ID, odds)
			if err != nil {
				logger.Error("Failed to upsert odds from The Odds API", "match_id", match.ID, "event_id", event.ID, "error", err)
				continue
			}
			if changed {
				totalOddsUpserted++
			}
		}
	}

	logger.Info(
		"The Odds API sync completed",
		"events_fetched", totalEvents,
		"matches_upserted", totalMatchesUpserted,
		"odds_updated", totalOddsUpserted,
	)
}

func (s *TheOddsSyncService) upsertMatch(ctx context.Context, leagueKey string, event theoddsapi.Event) (*bettingDomain.Match, bool, error) {
	match, err := s.matchRepo.FindMatchByExternalID(ctx, event.ID)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, false, err
	}

	status := bettingDomain.MatchStatusUpcoming
	if event.CommenceTime.Before(time.Now().UTC()) {
		status = bettingDomain.MatchStatusLive
	}

	if match == nil || errors.Is(err, gorm.ErrRecordNotFound) {
		match = &bettingDomain.Match{
			ID:         uuid.NewString(),
			ExternalID: event.ID,
			Sport:      "Football",
			League:     leagueNameForKey(leagueKey),
			HomeTeam:   event.HomeTeam,
			AwayTeam:   event.AwayTeam,
			StartTime:  event.CommenceTime.UTC(),
			Status:     status,
			CreatedAt:  time.Now(),
			UpdatedAt:  time.Now(),
		}
		if err := s.matchRepo.CreateMatch(ctx, match); err != nil {
			return nil, false, err
		}
		return match, true, nil
	}

	match.ExternalID = event.ID
	match.League = leagueNameForKey(leagueKey)
	match.Sport = "Football"
	match.HomeTeam = event.HomeTeam
	match.AwayTeam = event.AwayTeam
	match.StartTime = event.CommenceTime.UTC()
	match.Status = status
	match.UpdatedAt = time.Now()

	if err := s.matchRepo.UpdateMatch(ctx, match); err != nil {
		return nil, false, err
	}
	return match, false, nil
}

func (s *TheOddsSyncService) upsertOdds(ctx context.Context, matchID string, extracted extractedOdds) (bool, error) {
	current, err := s.oddsRepo.FindByMatchID(ctx, matchID)
	if err == nil && !hasOddsChanged(current, extracted) {
		return false, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return false, err
	}

	odds := &oddsDomain.Odds{
		MatchID:  matchID,
		HomeOdds: extracted.HomeOdds,
		AwayOdds: extracted.AwayOdds,
		DrawOdds: extracted.DrawOdds,
		IsActive: true,
		Source:   "the_odds_api",
	}
	if err := s.oddsRepo.Upsert(ctx, odds); err != nil {
		return false, err
	}

	history := &oddsDomain.OddsHistory{
		MatchID:   matchID,
		HomeOdds:  extracted.HomeOdds,
		AwayOdds:  extracted.AwayOdds,
		DrawOdds:  extracted.DrawOdds,
		Timestamp: time.Now().UTC(),
	}
	if err := s.oddsRepo.SaveHistory(ctx, history); err != nil {
		logger.Warn("Failed to save odds history", "match_id", matchID, "error", err)
	}

	return true, nil
}

type extractedOdds struct {
	HomeOdds float64
	AwayOdds float64
	DrawOdds float64
}

func extractBestH2HOdds(event theoddsapi.Event) (extractedOdds, bool) {
	var result extractedOdds

	for _, bookmaker := range event.Bookmakers {
		for _, market := range bookmaker.Markets {
			if market.Key != "h2h" {
				continue
			}
			for _, outcome := range market.Outcomes {
				switch {
				case strings.EqualFold(outcome.Name, event.HomeTeam):
					result.HomeOdds = math.Max(result.HomeOdds, outcome.Price)
				case strings.EqualFold(outcome.Name, event.AwayTeam):
					result.AwayOdds = math.Max(result.AwayOdds, outcome.Price)
				case strings.EqualFold(outcome.Name, "draw"):
					result.DrawOdds = math.Max(result.DrawOdds, outcome.Price)
				}
			}
		}
	}

	if result.HomeOdds <= 1 || result.AwayOdds <= 1 {
		return extractedOdds{}, false
	}
	return result, true
}

func hasOddsChanged(current *oddsDomain.Odds, next extractedOdds) bool {
	if current == nil {
		return true
	}
	return current.HomeOdds != next.HomeOdds || current.AwayOdds != next.AwayOdds || current.DrawOdds != next.DrawOdds
}

func leagueNameForKey(leagueKey string) string {
	if name, ok := leagueDisplayNames[leagueKey]; ok {
		return name
	}
	return fmt.Sprintf("League %s", leagueKey)
}
