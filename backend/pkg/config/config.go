package config

import (
	"fmt"
	"strings"

	"github.com/spf13/viper"
)

// Config holds all application configuration
type Config struct {
	Server     ServerConfig
	Database   DatabaseConfig
	Redis      RedisConfig
	JWT        JWTConfig
	App        AppConfig
	Security   SecurityConfig
	Sportmonks SportmonksConfig
	TheOddsAPI TheOddsAPIConfig
	OpenLigaDB OpenLigaDBConfig
}

type ServerConfig struct {
	Port string `mapstructure:"PORT"`
}

type DatabaseConfig struct {
	URL string `mapstructure:"DATABASE_URL"`
}

type RedisConfig struct {
	URL string `mapstructure:"REDIS_URL"`
}

type JWTConfig struct {
	Secret        string `mapstructure:"JWT_SECRET"`
	Expiry        string `mapstructure:"JWT_EXPIRY"`
	RefreshExpiry string `mapstructure:"REFRESH_EXPIRY"`
}

type AppConfig struct {
	Env string `mapstructure:"ENV"`
}

type SecurityConfig struct {
	WithdrawalCodePepper string `mapstructure:"WITHDRAWAL_CODE_PEPPER"`
	WithdrawalDataKey    string `mapstructure:"WITHDRAWAL_DATA_KEY"`
}

type SportmonksConfig struct {
	Token string `mapstructure:"SPORTMONKS_API_TOKEN"`
}

type TheOddsAPIConfig struct {
	Key          string `mapstructure:"THE_ODDS_API_KEY"`
	SyncInterval string `mapstructure:"THE_ODDS_SYNC_INTERVAL"`
}

type OpenLigaDBConfig struct {
	Leagues      string `mapstructure:"OPENLIGADB_LEAGUES"`
	Season       int    `mapstructure:"OPENLIGADB_SEASON"`
	SyncInterval string `mapstructure:"OPENLIGADB_SYNC_INTERVAL"`
}

// Load reads configuration from .env file and environment variables
func Load() (*Config, error) {
	viper.SetConfigFile(".env")
	viper.SetConfigType("env")
	viper.AutomaticEnv()

	// Set defaults
	viper.SetDefault("PORT", "8080")
	viper.SetDefault("ENV", "development")
	viper.SetDefault("JWT_EXPIRY", "15m")
	viper.SetDefault("REFRESH_EXPIRY", "168h")
	viper.SetDefault("DATABASE_URL", "postgres://user:password@localhost:5432/appdb?sslmode=disable")
	viper.SetDefault("REDIS_URL", "redis://localhost:6379")
	viper.SetDefault("WITHDRAWAL_CODE_PEPPER", "dev-withdrawal-pepper")
	viper.SetDefault("WITHDRAWAL_DATA_KEY", "dev-withdrawal-encryption-key")
	viper.SetDefault("THE_ODDS_SYNC_INTERVAL", "30m")
	viper.SetDefault("OPENLIGADB_LEAGUES", "bl1")
	viper.SetDefault("OPENLIGADB_SEASON", 2026)
	viper.SetDefault("OPENLIGADB_SYNC_INTERVAL", "6h")

	envPaths := []string{".env", "../../.env", "../../../.env"}
	var readErr error
	for _, p := range envPaths {
		viper.SetConfigFile(p)
		readErr = viper.ReadInConfig()
		if readErr == nil {
			break
		}
	}

	if readErr != nil {
		if !strings.Contains(readErr.Error(), "no such file") && !strings.Contains(readErr.Error(), "The system cannot find the file specified") {
			fmt.Printf("Warning: could not read config file: %v\n", readErr)
		}
	}

	cfg := &Config{
		Server: ServerConfig{
			Port: viper.GetString("PORT"),
		},
		Database: DatabaseConfig{
			URL: viper.GetString("DATABASE_URL"),
		},
		Redis: RedisConfig{
			URL: viper.GetString("REDIS_URL"),
		},
		JWT: JWTConfig{
			Secret:        viper.GetString("JWT_SECRET"),
			Expiry:        viper.GetString("JWT_EXPIRY"),
			RefreshExpiry: viper.GetString("REFRESH_EXPIRY"),
		},
		App: AppConfig{
			Env: viper.GetString("ENV"),
		},
		Security: SecurityConfig{
			WithdrawalCodePepper: viper.GetString("WITHDRAWAL_CODE_PEPPER"),
			WithdrawalDataKey:    viper.GetString("WITHDRAWAL_DATA_KEY"),
		},
		Sportmonks: SportmonksConfig{
			Token: viper.GetString("SPORTMONKS_API_TOKEN"),
		},
		TheOddsAPI: TheOddsAPIConfig{
			Key:          firstNonEmpty(viper.GetString("THE_ODDS_API_KEY"), viper.GetString("ODDS_API_KEY")),
			SyncInterval: viper.GetString("THE_ODDS_SYNC_INTERVAL"),
		},
		OpenLigaDB: OpenLigaDBConfig{
			Leagues:      viper.GetString("OPENLIGADB_LEAGUES"),
			Season:       viper.GetInt("OPENLIGADB_SEASON"),
			SyncInterval: viper.GetString("OPENLIGADB_SYNC_INTERVAL"),
		},
	}

	return cfg, nil
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
