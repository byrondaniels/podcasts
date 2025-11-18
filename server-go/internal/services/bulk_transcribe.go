package services

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/byrondaniels/podcasts/server-go/internal/database"
	"github.com/byrondaniels/podcasts/server-go/internal/models"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// BulkTranscribeService manages bulk transcription jobs
type BulkTranscribeService struct {
	db            *database.MongoDB
	whisper       *WhisperService
	rssParser     *RSSParser
	runningJobs   map[string]bool
	runningJobsMu sync.RWMutex
}

// NewBulkTranscribeService creates a new bulk transcription service
func NewBulkTranscribeService(db *database.MongoDB, whisper *WhisperService) *BulkTranscribeService {
	return &BulkTranscribeService{
		db:          db,
		whisper:     whisper,
		rssParser:   NewRSSParser(),
		runningJobs: make(map[string]bool),
	}
}

// CreateJob creates a new bulk transcription job
func (s *BulkTranscribeService) CreateJob(ctx context.Context, rssURL string, maxEpisodes *int) (*models.BulkTranscribeJob, error) {
	log.Printf("Creating bulk transcribe job for: %s", rssURL)

	// Parse RSS feed
	podcastData, episodes, err := s.rssParser.ParseFeed(rssURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse RSS feed: %w", err)
	}

	if len(episodes) == 0 {
		return nil, fmt.Errorf("no episodes found in RSS feed")
	}

	// Sort episodes by published date (oldest first for chronological processing)
	sortEpisodesByDate(episodes)

	// Limit episodes if specified
	if maxEpisodes != nil && *maxEpisodes > 0 && *maxEpisodes < len(episodes) {
		episodes = episodes[:*maxEpisodes]
	}

	// Create job
	jobID := generateJobID()
	now := time.Now()

	episodeProgress := make([]models.BulkTranscribeEpisodeProgress, len(episodes))
	for i, ep := range episodes {
		episodeProgress[i] = models.BulkTranscribeEpisodeProgress{
			EpisodeID: "", // Will be set when episode is created
			Title:     ep.Title,
			AudioURL:  ep.AudioURL,
			Status:    models.StatusPending,
		}
	}

	job := &models.BulkTranscribeJob{
		JobID:              jobID,
		RSSURL:             rssURL,
		PodcastTitle:       podcastData.Title,
		Status:             models.JobStatusPending,
		TotalEpisodes:      len(episodes),
		ProcessedEpisodes:  0,
		SuccessfulEpisodes: 0,
		FailedEpisodes:     0,
		CreatedAt:          now,
		UpdatedAt:          now,
		Episodes:           episodeProgress,
	}

	// Insert job
	_, err = s.db.BulkTranscribeJobs().InsertOne(ctx, job)
	if err != nil {
		return nil, fmt.Errorf("failed to insert job: %w", err)
	}

	log.Printf("Created job %s with %d episodes", jobID, len(episodes))
	return job, nil
}

// GetJob retrieves a job by ID
func (s *BulkTranscribeService) GetJob(ctx context.Context, jobID string) (*models.BulkTranscribeJob, error) {
	var job models.BulkTranscribeJob
	err := s.db.BulkTranscribeJobs().FindOne(ctx, bson.M{"job_id": jobID}).Decode(&job)
	if err != nil {
		return nil, err
	}
	return &job, nil
}

// ListJobs lists all jobs, most recent first
func (s *BulkTranscribeService) ListJobs(ctx context.Context, limit int) ([]models.BulkTranscribeJob, error) {
	opts := options.Find().
		SetSort(bson.D{{Key: "created_at", Value: -1}}).
		SetLimit(int64(limit))

	cursor, err := s.db.BulkTranscribeJobs().Find(ctx, bson.M{}, opts)
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)

	var jobs []models.BulkTranscribeJob
	if err := cursor.All(ctx, &jobs); err != nil {
		return nil, err
	}

	return jobs, nil
}

// UpdateJob updates job fields
func (s *BulkTranscribeService) UpdateJob(ctx context.Context, jobID string, updates bson.M) error {
	updates["updated_at"] = time.Now()
	_, err := s.db.BulkTranscribeJobs().UpdateOne(
		ctx,
		bson.M{"job_id": jobID},
		bson.M{"$set": updates},
	)
	return err
}

// UpdateEpisodeInJob updates a specific episode in a job
func (s *BulkTranscribeService) UpdateEpisodeInJob(ctx context.Context, jobID string, episodeIndex int, updates bson.M) error {
	setUpdates := bson.M{"updated_at": time.Now()}
	for key, value := range updates {
		setUpdates[fmt.Sprintf("episodes.%d.%s", episodeIndex, key)] = value
	}

	_, err := s.db.BulkTranscribeJobs().UpdateOne(
		ctx,
		bson.M{"job_id": jobID},
		bson.M{"$set": setUpdates},
	)
	return err
}

