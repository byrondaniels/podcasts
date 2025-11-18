package services

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// WhisperService handles communication with the Whisper transcription service
type WhisperService struct {
	baseURL string
	client  *http.Client
}

// NewWhisperService creates a new Whisper service client
func NewWhisperService(baseURL string) *WhisperService {
	return &WhisperService{
		baseURL: baseURL,
		client: &http.Client{
			Timeout: time.Hour, // 1 hour timeout for long transcriptions
		},
	}
}

// TranscribeAudioURL downloads audio from URL and transcribes it
func (w *WhisperService) TranscribeAudioURL(audioURL string) (string, error) {
	// Download audio file
	tempFile, err := w.downloadAudio(audioURL)
	if err != nil {
		return "", fmt.Errorf("failed to download audio: %w", err)
	}
	defer os.Remove(tempFile) // Clean up temp file

	// Transcribe the file
	return w.TranscribeAudioFile(tempFile)
}

// TranscribeAudioFile transcribes a local audio file
func (w *WhisperService) TranscribeAudioFile(filePath string) (string, error) {
	log.Printf("Transcribing audio file: %s", filePath)

	// Open the file
	file, err := os.Open(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	// Create multipart form
	var requestBody bytes.Buffer
	writer := multipart.NewWriter(&requestBody)

	// Add file field
	part, err := writer.CreateFormFile("audio_file", filepath.Base(filePath))
	if err != nil {
		return "", fmt.Errorf("failed to create form file: %w", err)
	}

	if _, err := io.Copy(part, file); err != nil {
		return "", fmt.Errorf("failed to copy file data: %w", err)
	}

	// Add other fields
	_ = writer.WriteField("task", "transcribe")
	_ = writer.WriteField("language", "en")
	_ = writer.WriteField("output", "txt")

	if err := writer.Close(); err != nil {
		return "", fmt.Errorf("failed to close writer: %w", err)
	}

	// Send request
	url := fmt.Sprintf("%s/asr", w.baseURL)
	req, err := http.NewRequest("POST", url, &requestBody)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", writer.FormDataContentType())

	resp, err := w.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("whisper service returned status %d: %s", resp.StatusCode, string(body))
	}

	// Read transcript
	transcript, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	log.Printf("Successfully transcribed %s", filepath.Base(filePath))
	return string(transcript), nil
}

// downloadAudio downloads audio from URL to a temporary file
func (w *WhisperService) downloadAudio(url string) (string, error) {
	log.Printf("Downloading audio from: %s", url)

	resp, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to download: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("download failed with status: %d", resp.StatusCode)
	}

	// Create temp file
	tempFile, err := os.CreateTemp("", "podcast-*.mp3")
	if err != nil {
		return "", fmt.Errorf("failed to create temp file: %w", err)
	}
	defer tempFile.Close()

	// Copy data
	if _, err := io.Copy(tempFile, resp.Body); err != nil {
		os.Remove(tempFile.Name())
		return "", fmt.Errorf("failed to save file: %w", err)
	}

	log.Printf("Audio downloaded to: %s", tempFile.Name())
	return tempFile.Name(), nil
}

// HealthCheck checks if the Whisper service is available
func (w *WhisperService) HealthCheck() bool {
	url := fmt.Sprintf("%s/health", w.baseURL)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		log.Printf("Whisper service health check failed: %v", err)
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK
}
