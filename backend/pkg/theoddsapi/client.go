package theoddsapi

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

type Client struct {
	apiKey     string
	httpClient *http.Client
}

func NewClient(apiKey string) *Client {
	return &Client{
		apiKey: apiKey,
		httpClient: &http.Client{
			Timeout: 20 * time.Second,
		},
	}
}

type Event struct {
	ID           string      `json:"id"`
	SportKey     string      `json:"sport_key"`
	CommenceTime time.Time   `json:"commence_time"`
	HomeTeam     string      `json:"home_team"`
	AwayTeam     string      `json:"away_team"`
	Bookmakers   []Bookmaker `json:"bookmakers"`
}

type Bookmaker struct {
	Key     string   `json:"key"`
	Title   string   `json:"title"`
	Markets []Market `json:"markets"`
}

type Market struct {
	Key      string    `json:"key"`
	Outcomes []Outcome `json:"outcomes"`
}

type Outcome struct {
	Name  string  `json:"name"`
	Price float64 `json:"price"`
}

func (c *Client) FetchLeagueOdds(league, from, to string) ([]Event, error) {
	endpoint := fmt.Sprintf("https://api.the-odds-api.com/v4/sports/%s/odds", league)
	params := url.Values{}
	params.Set("apiKey", c.apiKey)
	params.Set("regions", "eu")
	params.Set("markets", "h2h")
	params.Set("commenceTimeFrom", from)
	params.Set("commenceTimeTo", to)

	req, err := http.NewRequest(http.MethodGet, endpoint+"?"+params.Encode(), nil)
	if err != nil {
		return nil, err
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("theoddsapi.FetchLeagueOdds: unexpected status %s", resp.Status)
	}

	var events []Event
	if err := json.NewDecoder(resp.Body).Decode(&events); err != nil {
		return nil, err
	}

	return events, nil
}
