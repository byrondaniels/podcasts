//go:build http

package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/mmcdole/gofeed"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var (
	mongoClient *mongo.Client
	feedParser  *gofeed.Parser
)

// Podcast represents a podcast document
type Podcast struct {
	ID        primitive.ObjectID `bson:"_id"`
	PodcastID string             `bson:"podcast_id,omitempty"`
	FeedURL   string             `bson:"feed_url,omitempty"`
	RssURL    string             `bson:"rss_url,omitempty"`
	Title     string             `bson:"title"`
	Active    bool               `bson:"active"`
}

// Episode represents an episode document
type Episode struct {
	ID               string     `bson:"_id"`
	EpisodeID        string     `bson:"episode_id"`
	PodcastID        string     `bson:"podcast_id"`
	Title            string     `bson:"title"`
	Description      string     `bson:"description"`
	AudioURL         string     `bson:"audio_url"`
	PublishedDate    *time.Time `bson:"published_date,omitempty"`
	TranscriptStatus string     `bson:"transcript_status"`
	CreatedAt        time.Time  `bson:"created_at"`
	UpdatedAt        time.Time  `bson:"updated_at"`
}

// NewEpisode represents a newly discovered episode
type NewEpisode struct {
	EpisodeID string `json:"episode_id"`
	Title     string `json:"title"`
	AudioURL  string `json:"audio_url"`
	PodcastID string `json:"podcast_id"`
}

// PodcastResult holds processing stats
type PodcastResult struct {
	PodcastID    string       `json:"podcast_id"`
	PodcastTitle string       `json:"podcast_title"`
	NewEpisodes  int          `json:"new_episodes"`
	Episodes     []NewEpisode `json:"episodes,omitempty"`
	Errors       []string     `json:"errors"`
}

// Request is the request structure
type Request struct {
	PodcastID string `json:"podcast_id,omitempty"`
}

// Response is the response structure
type Response struct {
	StatusCode     int             `json:"statusCode"`
	Message        string          `json:"message"`
	TotalPodcasts  int             `json:"total_podcasts"`
	Processed      int             `json:"processed_podcasts"`
	TotalEpisodes  int             `json:"total_new_episodes"`
	Errors         []string        `json:"errors,omitempty"`
	PodcastResults []PodcastResult `json:"podcast_results,omitempty"`
}

func init() {
	if os.Getenv("SKIP_INIT") == "true" {
		return
	}
	initMongoClient()
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

	if err = mongoClient.Ping(ctx, nil); err != nil {
		log.Fatalf("Failed to ping MongoDB: %v", err)
	}

	log.Println("Successfully connected to MongoDB")
}

func generateEpisodeID(audioURL string) string {
	hash := sha256.Sum256([]byte(audioURL))
	return hex.EncodeToString(hash[:])
}

func extractAudioURL(item *gofeed.Item) string {
	for _, enc := range item.Enclosures {
		if enc.Type != "" && len(enc.Type) > 6 && enc.Type[:6] == "audio/" {
			return enc.URL
		}
	}
	if item.Link != "" {
		return item.Link
	}
	return ""
}

func processPodcast(ctx context.Context, podcast Podcast, db *mongo.Database) PodcastResult {
	result := PodcastResult{
		PodcastID:    podcast.ID.Hex(),
		PodcastTitle: podcast.Title,
		NewEpisodes:  0,
		Episodes:     []NewEpisode{},
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

	maxEpisodes := 10
	itemsToProcess := feed.Items
	if len(feed.Items) > maxEpisodes {
		itemsToProcess = feed.Items[:maxEpisodes]
		log.Printf("Limiting to %d most recent episodes out of %d total for podcast %s",
			maxEpisodes, len(feed.Items), podcast.Title)
	}

	for _, item := range itemsToProcess {
		audioURL := extractAudioURL(item)
		if audioURL == "" {
			log.Printf("No audio URL found for episode: %s", item.Title)
			continue
		}

		var existingEpisode Episode
		err := episodesCollection.FindOne(ctx, bson.M{"audio_url": audioURL}).Decode(&existingEpisode)
		if err == nil {
			continue
		} else if err != mongo.ErrNoDocuments {
			errMsg := fmt.Sprintf("Database error checking episode: %v", err)
			log.Println(errMsg)
			result.Errors = append(result.Errors, errMsg)
			continue
		}

		episodeID := generateEpisodeID(audioURL)

		var publishedDate *time.Time
		if item.PublishedParsed != nil {
			publishedDate = item.PublishedParsed
		}

		episode := Episode{
			ID:               episodeID,
			EpisodeID:        episodeID,
			PodcastID:        podcast.ID.Hex(),
			Title:            item.Title,
			Description:      item.Description,
			AudioURL:         audioURL,
			PublishedDate:    publishedDate,
			TranscriptStatus: "pending",
			CreatedAt:        time.Now().UTC(),
			UpdatedAt:        time.Now().UTC(),
		}

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
		result.Episodes = append(result.Episodes, NewEpisode{
			EpisodeID: episodeID,
			Title:     item.Title,
			AudioURL:  audioURL,
			PodcastID: podcast.ID.Hex(),
		})
		// NOTE: In HTTP mode, we don't trigger Step Functions
		// The backend orchestration handles transcription workflow
	}

	return result
}

func handleRequest(ctx context.Context, event json.RawMessage) (Response, error) {
	log.Println("Starting RSS feed polling")
	log.Printf("Event: %s", string(event))

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

	db := mongoClient.Database("podcast_db")
	podcastsCollection := db.Collection("podcasts")

	query := bson.M{"active": true}
	if request.PodcastID != "" {
		query["podcast_id"] = request.PodcastID
		log.Printf("Polling specific podcast: %s", request.PodcastID)
	} else {
		log.Println("Polling all active podcasts")
	}

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

	maxConcurrency := 10
	semaphore := make(chan struct{}, maxConcurrency)
	var wg sync.WaitGroup
	var mu sync.Mutex
	results := make([]PodcastResult, 0, len(podcasts))

	for _, podcast := range podcasts {
		wg.Add(1)
		semaphore <- struct{}{}

		go func(p Podcast) {
			defer wg.Done()
			defer func() { <-semaphore }()

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

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "poll-lambda",
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

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	response, err := handleRequest(ctx, body)
	if err != nil {
		log.Printf("Handler error: %v", err)
	}

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
		port = "8001"
	}

	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/invoke", invokeHandler)

	log.Printf("Starting poll-lambda HTTP server on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
