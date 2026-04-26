package services

import (
	"context"
	"strings"
	"time"

	bettingDomain "betting-app/internal/modules/betting/domain"
	"betting-app/pkg/logger"
	"betting-app/pkg/sportmonks"

	"github.com/google/uuid"
)

type SportmonksSyncService struct {
	client    *sportmonks.Client
	matchRepo bettingDomain.MatchRepository
}

func NewSportmonksSyncService(token string, matchRepo bettingDomain.MatchRepository) *SportmonksSyncService {
	return &SportmonksSyncService{
		client:    sportmonks.NewClient(token),
		matchRepo: matchRepo,
	}
}

func (s *SportmonksSyncService) StartSync(ctx context.Context) {
	// Execute immediately in background
	go s.syncFixtures(ctx)

	// Run periodically
	ticker := time.NewTicker(6 * time.Hour)
	go func() {
		for {
			select {
			case <-ctx.Done():
				ticker.Stop()
				return
			case <-ticker.C:
				s.syncFixtures(ctx)
			}
		}
	}()
}

func (s *SportmonksSyncService) syncFixtures(ctx context.Context) {
	logger.Info("Starting Sportmonks fixtures sync")

	fixtures, err := s.client.GetFixtures()
	if err != nil {
		logger.Error("Failed to fetch fixtures from Sportmonks", "error", err)
		return
	}

	count := 0
	for _, fixture := range fixtures {
		teams := strings.Split(fixture.Name, " vs ")
		if len(teams) != 2 {
			continue // skip if parsing fails
		}

		homeTeam := strings.TrimSpace(teams[0])
		awayTeam := strings.TrimSpace(teams[1])
		leagueName := strings.TrimSpace(fixture.League.Name)
		if leagueName == "" {
			leagueName = "Sportmonks"
		}

		startTime, err := time.Parse("2006-01-02 15:04:05", fixture.StartingAt)
		if err != nil {
			// fallback if format differs
			startTime = time.Now().Add(24 * time.Hour)
		}

		match := &bettingDomain.Match{
			ID:        uuid.New().String(),
			Sport:     "Football",
			League:    leagueName,
			HomeTeam:  homeTeam,
			AwayTeam:  awayTeam,
			StartTime: startTime,
			Status:    bettingDomain.MatchStatusUpcoming,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}

		// Note: Depending on unique constraints, this might fail if match already exists
		err = s.matchRepo.CreateMatch(ctx, match)
		if err == nil {
			count++
		}
	}

	logger.Info("Sportmonks fixtures sync completed", "inserted_count", count, "fetched", len(fixtures))
}
