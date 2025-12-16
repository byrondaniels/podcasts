package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sfn"
	"github.com/mmcdole/gofeed"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	// Global clients (reused across Lambda invocations)
	mongoClient *mongo.Client
	sfnClient   *sfn.SFN
	feedParser  *gofeed.Parser
)

// Podcast represents a podcast document
type Podcast struct {
	ID          primitive.ObjectID `bson:"_id"`
	PodcastID   string             `bson:"podcast_id,omitempty"`
	FeedURL     string             `bson:"feed_url,omitempty"`
	RssURL      string             `bson:"rss_url,omitempty"`
	Title       string             `bson:"title"`
	Active      bool               `bson:"active"`
}

// Episode represents an episode document
type Episode struct {
	ID            string             `bson:"_id"`
	EpisodeID     string             `bson:"episode_id"`
	PodcastID     string             `bson:"podcast_id"`
	Title         string             `bson:"title"`
	Description   string             `bson:"description"`
	AudioURL      string             `bson:"audio_url"`
	PublishedDate *time.Time         `bson:"published_date,omitempty"`
	Status        string             `bson:"status"`
	CreatedAt     time.Time          `bson:"created_at"`
	UpdatedAt     time.Time          `bson:"updated_at"`
}

// PodcastResult holds processing stats for a single podcast
type PodcastResult struct {
	PodcastID    string   `json:"podcast_id"`
	PodcastTitle string   `json:"podcast_title"`
	NewEpisodes  int      `json:"new_episodes"`
	Errors       []string `json:"errors"`
}

// Request is the Lambda function request
type Request struct {
	PodcastID string `json:"podcast_id,omitempty"`
}

// Response is the Lambda function response
type Response struct {
	StatusCode     int             `json:"statusCode"`
	Message        string          `json:"message"`
	TotalPodcasts  int             `json:"total_podcasts"`
	Processed      int             `json:"processed_podcasts"`
	TotalEpisodes  int             `json:"total_new_episodes"`
	Errors         []string        `json:"errors,omitempty"`
	PodcastResults []PodcastResult `json:"podcast_results,omitempty"`
}

// StepFunctionInput is the input for Step Functions
type StepFunctionInput struct {
	EpisodeID string `json:"episode_id"`
	AudioURL  string `json:"audio_url"`
	S3Bucket  string `json:"s3_bucket"`
}

