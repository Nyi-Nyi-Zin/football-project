package services

import (
	"context"
	"errors"
	"strconv"
	"strings"
	"time"

	bettingDomain "betting-app/internal/modules/betting/domain"
	"betting-app/pkg/logger"
	"betting-app/pkg/openligadb"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type OpenLigaDBSyncService struct {
	client       *openligadb.Client
	matchRepo    bettingDomain.MatchRepository
	leagues      []string
	season       int
	syncInterval time.Duration
}

func NewOpenLigaDBSyncService(
	leagueCSV string,
	season int,
	syncInterval time.Duration,
	matchRepo bettingDomain.MatchRepository,
) *OpenLigaDBSyncService {
	if season <= 0 {
		season = time.Now().UTC().Year()
	}
	if syncInterval <= 0 {
		syncInterval = 6 * time.Hour
	}

	var leagues []string
	for _, league := range strings.Split(leagueCSV, ",") {
		league = strings.TrimSpace(league)
		if league != "" {
			leagues = append(leagues, league)
		}
	}
	if len(leagues) == 0 {
		leagues = []string{"bl1"}
	}

	return &OpenLigaDBSyncService{
		client:       openligadb.NewClient(),
		matchRepo:    matchRepo,
		leagues:      leagues,
		season:       season,
		syncInterval: syncInterval,
	}
}

func (s *OpenLigaDBSyncService) StartSync(ctx context.Context) {
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

func (s *OpenLigaDBSyncService) syncAll(ctx context.Context) {
	logger.Info("Starting OpenLigaDB football fixture sync", "leagues", s.leagues, "season", s.season)
	var fetched, upserted int

	for _, league := range s.leagues {
		matches, err := s.client.GetMatchData(league, s.season)
		if err != nil {
			logger.Error("OpenLigaDB fixture fetch failed", "league", league, "error", err)
			continue
		}
		fetched += len(matches)
		for _, match := range matches {
			created, err := s.upsertMatch(ctx, league, match)
			if err != nil {
				logger.Error("OpenLigaDB match upsert failed", "league", league, "match_id", match.MatchID, "error", err)
				continue
			}
			if created {
				upserted++
			}
		}
	}

	logger.Info("OpenLigaDB football fixture sync completed", "fetched", fetched, "created", upserted)
}

func (s *OpenLigaDBSyncService) upsertMatch(ctx context.Context, league string, source openligadb.Match) (bool, error) {
	if source.MatchID <= 0 || strings.TrimSpace(source.Team1.TeamName) == "" || strings.TrimSpace(source.Team2.TeamName) == "" {
		return false, nil
	}

	externalID := "openligadb:" + strconv.Itoa(source.MatchID)
	match, err := s.matchRepo.FindMatchByExternalID(ctx, externalID)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return false, err
	}

	startTime := parseMatchTime(source)
	status := statusFor(source, startTime)
	leagueName := strings.TrimSpace(source.LeagueName)
	if leagueName == "" {
		leagueName = league
	}

	if errors.Is(err, gorm.ErrRecordNotFound) || match == nil {
		match = &bettingDomain.Match{
			ID:         uuid.NewString(),
			ExternalID: externalID,
			Sport:      "Football",
			League:     leagueName,
			HomeTeam:   strings.TrimSpace(source.Team1.TeamName),
			AwayTeam:   strings.TrimSpace(source.Team2.TeamName),
			StartTime:  startTime,
			Status:     status,
			CreatedAt:  time.Now().UTC(),
			UpdatedAt:  time.Now().UTC(),
			Testing:    "openligadb",
		}
		applySourceScore(match, source)
		return true, s.matchRepo.CreateMatch(ctx, match)
	}

	match.ExternalID = externalID
	match.Sport = "Football"
	match.League = leagueName
	match.HomeTeam = strings.TrimSpace(source.Team1.TeamName)
	match.AwayTeam = strings.TrimSpace(source.Team2.TeamName)
	match.StartTime = startTime
	match.Status = status
	match.UpdatedAt = time.Now().UTC()
	applySourceScore(match, source)
	return false, s.matchRepo.UpdateMatch(ctx, match)
}

func parseMatchTime(source openligadb.Match) time.Time {
	for _, value := range []string{source.MatchDateTimeUTC, source.MatchDateTime} {
		if parsed, err := time.Parse(time.RFC3339, value); err == nil {
			return parsed.UTC()
		}
		if parsed, err := time.Parse("2006-01-02T15:04:05", value); err == nil {
			return parsed.UTC()
		}
	}
	return time.Now().UTC().Add(24 * time.Hour)
}

func statusFor(source openligadb.Match, startTime time.Time) bettingDomain.MatchStatus {
	if source.MatchIsFinished {
		return bettingDomain.MatchStatusFinished
	}
	if startTime.Before(time.Now().UTC()) {
		return bettingDomain.MatchStatusLive
	}
	return bettingDomain.MatchStatusUpcoming
}

func applySourceScore(match *bettingDomain.Match, source openligadb.Match) {
	if len(source.MatchResults) == 0 {
		return
	}
	result := source.MatchResults[len(source.MatchResults)-1]
	match.HomeScore = &result.PointsTeam1
	match.AwayScore = &result.PointsTeam2
}
