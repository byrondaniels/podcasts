//go:build http

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sort"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
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
	if os.Getenv("SKIP_INIT") == "true" {
		return
	}
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

	if err = mongoClient.Ping(ctx, nil); err != nil {
		log.Fatalf("Failed to ping MongoDB: %v", err)
	}

	log.Println("Successfully connected to MongoDB")
}

func initS3Client() {
	awsConfig := &aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	}

	// Use custom endpoint for Minio/LocalStack
	if endpoint := os.Getenv("AWS_ENDPOINT_URL"); endpoint != "" {
		awsConfig.Endpoint = aws.String(endpoint)
		awsConfig.S3ForcePathStyle = aws.Bool(true)
	}

	// Use explicit credentials if provided (for Minio)
	if accessKey := os.Getenv("AWS_ACCESS_KEY_ID"); accessKey != "" {
		secretKey := os.Getenv("AWS_SECRET_ACCESS_KEY")
		awsConfig.Credentials = credentials.NewStaticCredentials(accessKey, secretKey, "")
	}

	sess := session.Must(session.NewSession(awsConfig))
	s3Client = s3.New(sess)
	log.Printf("S3 client initialized with endpoint: %s", os.Getenv("AWS_ENDPOINT_URL"))
}

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

func formatTimestamp(seconds int) string {
	hours := seconds / 3600
	minutes := (seconds % 3600) / 60
	secs := seconds % 60
	return fmt.Sprintf("[%02d:%02d:%02d]", hours, minutes, secs)
}

func mergeTranscripts(ctx context.Context, transcripts []TranscriptChunk, s3Bucket string, addTimestamps bool) (string, int, error) {
	sort.Slice(transcripts, func(i, j int) bool {
		return transcripts[i].ChunkIndex < transcripts[j].ChunkIndex
	})

	var builder strings.Builder
	totalWords := 0
	lastTimestampSeconds := -timestampIntervalSeconds

	for _, chunk := range transcripts {
		log.Printf("Processing chunk %d from %s", chunk.ChunkIndex, chunk.TranscriptS3Key)

		transcriptData, err := downloadTranscriptFromS3(ctx, s3Bucket, chunk.TranscriptS3Key)
		if err != nil {
			return "", 0, fmt.Errorf("chunk %d: %w", chunk.ChunkIndex, err)
		}

		text := strings.TrimSpace(transcriptData.Text)
		if text == "" {
			log.Printf("Warning: Chunk %d has no text content", chunk.ChunkIndex)
			continue
		}

		if addTimestamps && (chunk.StartTimeSeconds-lastTimestampSeconds) >= timestampIntervalSeconds {
			builder.WriteString("\n")
			builder.WriteString(formatTimestamp(chunk.StartTimeSeconds))
			builder.WriteString("\n")
			lastTimestampSeconds = chunk.StartTimeSeconds
		}

		builder.WriteString(text)
		builder.WriteString("\n\n")
		totalWords += len(strings.Fields(text))
	}

	mergedText := strings.TrimSpace(builder.String())
	log.Printf("Merged transcript: %d characters, %d words", len(mergedText), totalWords)

	return mergedText, totalWords, nil
}

func updateEpisodeInMongoDB(ctx context.Context, episodeID, transcriptS3Key string) error {
	db := mongoClient.Database("podcast_db")
	episodesCollection := db.Collection("episodes")

	result, err := episodesCollection.UpdateOne(
		ctx,
		bson.M{"episode_id": episodeID},
		bson.M{
			"$set": bson.M{
				"transcript_status": "completed",
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

func updateEpisodeError(ctx context.Context, episodeID, errorMessage string) {
	db := mongoClient.Database("podcast_db")
	episodesCollection := db.Collection("episodes")

	_, err := episodesCollection.UpdateOne(
		ctx,
		bson.M{"episode_id": episodeID},
		bson.M{
			"$set": bson.M{
				"transcript_status": "failed",
				"error_message":     errorMessage,
				"processed_at":      time.Now().UTC(),
			},
		},
	)

	if err != nil {
		log.Printf("Failed to update error status in MongoDB: %v", err)
	}
}

func handleRequest(ctx context.Context, event LambdaEvent) LambdaResponse {
	log.Printf("Received event: %+v", event)

	if event.EpisodeID == "" {
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: "Missing required parameter: episode_id",
		}
	}

	if len(event.Transcripts) == 0 {
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: "No transcripts provided",
		}
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
		}
	}

	if event.TotalChunks > 0 && len(event.Transcripts) != event.TotalChunks {
		log.Printf("Warning: Expected %d chunks but received %d", event.TotalChunks, len(event.Transcripts))
	}

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
			}
		}
	}

	mergedText, totalWords, err := mergeTranscripts(ctx, event.Transcripts, s3Bucket, true)
	if err != nil {
		errorMessage := fmt.Sprintf("Error merging transcripts: %v", err)
		log.Println(errorMessage)
		updateEpisodeError(ctx, event.EpisodeID, errorMessage)
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: errorMessage,
		}
	}

	finalTranscriptKey := fmt.Sprintf("transcripts/%s/final.txt", event.EpisodeID)
	if err := uploadToS3(ctx, s3Bucket, finalTranscriptKey, mergedText, "text/plain"); err != nil {
		errorMessage := fmt.Sprintf("Failed to upload final transcript: %v", err)
		log.Println(errorMessage)
		updateEpisodeError(ctx, event.EpisodeID, errorMessage)
		return LambdaResponse{
			EpisodeID:    event.EpisodeID,
			Status:       "error",
			ErrorMessage: errorMessage,
		}
	}

	if err := updateEpisodeInMongoDB(ctx, event.EpisodeID, finalTranscriptKey); err != nil {
		errorMessage := fmt.Sprintf("Failed to update MongoDB: %v", err)
		log.Println(errorMessage)
		log.Println("Warning: Transcript uploaded but MongoDB update failed")
	}

	log.Printf("Successfully merged transcripts for episode %s", event.EpisodeID)

	return LambdaResponse{
		EpisodeID:       event.EpisodeID,
		TranscriptS3Key: finalTranscriptKey,
		TotalWords:      totalWords,
		Status:          "completed",
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "merge-lambda",
	})
}

func invokeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		sendError(w, "Failed to read request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	log.Printf("Received invoke request: %s", string(body))

	var event LambdaEvent
	if err := json.Unmarshal(body, &event); err != nil {
		sendError(w, fmt.Sprintf("Failed to parse request: %v", err), http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	response := handleRequest(ctx, event)

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Failed to encode response: %v", err)
		sendError(w, "Failed to encode response", http.StatusInternalServerError)
	}
}

func sendError(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"statusCode": statusCode,
		"message":    message,
		"error":      true,
	})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8004"
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/invoke", invokeHandler)

	log.Printf("Starting merge-lambda HTTP server on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
