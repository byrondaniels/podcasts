package services

import (
	"strings"
	"testing"
	"time"
)

func TestGenerateJobID(t *testing.T) {
	jobID1 := generateJobID()
	jobID2 := generateJobID()

	if jobID1 == "" {
		t.Error("generateJobID() returned empty string")
	}
	if !strings.HasPrefix(jobID1, "job_") {
		t.Error("generateJobID() should return ID with 'job_' prefix")
	}
	if jobID1 == jobID2 {
		t.Error("generateJobID() should generate unique IDs")
	}
	if len(jobID1) < 5 {
		t.Error("generateJobID() returned ID that is too short")
	}
}

func TestNewBulkTranscribeService(t *testing.T) {
	whisper := NewWhisperService("http://localhost:9000")
	service := NewBulkTranscribeService(nil, whisper)

	if service == nil {
		t.Fatal("NewBulkTranscribeService() returned nil")
	}
	if service.whisper == nil {
		t.Error("whisper service is nil")
	}
	if service.rssParser == nil {
		t.Error("rssParser is nil")
	}
	if service.runningJobs == nil {
		t.Error("runningJobs map is nil")
	}
}

func TestCancelJob(t *testing.T) {
	service := &BulkTranscribeService{
		runningJobs: make(map[string]bool),
	}

	jobID := "test-job-123"

	cancelled := service.CancelJob(jobID)
	if cancelled {
		t.Error("CancelJob() should return false for non-existent job")
	}

	service.runningJobs[jobID] = true
	cancelled = service.CancelJob(jobID)
	if !cancelled {
		t.Error("CancelJob() should return true for existing job")
	}

	if service.runningJobs[jobID] {
		t.Error("CancelJob() should remove job from runningJobs map")
	}
}

func TestSortEpisodesByDateEdgeCases(t *testing.T) {
	tests := []struct {
		name  string
		input []EpisodeData
	}{
		{
			name:  "empty slice",
			input: []EpisodeData{},
		},
		{
			name: "single episode",
			input: []EpisodeData{
				{Title: "Episode 1", PublishedDate: nil},
			},
		},
		{
			name: "all nil dates",
			input: []EpisodeData{
				{Title: "Episode 1", PublishedDate: nil},
				{Title: "Episode 2", PublishedDate: nil},
				{Title: "Episode 3", PublishedDate: nil},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			episodes := make([]EpisodeData, len(tt.input))
			copy(episodes, tt.input)
			sortEpisodesByDate(episodes)
		})
	}
}

func TestSortEpisodesByDateWithMixedNilDates(t *testing.T) {
	time1 := time.Date(2023, 1, 1, 0, 0, 0, 0, time.UTC)
	time2 := time.Date(2023, 2, 1, 0, 0, 0, 0, time.UTC)

	episodes := []EpisodeData{
		{Title: "Episode 2", PublishedDate: &time2},
		{Title: "Episode Nil", PublishedDate: nil},
		{Title: "Episode 1", PublishedDate: &time1},
	}

	sortEpisodesByDate(episodes)

	for i := 0; i < len(episodes)-1; i++ {
		if episodes[i].PublishedDate != nil && episodes[i+1].PublishedDate != nil {
			if episodes[i].PublishedDate.After(*episodes[i+1].PublishedDate) {
				t.Errorf("Episodes not sorted correctly: %v comes after %v",
					episodes[i].PublishedDate, episodes[i+1].PublishedDate)
			}
		}
	}
}
