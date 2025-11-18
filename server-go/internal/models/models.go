package models

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// TranscriptStatus represents the status of a transcript
type TranscriptStatus string

const (
	StatusPending    TranscriptStatus = "pending"
	StatusProcessing TranscriptStatus = "processing"
	StatusCompleted  TranscriptStatus = "completed"
	StatusFailed     TranscriptStatus = "failed"
)

// BulkJobStatus represents the status of a bulk transcription job
type BulkJobStatus string

const (
	JobStatusPending   BulkJobStatus = "pending"
	JobStatusRunning   BulkJobStatus = "running"
	JobStatusPaused    BulkJobStatus = "paused"
	JobStatusCompleted BulkJobStatus = "completed"
	JobStatusFailed    BulkJobStatus = "failed"
	JobStatusCancelled BulkJobStatus = "cancelled"
)

// Podcast represents a podcast subscription
type Podcast struct {
	ID           primitive.ObjectID `json:"-" bson:"_id,omitempty"`
	PodcastID    string             `json:"podcast_id" bson:"podcast_id"`
	RSSURL       string             `json:"rss_url" bson:"rss_url"`
	Title        string             `json:"title" bson:"title"`
	Description  string             `json:"description,omitempty" bson:"description,omitempty"`
	ImageURL     string             `json:"image_url,omitempty" bson:"image_url,omitempty"`
	Author       string             `json:"author,omitempty" bson:"author,omitempty"`
	WebsiteURL   string             `json:"website_url,omitempty" bson:"website_url,omitempty"`
	Language     string             `json:"language,omitempty" bson:"language,omitempty"`
	SubscribedAt time.Time          `json:"subscribed_at" bson:"subscribed_at"`
	LastPolledAt *time.Time         `json:"last_polled_at,omitempty" bson:"last_polled_at,omitempty"`
	Active       bool               `json:"active" bson:"active"`
}

// Episode represents a podcast episode
type Episode struct {
	ID                 primitive.ObjectID `json:"-" bson:"_id,omitempty"`
	EpisodeID          string             `json:"episode_id" bson:"episode_id"`
	PodcastID          string             `json:"podcast_id" bson:"podcast_id"`
	Title              string             `json:"title" bson:"title"`
	Description        string             `json:"description,omitempty" bson:"description,omitempty"`
	AudioURL           string             `json:"audio_url,omitempty" bson:"audio_url,omitempty"`
	PublishedDate      *time.Time         `json:"published_date,omitempty" bson:"published_date,omitempty"`
	DurationMinutes    *int               `json:"duration_minutes,omitempty" bson:"duration_minutes,omitempty"`
	FileSizeMB         *float64           `json:"file_size_mb,omitempty" bson:"file_size_mb,omitempty"`
	S3AudioKey         string             `json:"s3_audio_key,omitempty" bson:"s3_audio_key,omitempty"`
	TranscriptStatus   TranscriptStatus   `json:"transcript_status" bson:"transcript_status"`
	TranscriptS3Key    string             `json:"transcript_s3_key,omitempty" bson:"transcript_s3_key,omitempty"`
	TranscriptWordCount *int              `json:"transcript_word_count,omitempty" bson:"transcript_word_count,omitempty"`
	DiscoveredAt       time.Time          `json:"discovered_at" bson:"discovered_at"`
	ProcessedAt        *time.Time         `json:"processed_at,omitempty" bson:"processed_at,omitempty"`
	ErrorMessage       string             `json:"error_message,omitempty" bson:"error_message,omitempty"`
}

// BulkTranscribeEpisodeProgress represents progress of a single episode in a bulk job
type BulkTranscribeEpisodeProgress struct {
	EpisodeID    string           `json:"episode_id" bson:"episode_id"`
	Title        string           `json:"title" bson:"title"`
	AudioURL     string           `json:"audio_url" bson:"audio_url"`
	Status       TranscriptStatus `json:"status" bson:"status"`
	ErrorMessage string           `json:"error_message,omitempty" bson:"error_message,omitempty"`
	StartedAt    *time.Time       `json:"started_at,omitempty" bson:"started_at,omitempty"`
	CompletedAt  *time.Time       `json:"completed_at,omitempty" bson:"completed_at,omitempty"`
}

// BulkTranscribeJob represents a bulk transcription job
type BulkTranscribeJob struct {
	ID                  primitive.ObjectID              `json:"-" bson:"_id,omitempty"`
	JobID               string                          `json:"job_id" bson:"job_id"`
	RSSURL              string                          `json:"rss_url" bson:"rss_url"`
	PodcastTitle        string                          `json:"podcast_title,omitempty" bson:"podcast_title,omitempty"`
	Status              BulkJobStatus                   `json:"status" bson:"status"`
	TotalEpisodes       int                             `json:"total_episodes" bson:"total_episodes"`
	ProcessedEpisodes   int                             `json:"processed_episodes" bson:"processed_episodes"`
	SuccessfulEpisodes  int                             `json:"successful_episodes" bson:"successful_episodes"`
	FailedEpisodes      int                             `json:"failed_episodes" bson:"failed_episodes"`
	CreatedAt           time.Time                       `json:"created_at" bson:"created_at"`
	UpdatedAt           time.Time                       `json:"updated_at" bson:"updated_at"`
	CompletedAt         *time.Time                      `json:"completed_at,omitempty" bson:"completed_at,omitempty"`
	CurrentEpisode      string                          `json:"current_episode,omitempty" bson:"current_episode,omitempty"`
	Episodes            []BulkTranscribeEpisodeProgress `json:"episodes,omitempty" bson:"episodes,omitempty"`
}

// Request/Response DTOs

// SubscribePodcastRequest is the request to subscribe to a podcast
type SubscribePodcastRequest struct {
	RSSURL string `json:"rss_url" binding:"required,url"`
}

// BulkTranscribeRequest is the request to start bulk transcription
type BulkTranscribeRequest struct {
	RSSURL      string `json:"rss_url" binding:"required,url"`
	MaxEpisodes *int   `json:"max_episodes,omitempty" binding:"omitempty,min=1"`
}

// EpisodeListResponse is the response for episode listing
type EpisodeListResponse struct {
	Episodes []Episode `json:"episodes"`
	Total    int       `json:"total"`
	Page     int       `json:"page"`
	Limit    int       `json:"limit"`
	HasMore  bool      `json:"has_more"`
}

// PodcastListResponse is the response for podcast listing
type PodcastListResponse struct {
	Podcasts []Podcast `json:"podcasts"`
	Total    int       `json:"total"`
}

// TranscriptResponse is the response for getting a transcript
type TranscriptResponse struct {
	EpisodeID   string           `json:"episode_id"`
	Transcript  string           `json:"transcript"`
	Status      TranscriptStatus `json:"status"`
	GeneratedAt *time.Time       `json:"generated_at,omitempty"`
}

// BulkTranscribeJobListResponse is the response for listing bulk jobs
type BulkTranscribeJobListResponse struct {
	Jobs  []BulkTranscribeJob `json:"jobs"`
	Total int                 `json:"total"`
}

// ErrorResponse is a standard error response
type ErrorResponse struct {
	Error  string `json:"error"`
	Detail string `json:"detail,omitempty"`
}

// SuccessResponse is a generic success response
type SuccessResponse struct {
	Message string                 `json:"message"`
	Data    map[string]interface{} `json:"data,omitempty"`
}
