package config

import (
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
)

// Config holds all application configuration
type Config struct {
	// MongoDB Configuration
	MongoDBURL    string
	MongoDBName   string

	// AWS S3 Configuration
	AWSAccessKeyID     string
	AWSSecretAccessKey string
	AWSRegion          string
	S3BucketName       string

	// Transcription Configuration
	OpenAIAPIKey      string
	WhisperServiceURL string

	// Application Configuration
	AppHost  string
	AppPort  string
	LogLevel string

	// CORS Configuration
	CORSOrigins []string
}

// Load loads configuration from environment variables
func Load() *Config {
	// Load .env file if it exists (ignore error in production)
	_ = godotenv.Load()

	corsOrigins := os.Getenv("CORS_ORIGINS")
	if corsOrigins == "" {
		corsOrigins = "http://localhost:3000"
	}

	config := &Config{
		MongoDBURL:         getEnv("MONGODB_URL", "mongodb://localhost:27017"),
		MongoDBName:        getEnv("MONGODB_DB_NAME", "podcast_db"),
		AWSAccessKeyID:     getEnv("AWS_ACCESS_KEY_ID", ""),
		AWSSecretAccessKey: getEnv("AWS_SECRET_ACCESS_KEY", ""),
		AWSRegion:          getEnv("AWS_DEFAULT_REGION", "us-east-1"),
		S3BucketName:       getEnv("S3_BUCKET_NAME", "podcast-audio"),
		OpenAIAPIKey:       getEnv("OPENAI_API_KEY", ""),
		WhisperServiceURL:  getEnv("WHISPER_SERVICE_URL", "http://localhost:9000"),
		AppHost:            getEnv("APP_HOST", "0.0.0.0"),
		AppPort:            getEnv("APP_PORT", "8000"),
		LogLevel:           getEnv("LOG_LEVEL", "info"),
		CORSOrigins:        parseOrigins(corsOrigins),
	}

	log.Printf("Configuration loaded: MongoDB=%s, WhisperURL=%s", config.MongoDBURL, config.WhisperServiceURL)
	return config
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

func parseOrigins(origins string) []string {
	parts := strings.Split(origins, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}
