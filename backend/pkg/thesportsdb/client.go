package thesportsdb

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const defaultBaseURL = "https://www.thesportsdb.com/api/v1/json"

type Client struct {
	httpClient *http.Client
	baseURL    string
	apiKey     string
}

type Event struct {
	IDEvent    string `json:"idEvent"`
	IDLeague   string `json:"idLeague"`
	LeagueName string `json:"strLeague"`
	Season     string `json:"strSeason"`
	EventName  string `json:"strEvent"`
	HomeTeam   string `json:"strHomeTeam"`
	AwayTeam   string `json:"strAwayTeam"`
	Timestamp  string `json:"strTimestamp"`
	Date       string `json:"dateEvent"`
	Time       string `json:"strTime"`
	Status     string `json:"strStatus"`
	HomeScore  *int   `json:"intHomeScore"`
	AwayScore  *int   `json:"intAwayScore"`
}

type eventsResponse struct {
	Events []Event `json:"events"`
}

func NewClient(apiKey string) *Client {
	if strings.TrimSpace(apiKey) == "" {
		apiKey = "123"
	}
	return &Client{
		httpClient: &http.Client{Timeout: 20 * time.Second},
		baseURL:    defaultBaseURL,
		apiKey:     strings.TrimSpace(apiKey),
	}
}

func (c *Client) GetSeasonEvents(ctx context.Context, leagueID, season string) ([]Event, error) {
	endpoint := fmt.Sprintf("%s/%s/eventsseason.php", strings.TrimRight(c.baseURL, "/"), url.PathEscape(c.apiKey))
	query := url.Values{}
	query.Set("id", leagueID)
	query.Set("s", season)
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint+"?"+query.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("thesportsdb request: %w", err)
	}

	response, err := c.httpClient.Do(request)
	if err != nil {
		return nil, fmt.Errorf("thesportsdb request: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < http.StatusOK || response.StatusCode >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("thesportsdb returned HTTP %d", response.StatusCode)
	}

	var payload eventsResponse
	if err := json.NewDecoder(response.Body).Decode(&payload); err != nil {
		return nil, fmt.Errorf("thesportsdb decode: %w", err)
	}
	return payload.Events, nil
}
