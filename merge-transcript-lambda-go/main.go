package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

const (
	timestampIntervalSeconds = 300 // Add timestamp every 5 minutes
)

var (
	// Global clients (reused across Lambda invocations)
	mongoClient *mongo.Client
	s3Client    *s3.S3
)

// TranscriptChunk represents a single transcript chunk
type TranscriptChunk struct {
	ChunkIndex       int    `json:"chunk_index"`
	TranscriptS3Key  string `json:"transcript_s3_key"`
	StartTimeSeconds int    `json:"start_time_seconds"`
}

// TranscriptData is the JSON structure of a transcript file
type TranscriptData struct {
	Text string `json:"text"`
}

// LambdaEvent is the input event structure
type LambdaEvent struct {
	EpisodeID   string            `json:"episode_id"`
	TotalChunks int               `json:"total_chunks"`
	Transcripts []TranscriptChunk `json:"transcripts"`
	S3Bucket    string            `json:"s3_bucket"`
}

// LambdaResponse is the output structure
type LambdaResponse struct {
	EpisodeID       string `json:"episode_id"`
	TranscriptS3Key string `json:"transcript_s3_key,omitempty"`
	TotalWords      int    `json:"total_words,omitempty"`
	Status          string `json:"status"`
	ErrorMessage    string `json:"error_message,omitempty"`
}

func init() {
	// Initialize global clients once
	initMongoClient()
	initS3Client()
}

func initMongoClient() {
	mongoURI := os.Getenv("MONGODB_URI")
	if mongoURI == "" {
		log.Fatal("MONGODB_URI environment variable not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var err error
	mongoClient, err = mongo.Connect(ctx, options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("Failed to connect to MongoDB: %v", err)
	}

	// Ping to verify connection
	if err = mongoClient.Ping(ctx, nil); err != nil {
		log.Fatalf("Failed to ping MongoDB: %v", err)
	}

	log.Println("Successfully connected to MongoDB")
}

func initS3Client() {
	sess := session.Must(session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	}))
	s3Client = s3.New(sess)
}

// downloadTranscriptFromS3 retrieves and parses a transcript chunk
func downloadTranscriptFromS3(ctx context.Context, bucket, key string) (*TranscriptData, error) {
	log.Printf("Downloading s3://%s/%s", bucket, key)

	result, err := s3Client.GetObjectWithContext(ctx, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to download from S3: %w", err)
	}
	defer result.Body.Close()

	body, err := io.ReadAll(result.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read S3 object: %w", err)
	}

	var transcriptData TranscriptData
	if err := json.Unmarshal(body, &transcriptData); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	log.Printf("Successfully downloaded and parsed %s", key)
	return &transcriptData, nil
}

// uploadToS3 uploads content to S3
func uploadToS3(ctx context.Context, bucket, key, content, contentType string) error {
	log.Printf("Uploading to s3://%s/%s", bucket, key)

	_, err := s3Client.PutObjectWithContext(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(bucket),
		Key:         aws.String(key),
		Body:        bytes.NewReader([]byte(content)),
		ContentType: aws.String(contentType),
	})

	if err != nil {
		return fmt.Errorf("failed to upload to S3: %w", err)
	}

	log.Printf("Successfully uploaded to %s", key)
	return nil
}

// formatTimestamp converts seconds to [HH:MM:SS] format
func formatTimestamp(seconds int) string {
	hours := seconds / 3600
	minutes := (seconds % 3600) / 60
	secs := seconds % 60
	return fmt.Sprintf("[%02d:%02d:%02d]", hours, minutes, secs)
}

// mergeTranscripts combines transcript chunks into a single formatted transcript
func mergeTranscripts(ctx context.Context, transcripts []TranscriptChunk, s3Bucket string, addTimestamps bool) (string, int, error) {
	// Sort transcripts by chunk index
	sort.Slice(transcripts, func(i, j int) bool {
		return transcripts[i].ChunkIndex < transcripts[j].ChunkIndex
	})

	var builder strings.Builder
	totalWords := 0
	lastTimestampSeconds := -timestampIntervalSeconds // Force timestamp at the beginning

	for _, chunk := range transcripts {
		log.Printf("Processing chunk %d from %s", chunk.ChunkIndex, chunk.TranscriptS3Key)

		// Download and parse transcript chunk
		transcriptData, err := downloadTranscriptFromS3(ctx, s3Bucket, chunk.TranscriptS3Key)
		if err != nil {
			return "", 0, fmt.Errorf("chunk %d: %w", chunk.ChunkIndex, err)
		}

		text := strings.TrimSpace(transcriptData.Text)
		if text == "" {
			log.Printf("Warning: Chunk %d has no text content", chunk.ChunkIndex)
			continue
		}

		// Add timestamp header if 5 minutes have passed
		if addTimestamps && (chunk.StartTimeSeconds-lastTimestampSeconds) >= timestampIntervalSeconds {
			builder.WriteString("\n")
			builder.WriteString(formatTimestamp(chunk.StartTimeSeconds))
			builder.WriteString("\n")
			lastTimestampSeconds = chunk.StartTimeSeconds
		}

		// Add the chunk text
		builder.WriteString(text)

		// Add paragraph break between chunks
		builder.WriteString("\n\n")

		// Count words (simple split by whitespace)
		totalWords += len(strings.Fields(text))
	}

	mergedText := strings.TrimSpace(builder.String())
	log.Printf("Merged transcript: %d characters, %d words", len(mergedText), totalWords)

	return mergedText, totalWords, nil
}

