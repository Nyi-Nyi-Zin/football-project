package services

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	bettingDomain "betting-app/internal/modules/betting/domain"
	"betting-app/pkg/logger"
	"betting-app/pkg/thesportsdb"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type TheSportsDBSyncService struct {
	client       *thesportsdb.Client
	matchRepo    bettingDomain.MatchRepository
	leagueIDs    []string
	season       string
	syncInterval time.Duration
}

func NewTheSportsDBSyncService(
	apiKey string,
	leagueCSV string,
	season string,
	syncInterval time.Duration,
	matchRepo bettingDomain.MatchRepository,
) *TheSportsDBSyncService {
	if strings.TrimSpace(season) == "" {
		season = fmt.Sprintf("%d-%d", time.Now().UTC().Year(), time.Now().UTC().Year()+1)
	}
	if syncInterval <= 0 {
		syncInterval = 6 * time.Hour
	}

	var leagueIDs []string
	for _, leagueID := range strings.Split(leagueCSV, ",") {
		leagueID = strings.TrimSpace(leagueID)
		if leagueID != "" {
			leagueIDs = append(leagueIDs, leagueID)
		}
	}
	if len(leagueIDs) == 0 {
		leagueIDs = []string{"4328", "4335", "4334", "4332", "4480"}
	}

	return &TheSportsDBSyncService{
		client:       thesportsdb.NewClient(apiKey),
		matchRepo:    matchRepo,
		leagueIDs:    leagueIDs,
		season:       season,
		syncInterval: syncInterval,
	}
}

func (s *TheSportsDBSyncService) StartSync(ctx context.Context) {
	go s.syncAll(ctx)

	ticker := time.NewTicker(s.syncInterval)
	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				s.syncAll(ctx)
			}
		}
	}()
}

func (s *TheSportsDBSyncService) syncAll(ctx context.Context) {
	logger.Info("Starting TheSportsDB football fixture sync", "leagues", s.leagueIDs, "season", s.season)
	var fetched, created int

	for _, leagueID := range s.leagueIDs {
		events, err := s.client.GetSeasonEvents(ctx, leagueID, s.season)
		if err != nil {
			logger.Warn("TheSportsDB fixture fetch failed", "league_id", leagueID, "error", err)
			continue
		}
		fetched += len(events)
		for _, event := range events {
			wasCreated, err := s.upsertEvent(ctx, leagueID, event)
			if err != nil {
				logger.Warn("TheSportsDB match upsert failed", "league_id", leagueID, "event_id", event.IDEvent, "error", err)
				continue
			}
			if wasCreated {
				created++
			}
		}
	}

	logger.Info("TheSportsDB football fixture sync completed", "fetched", fetched, "created", created)
}

func (s *TheSportsDBSyncService) upsertEvent(ctx context.Context, leagueID string, source thesportsdb.Event) (bool, error) {
	home := strings.TrimSpace(source.HomeTeam)
	away := strings.TrimSpace(source.AwayTeam)
	if strings.TrimSpace(source.IDEvent) == "" || home == "" || away == "" {
		return false, nil
	}

	externalID := "thesportsdb:" + source.IDEvent
	match, err := s.matchRepo.FindMatchByExternalID(ctx, externalID)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return false, err
	}

	startTime := parseTheSportsDBTime(source)
	status := statusForTheSportsDB(source, startTime)
	leagueName := strings.TrimSpace(source.LeagueName)
	if leagueName == "" {
		leagueName = "TheSportsDB league " + leagueID
	}

	if errors.Is(err, gorm.ErrRecordNotFound) || match == nil {
		match = &bettingDomain.Match{
			ID:         uuid.NewString(),
			ExternalID: externalID,
			Sport:      "Football",
			League:     leagueName,
			HomeTeam:   home,
			AwayTeam:   away,
			StartTime:  startTime,
			Status:     status,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
			Testing:    "thesportsdb",
		}
		applyTheSportsDBScore(match, source)
		return true, s.matchRepo.CreateMatch(ctx, match)
	}

	match.Sport = "Football"
	match.League = leagueName
	match.HomeTeam = home
	match.AwayTeam = away
	match.StartTime = startTime
	match.Status = status
	match.UpdatedAt = time.Now().UTC()
	applyTheSportsDBScore(match, source)
	return false, s.matchRepo.UpdateMatch(ctx, match)
}

func parseTheSportsDBTime(source thesportsdb.Event) time.Time {
	for _, value := range []string{source.Timestamp, source.Date + "T" + source.Time} {
		if parsed, err := time.Parse(time.RFC3339, value); err == nil {
			return parsed.UTC()
		}
		if parsed, err := time.Parse("2006-01-02T15:04:05", value); err == nil {
			return parsed.UTC()
		}
		if parsed, err := time.Parse("2006-01-02T15:04", value); err == nil {
			return parsed.UTC()
		}
	}
	return time.Now().UTC().Add(24 * time.Hour)
}

func statusForTheSportsDB(source thesportsdb.Event, startTime time.Time) bettingDomain.MatchStatus {
	status := strings.ToLower(strings.TrimSpace(source.Status))
	if strings.Contains(status, "postpon") || strings.Contains(status, "cancel") {
		return bettingDomain.MatchStatusCancelled
	}
	if source.HomeScore != nil && source.AwayScore != nil && (strings.Contains(status, "finish") || strings.Contains(status, "ft")) {
		return bettingDomain.MatchStatusFinished
	}
	if startTime.Before(time.Now().UTC()) {
		return bettingDomain.MatchStatusLive
	}
	return bettingDomain.MatchStatusUpcoming
}

func applyTheSportsDBScore(match *bettingDomain.Match, source thesportsdb.Event) {
	if source.HomeScore != nil {
		match.HomeScore = source.HomeScore
	}
	if source.AwayScore != nil {
		match.AwayScore = source.AwayScore
	}
}

func parseScore(value string) *int {
	if value == "" {
		return nil
	}
	score, err := strconv.Atoi(value)
	if err != nil {
		return nil
	}
	return &score
}
