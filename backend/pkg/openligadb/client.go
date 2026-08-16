package openligadb

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const defaultBaseURL = "https://api.openligadb.de"

type Client struct {
	baseURL    string
	httpClient *http.Client
}

func NewClient() *Client {
	return &Client{
		baseURL: defaultBaseURL,
		httpClient: &http.Client{
			Timeout: 20 * time.Second,
		},
	}
}

type Match struct {
	MatchID          int           `json:"matchID"`
	MatchDateTime    string        `json:"matchDateTime"`
	MatchDateTimeUTC string        `json:"matchDateTimeUTC"`
	LeagueName       string        `json:"leagueName"`
	LeagueShortcut   string        `json:"leagueShortcut"`
	MatchIsFinished  bool          `json:"matchIsFinished"`
	Team1            Team          `json:"team1"`
	Team2            Team          `json:"team2"`
	MatchResults     []MatchResult `json:"matchResults"`
}

type Team struct {
	TeamID   int    `json:"teamId"`
	TeamName string `json:"teamName"`
}

type MatchResult struct {
	PointsTeam1 int    `json:"pointsTeam1"`
	PointsTeam2 int    `json:"pointsTeam2"`
	ResultName  string `json:"resultName"`
}

func (c *Client) GetMatchData(league string, season int) ([]Match, error) {
	url := fmt.Sprintf("%s/getmatchdata/%s/%d", c.baseURL, league, season)
	request, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("openligadb create request: %w", err)
	}

	response, err := c.httpClient.Do(request)
	if err != nil {
		return nil, fmt.Errorf("openligadb request: %w", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("openligadb unexpected status: %s", response.Status)
	}

	var matches []Match
	if err := json.NewDecoder(response.Body).Decode(&matches); err != nil {
		return nil, fmt.Errorf("openligadb decode response: %w", err)
	}
	return matches, nil
}