// ProcessJob processes a bulk transcription job
func (s *BulkTranscribeService) ProcessJob(jobID string) {
	// Mark job as running
	s.runningJobsMu.Lock()
	s.runningJobs[jobID] = true
	s.runningJobsMu.Unlock()

	defer func() {
		s.runningJobsMu.Lock()
		delete(s.runningJobs, jobID)
		s.runningJobsMu.Unlock()
	}()

	ctx := context.Background()
	log.Printf("Starting to process job %s", jobID)

	// Update job status to running
	if err := s.UpdateJob(ctx, jobID, bson.M{"status": models.JobStatusRunning}); err != nil {
		log.Printf("Error updating job status: %v", err)
		return
	}

	// Get job
	job, err := s.GetJob(ctx, jobID)
	if err != nil {
		log.Printf("Error getting job %s: %v", jobID, err)
		return
	}

	// Process each episode
	for idx, episode := range job.Episodes {
		// Check if job was cancelled
		s.runningJobsMu.RLock()
		isRunning := s.runningJobs[jobID]
		s.runningJobsMu.RUnlock()

		if !isRunning {
			log.Printf("Job %s was cancelled", jobID)
			s.UpdateJob(ctx, jobID, bson.M{"status": models.JobStatusCancelled})
			return
		}

		// Update current episode
		s.UpdateJob(ctx, jobID, bson.M{"current_episode": episode.Title})

		// Update episode status to processing
		now := time.Now()
		s.UpdateEpisodeInJob(ctx, jobID, idx, bson.M{
			"status":     models.StatusProcessing,
			"started_at": now,
		})

		log.Printf("Processing episode %d/%d: %s", idx+1, len(job.Episodes), episode.Title)

		// Transcribe using Whisper
		var episodeStatus models.TranscriptStatus
		var errorMsg string

		if episode.AudioURL == "" {
			errorMsg = "No audio URL found for episode"
			episodeStatus = models.StatusFailed
		} else {
			transcript, err := s.whisper.TranscribeAudioURL(episode.AudioURL)
			if err != nil {
				log.Printf("Error transcribing episode %d: %v", idx+1, err)
				errorMsg = err.Error()
				episodeStatus = models.StatusFailed
			} else if transcript == "" {
				errorMsg = "Transcription returned empty result"
				episodeStatus = models.StatusFailed
			} else {
				episodeStatus = models.StatusCompleted
				log.Printf("Successfully transcribed episode %d", idx+1)
				// TODO: Store transcript to S3 or database
			}
		}

		// Update episode in job
		completedAt := time.Now()
		episodeUpdate := bson.M{
			"status":       episodeStatus,
			"completed_at": completedAt,
		}
		if errorMsg != "" {
			episodeUpdate["error_message"] = errorMsg
		}
		s.UpdateEpisodeInJob(ctx, jobID, idx, episodeUpdate)

		// Update job counters
		jobUpdate := bson.M{
			"processed_episodes": idx + 1,
		}
		if episodeStatus == models.StatusCompleted {
			jobUpdate["successful_episodes"] = job.SuccessfulEpisodes + 1
		} else {
			jobUpdate["failed_episodes"] = job.FailedEpisodes + 1
		}
		s.UpdateJob(ctx, jobID, jobUpdate)

		// Refresh job data
		job, _ = s.GetJob(ctx, jobID)

		// Small delay between episodes
		time.Sleep(2 * time.Second)
	}

	// Mark job as completed
	completedAt := time.Now()
	s.UpdateJob(ctx, jobID, bson.M{
		"status":          models.JobStatusCompleted,
		"current_episode": "",
		"completed_at":    completedAt,
	})

	job, _ = s.GetJob(ctx, jobID)
	log.Printf("Job %s completed. Success: %d, Failed: %d",
		jobID, job.SuccessfulEpisodes, job.FailedEpisodes)
}

// CancelJob cancels a running job
func (s *BulkTranscribeService) CancelJob(jobID string) bool {
	s.runningJobsMu.Lock()
	defer s.runningJobsMu.Unlock()

	if s.runningJobs[jobID] {
		delete(s.runningJobs, jobID)
		log.Printf("Cancelled job %s", jobID)
		return true
	}
	return false
}

// Helper functions

func generateJobID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return "job_" + base64.URLEncoding.EncodeToString(b)[:16]
}

func sortEpisodesByDate(episodes []EpisodeData) {
	// Sort episodes by published date, oldest first
	// Using simple bubble sort for small lists
	for i := 0; i < len(episodes)-1; i++ {
		for j := 0; j < len(episodes)-i-1; j++ {
			// Handle nil dates
			if episodes[j].PublishedDate == nil {
				continue
			}
			if episodes[j+1].PublishedDate == nil {
				continue
			}
			if episodes[j].PublishedDate.After(*episodes[j+1].PublishedDate) {
				episodes[j], episodes[j+1] = episodes[j+1], episodes[j]
			}
		}
	}
}
