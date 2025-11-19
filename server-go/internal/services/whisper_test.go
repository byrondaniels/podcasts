package services

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestNewWhisperService(t *testing.T) {
	baseURL := "http://localhost:9000"
	service := NewWhisperService(baseURL)

	if service == nil {
		t.Fatal("NewWhisperService() returned nil")
	}
	if service.baseURL != baseURL {
		t.Errorf("baseURL = %v, want %v", service.baseURL, baseURL)
	}
	if service.client == nil {
		t.Error("client is nil")
	}
}

func TestHealthCheck(t *testing.T) {
	tests := []struct {
		name           string
		statusCode     int
		expectedResult bool
	}{
		{
			name:           "healthy service",
			statusCode:     http.StatusOK,
			expectedResult: true,
		},
		{
			name:           "unhealthy service",
			statusCode:     http.StatusInternalServerError,
			expectedResult: false,
		},
		{
			name:           "service not found",
			statusCode:     http.StatusNotFound,
			expectedResult: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path != "/health" {
					t.Errorf("Expected path /health, got %s", r.URL.Path)
				}
				w.WriteHeader(tt.statusCode)
			}))
			defer server.Close()

			service := NewWhisperService(server.URL)
			result := service.HealthCheck()

			if result != tt.expectedResult {
				t.Errorf("HealthCheck() = %v, want %v", result, tt.expectedResult)
			}
		})
	}
}

func TestHealthCheckNetworkError(t *testing.T) {
	service := NewWhisperService("http://invalid-host-that-does-not-exist:9999")
	result := service.HealthCheck()

	if result != false {
		t.Error("HealthCheck() should return false for network errors")
	}
}

func TestTranscribeAudioFile(t *testing.T) {
	tests := []struct {
		name           string
		statusCode     int
		responseBody   string
		expectError    bool
		expectedResult string
	}{
		{
			name:           "successful transcription",
			statusCode:     http.StatusOK,
			responseBody:   "This is the transcribed text",
			expectError:    false,
			expectedResult: "This is the transcribed text",
		},
		{
			name:         "service returns error",
			statusCode:   http.StatusInternalServerError,
			responseBody: "Internal server error",
			expectError:  true,
		},
		{
			name:         "service returns bad request",
			statusCode:   http.StatusBadRequest,
			responseBody: "Bad request",
			expectError:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.URL.Path != "/asr" {
					t.Errorf("Expected path /asr, got %s", r.URL.Path)
				}
				if r.Method != "POST" {
					t.Errorf("Expected POST method, got %s", r.Method)
				}
				w.WriteHeader(tt.statusCode)
				w.Write([]byte(tt.responseBody))
			}))
			defer server.Close()

			tmpFile, err := os.CreateTemp("", "test-audio-*.mp3")
			if err != nil {
				t.Fatalf("Failed to create temp file: %v", err)
			}
			tmpFile.Write([]byte("fake audio data"))
			tmpFile.Close()
			defer os.Remove(tmpFile.Name())

			service := NewWhisperService(server.URL)
			result, err := service.TranscribeAudioFile(tmpFile.Name())

			if tt.expectError {
				if err == nil {
					t.Error("Expected error but got none")
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error: %v", err)
				}
				if result != tt.expectedResult {
					t.Errorf("TranscribeAudioFile() = %v, want %v", result, tt.expectedResult)
				}
			}
		})
	}
}

func TestTranscribeAudioFileInvalidPath(t *testing.T) {
	service := NewWhisperService("http://localhost:9000")
	_, err := service.TranscribeAudioFile("/nonexistent/file.mp3")

	if err == nil {
		t.Error("Expected error for nonexistent file")
	}
}

func TestTranscribeAudioURL(t *testing.T) {
	audioContent := []byte("fake audio content")

	audioServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "audio/mpeg")
		w.WriteHeader(http.StatusOK)
		w.Write(audioContent)
	}))
	defer audioServer.Close()

	whisperServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("Transcription result"))
	}))
	defer whisperServer.Close()

	service := NewWhisperService(whisperServer.URL)
	result, err := service.TranscribeAudioURL(audioServer.URL)

	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
	if result != "Transcription result" {
		t.Errorf("TranscribeAudioURL() = %v, want 'Transcription result'", result)
	}
}

func TestTranscribeAudioURLDownloadFailure(t *testing.T) {
	service := NewWhisperService("http://localhost:9000")
	_, err := service.TranscribeAudioURL("http://invalid-host-does-not-exist:9999/audio.mp3")

	if err == nil {
		t.Error("Expected error for failed download")
	}
}

func TestDownloadAudio(t *testing.T) {
	tests := []struct {
		name        string
		statusCode  int
		expectError bool
	}{
		{
			name:        "successful download",
			statusCode:  http.StatusOK,
			expectError: false,
		},
		{
			name:        "not found",
			statusCode:  http.StatusNotFound,
			expectError: true,
		},
		{
			name:        "internal server error",
			statusCode:  http.StatusInternalServerError,
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(tt.statusCode)
				if tt.statusCode == http.StatusOK {
					w.Write([]byte("audio data"))
				}
			}))
			defer server.Close()

			service := NewWhisperService("http://localhost:9000")
			filePath, err := service.downloadAudio(server.URL)

			if tt.expectError {
				if err == nil {
					t.Error("Expected error but got none")
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error: %v", err)
				}
				if filePath == "" {
					t.Error("Expected file path but got empty string")
				}
				defer os.Remove(filePath)

				if _, statErr := os.Stat(filePath); statErr != nil {
					t.Errorf("Downloaded file does not exist: %v", statErr)
				}
			}
		})
	}
}
