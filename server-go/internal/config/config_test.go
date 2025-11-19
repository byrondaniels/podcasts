package config

import (
	"os"
	"testing"
)

func TestGetEnv(t *testing.T) {
	tests := []struct {
		name         string
		key          string
		defaultValue string
		envValue     string
		expected     string
	}{
		{
			name:         "returns environment variable when set",
			key:          "TEST_KEY",
			defaultValue: "default",
			envValue:     "custom",
			expected:     "custom",
		},
		{
			name:         "returns default when env var not set",
			key:          "NONEXISTENT_KEY",
			defaultValue: "default",
			envValue:     "",
			expected:     "default",
		},
		{
			name:         "returns empty string when env var is empty",
			key:          "EMPTY_KEY",
			defaultValue: "default",
			envValue:     "",
			expected:     "default",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.envValue != "" {
				os.Setenv(tt.key, tt.envValue)
				defer os.Unsetenv(tt.key)
			}

			result := getEnv(tt.key, tt.defaultValue)
			if result != tt.expected {
				t.Errorf("getEnv() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestParseOrigins(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected []string
	}{
		{
			name:     "single origin",
			input:    "http://localhost:3000",
			expected: []string{"http://localhost:3000"},
		},
		{
			name:     "multiple origins",
			input:    "http://localhost:3000,https://example.com",
			expected: []string{"http://localhost:3000", "https://example.com"},
		},
		{
			name:     "origins with spaces",
			input:    "http://localhost:3000, https://example.com , https://test.com",
			expected: []string{"http://localhost:3000", "https://example.com", "https://test.com"},
		},
		{
			name:     "empty string",
			input:    "",
			expected: []string{},
		},
		{
			name:     "only commas",
			input:    ",,,",
			expected: []string{},
		},
		{
			name:     "trailing comma",
			input:    "http://localhost:3000,",
			expected: []string{"http://localhost:3000"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parseOrigins(tt.input)
			if len(result) != len(tt.expected) {
				t.Errorf("parseOrigins() length = %v, want %v", len(result), len(tt.expected))
				return
			}
			for i := range result {
				if result[i] != tt.expected[i] {
					t.Errorf("parseOrigins()[%d] = %v, want %v", i, result[i], tt.expected[i])
				}
			}
		})
	}
}

func TestLoad(t *testing.T) {
	tests := []struct {
		name        string
		envVars     map[string]string
		checkFields func(*testing.T, *Config)
	}{
		{
			name:    "loads default values when no env vars set",
			envVars: map[string]string{},
			checkFields: func(t *testing.T, c *Config) {
				if c.MongoDBURL != "mongodb://localhost:27017" {
					t.Errorf("MongoDBURL = %v, want mongodb://localhost:27017", c.MongoDBURL)
				}
				if c.AppPort != "8000" {
					t.Errorf("AppPort = %v, want 8000", c.AppPort)
				}
			},
		},
		{
			name: "loads custom values from env vars",
			envVars: map[string]string{
				"MONGODB_URL":  "mongodb://custom:27017",
				"APP_PORT":     "9000",
				"CORS_ORIGINS": "http://example.com,https://test.com",
			},
			checkFields: func(t *testing.T, c *Config) {
				if c.MongoDBURL != "mongodb://custom:27017" {
					t.Errorf("MongoDBURL = %v, want mongodb://custom:27017", c.MongoDBURL)
				}
				if c.AppPort != "9000" {
					t.Errorf("AppPort = %v, want 9000", c.AppPort)
				}
				if len(c.CORSOrigins) != 2 {
					t.Errorf("CORSOrigins length = %v, want 2", len(c.CORSOrigins))
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			for k, v := range tt.envVars {
				os.Setenv(k, v)
			}
			defer func() {
				for k := range tt.envVars {
					os.Unsetenv(k)
				}
			}()

			config := Load()
			if config == nil {
				t.Fatal("Load() returned nil")
			}
			tt.checkFields(t, config)
		})
	}
}
