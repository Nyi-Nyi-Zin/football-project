package config

import (
	"fmt"
	"strings"

	"github.com/spf13/viper"
)

// Config holds all application configuration
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Redis    RedisConfig
	JWT      JWTConfig
	App      AppConfig
	Sportmonks SportmonksConfig
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

type SportmonksConfig struct {
	Token string `mapstructure:"SPORTMONKS_API_TOKEN"`
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
		Sportmonks: SportmonksConfig{
			Token: viper.GetString("SPORTMONKS_API_TOKEN"),
		},
	}

	return cfg, nil
}