// updateEpisodeInMongoDB updates the episode document with completion status
func updateEpisodeInMongoDB(ctx context.Context, episodeID, transcriptS3Key string) error {
	db := mongoClient.Database("")
	episodesCollection := db.Collection("episodes")

	result, err := episodesCollection.UpdateOne(
		ctx,
		bson.M{"episode_id": episodeID},
		bson.M{
			"$set": bson.M{
				"status":            "completed",
				"transcript_s3_key": transcriptS3Key,
				"processed_at":      time.Now().UTC(),
			},
		},
	)

	if err != nil {
		return fmt.Errorf("failed to update MongoDB: %w", err)
	}

	if result.MatchedCount > 0 {
		log.Printf("Updated MongoDB episode %s: matched=%d, modified=%d",
			episodeID, result.MatchedCount, result.ModifiedCount)
	} else {
		log.Printf("Warning: No episode found with episode_id=%s", episodeID)
	}

	return nil
}

// updateEpisodeError updates the episode with error status
func updateEpisodeError(ctx context.Context, episodeID, errorMessage string) {
	db := mongoClient.Database("")
	episodesCollection := db.Collection("episodes")

	_, err := episodesCollection.UpdateOne(
		ctx,
		bson.M{"episode_id": episodeID},
		bson.M{
			"$set": bson.M{
				"status":        "error",
				"error_message": errorMessage,
				"processed_at":  time.Now().UTC(),
			},
		},
	)

	if err != nil {
		log.Printf("Failed to update error status in MongoDB: %v", err)
	}
}

// HandleRequest is the Lambda handler
func HandleRequest(ctx context.Context, event LambdaEvent) (LambdaResponse, error) {
	log.Printf("Received event: %+v", event)

	// Validate required parameters
	if event.EpisodeID == "" {
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: "Missing required parameter: episode_id",
		}, nil
	}

	if len(event.Transcripts) == 0 {
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: "No transcripts provided",
		}, nil
	}

	s3Bucket := event.S3Bucket
	if s3Bucket == "" {
		s3Bucket = os.Getenv("S3_BUCKET")
	}

	if s3Bucket == "" {
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: "S3 bucket not specified in event or environment variables",
		}, nil
	}

	// Validate chunk count
	if event.TotalChunks > 0 && len(event.Transcripts) != event.TotalChunks {
		log.Printf("Warning: Expected %d chunks but received %d", event.TotalChunks, len(event.Transcripts))
	}

	// Check for missing chunks
	chunkIndices := make(map[int]bool)
	for _, chunk := range event.Transcripts {
		chunkIndices[chunk.ChunkIndex] = true
	}

	for i := 0; i < len(event.Transcripts); i++ {
		if !chunkIndices[i] {
			errorMsg := fmt.Sprintf("Missing chunk at index: %d", i)
			log.Println(errorMsg)
			return LambdaResponse{
				EpisodeID:    event.EpisodeID,
				Status:       "error",
				ErrorMessage: errorMsg,
			}, nil
		}
	}

	// Merge transcripts
	mergedText, totalWords, err := mergeTranscripts(ctx, event.Transcripts, s3Bucket, true)
	if err != nil {
		errorMessage := fmt.Sprintf("Error merging transcripts: %v", err)
		log.Println(errorMessage)
		updateEpisodeError(ctx, event.EpisodeID, errorMessage)
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: errorMessage,
		}, nil
	}

	// Upload final transcript to S3
	finalTranscriptKey := fmt.Sprintf("transcripts/%s/final.txt", event.EpisodeID)
	if err := uploadToS3(ctx, s3Bucket, finalTranscriptKey, mergedText, "text/plain"); err != nil {
		errorMessage := fmt.Sprintf("Failed to upload final transcript: %v", err)
		log.Println(errorMessage)
		updateEpisodeError(ctx, event.EpisodeID, errorMessage)
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: errorMessage,
		}, nil
	}

	// Update MongoDB
	if err := updateEpisodeInMongoDB(ctx, event.EpisodeID, finalTranscriptKey); err != nil {
		errorMessage := fmt.Sprintf("Failed to update MongoDB: %v", err)
		log.Println(errorMessage)
		// Don't mark as error since transcript was successfully uploaded
		log.Println("Warning: Transcript uploaded but MongoDB update failed")
	}

	log.Printf("Successfully merged transcripts for episode %s", event.EpisodeID)

	return LambdaResponse{
		EpisodeID:       event.EpisodeID,
		TranscriptS3Key: finalTranscriptKey,
		TotalWords:      totalWords,
		Status:          "completed",
	}, nil
}

func main() {
	lambda.Start(HandleRequest)
}
