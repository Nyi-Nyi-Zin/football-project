package sportmonks

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type Client struct {
	token      string
	httpClient *http.Client
}

func NewClient(token string) *Client {
	return &Client{
		token: token,
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

type FixturesResponse struct {
	Data []Fixture `json:"data"`
}

type Fixture struct {
	ID         int    `json:"id"`
	Name       string `json:"name"`
	StartingAt string `json:"starting_at"`
}

func (c *Client) GetFixtures() ([]Fixture, error) {
	url := fmt.Sprintf("https://api.sportmonks.com/v3/football/fixtures?api_token=%s", c.token)

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code from sportmonks: %d", resp.StatusCode)
	}

	var parsed FixturesResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}

	return parsed.Data, nil
}