func init() {
	// Skip initialization during tests
	if os.Getenv("SKIP_INIT") == "true" {
		return
	}
	// Initialize global clients once
	initMongoClient()
	initSFNClient()
	feedParser = gofeed.NewParser()
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

func initSFNClient() {
	sess := session.Must(session.NewSession(&aws.Config{
		Region: aws.String(os.Getenv("AWS_REGION")),
	}))
	sfnClient = sfn.New(sess)
}

// generateEpisodeID creates a unique episode ID from audio URL
func generateEpisodeID(audioURL string) string {
	hash := sha256.Sum256([]byte(audioURL))
	return hex.EncodeToString(hash[:])
}

// extractAudioURL gets the audio URL from a feed item
func extractAudioURL(item *gofeed.Item) string {
	// Check enclosures first (most common for podcasts)
	for _, enc := range item.Enclosures {
		if enc.Type != "" && len(enc.Type) > 6 && enc.Type[:6] == "audio/" {
			return enc.URL
		}
	}

	// Fallback to item link
	if item.Link != "" {
		return item.Link
	}

	return ""
}

// processPodcast handles a single podcast feed with error handling
func processPodcast(ctx context.Context, podcast Podcast, db *mongo.Database) PodcastResult {
	result := PodcastResult{
		PodcastID:    podcast.ID.Hex(),
		PodcastTitle: podcast.Title,
		NewEpisodes:  0,
		Errors:       []string{},
	}

	feedURL := podcast.FeedURL
	if feedURL == "" {
		feedURL = podcast.RssURL
	}

	if feedURL == "" {
		errMsg := fmt.Sprintf("No feed URL found for podcast %s", podcast.ID.Hex())
		log.Println(errMsg)
		result.Errors = append(result.Errors, errMsg)
		return result
	}

	log.Printf("Processing podcast: %s (%s)", podcast.Title, podcast.ID.Hex())

	// Parse RSS feed
	feed, err := feedParser.ParseURL(feedURL)
	if err != nil {
		errMsg := fmt.Sprintf("Failed to parse feed %s: %v", feedURL, err)
		log.Println(errMsg)
		result.Errors = append(result.Errors, errMsg)
		return result
	}

	if len(feed.Items) == 0 {
		log.Printf("No items found in feed for podcast %s", podcast.Title)
		return result
	}

	episodesCollection := db.Collection("episodes")

	// Limit to the last 10 episodes (most recent)
	// RSS feeds typically list newest episodes first, so we take the first 10
	maxEpisodes := 10
	itemsToProcess := feed.Items
	if len(feed.Items) > maxEpisodes {
		itemsToProcess = feed.Items[:maxEpisodes]
		log.Printf("Limiting to %d most recent episodes out of %d total for podcast %s",
			maxEpisodes, len(feed.Items), podcast.Title)
	}

	// Process each episode in the feed
	for _, item := range itemsToProcess {
		audioURL := extractAudioURL(item)
		if audioURL == "" {
			log.Printf("No audio URL found for episode: %s", item.Title)
			continue
		}

		// Check if episode already exists
		var existingEpisode Episode
		err := episodesCollection.FindOne(ctx, bson.M{"audio_url": audioURL}).Decode(&existingEpisode)
		if err == nil {
			// Episode already exists
			continue
		} else if err != mongo.ErrNoDocuments {
			errMsg := fmt.Sprintf("Database error checking episode: %v", err)
			log.Println(errMsg)
			result.Errors = append(result.Errors, errMsg)
			continue
		}

		// Generate episode ID
		episodeID := generateEpisodeID(audioURL)

		// Parse published date
		var publishedDate *time.Time
		if item.PublishedParsed != nil {
			publishedDate = item.PublishedParsed
		}

		// Create episode document
		episode := Episode{
			ID:            episodeID,
			EpisodeID:     episodeID,
			PodcastID:     podcast.ID.Hex(),
			Title:         item.Title,
			Description:   item.Description,
			AudioURL:      audioURL,
			PublishedDate: publishedDate,
			Status:        "pending",
			CreatedAt:     time.Now().UTC(),
			UpdatedAt:     time.Now().UTC(),
		}

		// Insert episode into MongoDB
		_, err = episodesCollection.InsertOne(ctx, episode)
		if err != nil {
			if mongo.IsDuplicateKeyError(err) {
				log.Printf("Duplicate episode detected (race condition): %s", episodeID)
				continue
			}
			errMsg := fmt.Sprintf("Failed to insert episode %s: %v", episodeID, err)
			log.Println(errMsg)
			result.Errors = append(result.Errors, errMsg)
			continue
		}

		log.Printf("Inserted new episode: %s (%s)", item.Title, episodeID)
		result.NewEpisodes++

		// Trigger Step Functions workflow
		if err := triggerStepFunction(ctx, episodeID, audioURL); err != nil {
			errMsg := fmt.Sprintf("Failed to trigger Step Function for %s: %v", episodeID, err)
			log.Println(errMsg)
			result.Errors = append(result.Errors, errMsg)

			// Update episode status to failed
			_, _ = episodesCollection.UpdateOne(
				ctx,
				bson.M{"_id": episodeID},
				bson.M{"$set": bson.M{"status": "failed", "error": err.Error()}},
			)
		} else {
			log.Printf("Triggered Step Function for episode %s", episodeID)
		}
	}

	return result
}

// triggerStepFunction starts a Step Functions execution
func triggerStepFunction(ctx context.Context, episodeID, audioURL string) error {
	stepFunctionARN := os.Getenv("STEP_FUNCTION_ARN")
	s3Bucket := os.Getenv("S3_BUCKET")
	if s3Bucket == "" {
		s3Bucket = "podcast-audio-bucket"
	}

	input := StepFunctionInput{
		EpisodeID: episodeID,
		AudioURL:  audioURL,
		S3Bucket:  s3Bucket,
	}

	inputJSON, err := json.Marshal(input)
	if err != nil {
		return fmt.Errorf("failed to marshal input: %w", err)
	}

	executionName := fmt.Sprintf("episode-%s-%d", episodeID, time.Now().Unix())

	_, err = sfnClient.StartExecutionWithContext(ctx, &sfn.StartExecutionInput{
		StateMachineArn: aws.String(stepFunctionARN),
		Name:            aws.String(executionName),
		Input:           aws.String(string(inputJSON)),
	})

	return err
}

// HandleRequest is the Lambda handler
func HandleRequest(ctx context.Context, event json.RawMessage) (Response, error) {
	log.Println("Starting RSS feed polling")
	log.Printf("Event: %s", string(event))

	// Parse request to check for specific podcast_id
	var request Request
	if len(event) > 0 && string(event) != "{}" && string(event) != "null" {
		if err := json.Unmarshal(event, &request); err != nil {
			log.Printf("Warning: Failed to parse event as Request: %v", err)
		}
	}

	response := Response{
		StatusCode:     200,
		Message:        "RSS polling completed",
		TotalPodcasts:  0,
		Processed:      0,
		TotalEpisodes:  0,
		Errors:         []string{},
		PodcastResults: []PodcastResult{},
	}

	// Get database
	db := mongoClient.Database("")  // Uses default database from connection string
	podcastsCollection := db.Collection("podcasts")

	// Build query - filter by podcast_id if provided, otherwise get all active podcasts
	query := bson.M{"active": true}
	if request.PodcastID != "" {
		query["podcast_id"] = request.PodcastID
		log.Printf("Polling specific podcast: %s", request.PodcastID)
	} else {
		log.Println("Polling all active podcasts")
	}

	// Query for podcasts
	cursor, err := podcastsCollection.Find(ctx, query)
	if err != nil {
		response.StatusCode = 500
		response.Message = "Failed to query podcasts"
		response.Errors = append(response.Errors, err.Error())
		return response, err
	}
	defer cursor.Close(ctx)

	var podcasts []Podcast
	if err := cursor.All(ctx, &podcasts); err != nil {
		response.StatusCode = 500
		response.Message = "Failed to decode podcasts"
		response.Errors = append(response.Errors, err.Error())
		return response, err
	}

	response.TotalPodcasts = len(podcasts)
	log.Printf("Found %d active podcasts", len(podcasts))

	if len(podcasts) == 0 {
		if request.PodcastID != "" {
			response.StatusCode = 404
			response.Message = fmt.Sprintf("Podcast with ID '%s' not found or not active", request.PodcastID)
			response.Errors = append(response.Errors, response.Message)
			return response, fmt.Errorf(response.Message)
		}
		response.Message = "No active podcasts to process"
		return response, nil
	}

	// Process podcasts concurrently with bounded parallelism
	maxConcurrency := 10
	semaphore := make(chan struct{}, maxConcurrency)
	var wg sync.WaitGroup
	var mu sync.Mutex
	results := make([]PodcastResult, 0, len(podcasts))

	for _, podcast := range podcasts {
		wg.Add(1)
		semaphore <- struct{}{} // Acquire semaphore

		go func(p Podcast) {
			defer wg.Done()
			defer func() { <-semaphore }() // Release semaphore

			result := processPodcast(ctx, p, db)

			mu.Lock()
			results = append(results, result)
			response.Processed++
			response.TotalEpisodes += result.NewEpisodes
			if len(result.Errors) > 0 {
				response.Errors = append(response.Errors, result.Errors...)
			}
			mu.Unlock()
		}(podcast)
	}

	wg.Wait()
	response.PodcastResults = results

	if request.PodcastID != "" {
		response.Message = fmt.Sprintf("Polling completed for podcast %s", request.PodcastID)
		log.Printf("RSS polling complete for podcast %s. Found %d new episodes", request.PodcastID, response.TotalEpisodes)
	} else {
		log.Printf("RSS polling complete. Processed %d podcasts, found %d new episodes",
			response.Processed, response.TotalEpisodes)
	}

	return response, nil
}

func main() {
	lambda.Start(HandleRequest)
}
