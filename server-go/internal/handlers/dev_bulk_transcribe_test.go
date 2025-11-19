package handlers

import (
	"testing"

	"github.com/byrondaniels/podcasts/server-go/internal/services"
)

func TestNewBulkTranscribeHandler(t *testing.T) {
	whisper := services.NewWhisperService("http://localhost:9000")
	bulkService := services.NewBulkTranscribeService(nil, whisper)
	handler := NewBulkTranscribeHandler(bulkService)

	if handler == nil {
		t.Fatal("NewBulkTranscribeHandler() returned nil")
	}
	if handler.service == nil {
		t.Error("handler.service is nil")
	}
}
