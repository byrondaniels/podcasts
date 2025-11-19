package main

import (
	"testing"
)

func TestFormatTimestamp(t *testing.T) {
	tests := []struct {
		name     string
		seconds  int
		expected string
	}{
		{
			name:     "zero seconds",
			seconds:  0,
			expected: "[00:00:00]",
		},
		{
			name:     "one minute",
			seconds:  60,
			expected: "[00:01:00]",
		},
		{
			name:     "one hour",
			seconds:  3600,
			expected: "[01:00:00]",
		},
		{
			name:     "complex time",
			seconds:  3661,
			expected: "[01:01:01]",
		},
		{
			name:     "five minutes",
			seconds:  300,
			expected: "[00:05:00]",
		},
		{
			name:     "one hour thirty minutes",
			seconds:  5400,
			expected: "[01:30:00]",
		},
		{
			name:     "two hours fifteen minutes thirty seconds",
			seconds:  8130,
			expected: "[02:15:30]",
		},
		{
			name:     "large value",
			seconds:  36000,
			expected: "[10:00:00]",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := formatTimestamp(tt.seconds)
			if result != tt.expected {
				t.Errorf("formatTimestamp(%d) = %v, want %v", tt.seconds, result, tt.expected)
			}
		})
	}
}

func TestHandleRequestValidation(t *testing.T) {
	tests := []struct {
		name          string
		event         LambdaEvent
		expectedError string
	}{
		{
			name: "missing episode_id",
			event: LambdaEvent{
				EpisodeID:   "",
				Transcripts: []TranscriptChunk{{ChunkIndex: 0}},
				S3Bucket:    "test-bucket",
			},
			expectedError: "Missing required parameter: episode_id",
		},
		{
			name: "no transcripts",
			event: LambdaEvent{
				EpisodeID:   "test-123",
				Transcripts: []TranscriptChunk{},
				S3Bucket:    "test-bucket",
			},
			expectedError: "No transcripts provided",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mongoClient = nil
			s3Client = nil

			result, _ := HandleRequest(nil, tt.event)

			if result.Status != "error" {
				t.Errorf("Expected status 'error', got '%s'", result.Status)
			}
			if result.ErrorMessage != tt.expectedError {
				t.Errorf("Expected error message '%s', got '%s'", tt.expectedError, result.ErrorMessage)
			}
		})
	}
}

func TestHandleRequestMissingChunks(t *testing.T) {
	mongoClient = nil
	s3Client = nil

	event := LambdaEvent{
		EpisodeID: "test-123",
		Transcripts: []TranscriptChunk{
			{ChunkIndex: 0, TranscriptS3Key: "key0"},
			{ChunkIndex: 2, TranscriptS3Key: "key2"},
		},
		S3Bucket: "test-bucket",
	}

	result, _ := HandleRequest(nil, event)

	if result.Status != "error" {
		t.Errorf("Expected status 'error', got '%s'", result.Status)
	}
	if result.ErrorMessage != "Missing chunk at index: 1" {
		t.Errorf("Expected missing chunk error, got '%s'", result.ErrorMessage)
	}
}
