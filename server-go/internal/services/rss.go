package services

import (
	"fmt"
	"log"
	"time"

	"github.com/mmcdole/gofeed"
)

// RSSParser handles parsing of RSS feeds
type RSSParser struct {
	parser *gofeed.Parser
}

// NewRSSParser creates a new RSS parser
func NewRSSParser() *RSSParser {
	return &RSSParser{
		parser: gofeed.NewParser(),
	}
}

// PodcastData represents parsed podcast metadata
type PodcastData struct {
	Title       string
	Description string
	ImageURL    string
	Author      string
	Language    string
	WebsiteURL  string
}

// EpisodeData represents parsed episode metadata
type EpisodeData struct {
	Title         string
	Description   string
	AudioURL      string
	PublishedDate *time.Time
	Duration      *int
}

// ParseFeed parses an RSS feed and returns podcast and episode data
func (r *RSSParser) ParseFeed(rssURL string) (*PodcastData, []EpisodeData, error) {
	log.Printf("Parsing RSS feed: %s", rssURL)

	feed, err := r.parser.ParseURL(rssURL)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to parse RSS feed: %w", err)
	}

	if feed == nil {
		return nil, nil, fmt.Errorf("feed is empty")
	}

	// Extract podcast metadata
	podcastData := &PodcastData{
		Title:       feed.Title,
		Description: feed.Description,
		ImageURL:    extractImageURL(feed),
		Author:      extractAuthor(feed),
		Language:    feed.Language,
		WebsiteURL:  feed.Link,
	}

	// Extract episodes
	episodes := make([]EpisodeData, 0, len(feed.Items))
	for _, item := range feed.Items {
		episode := EpisodeData{
			Title:         item.Title,
			Description:   item.Description,
			AudioURL:      extractAudioURL(item),
			PublishedDate: item.PublishedParsed,
		}

		// Extract duration if available
		if item.ITunesExt != nil && item.ITunesExt.Duration != "" {
			if duration := parseDuration(item.ITunesExt.Duration); duration > 0 {
				durationMinutes := int(duration / 60)
				episode.Duration = &durationMinutes
			}
		}

		// Only include episodes with audio URL
		if episode.AudioURL != "" {
			episodes = append(episodes, episode)
		}
	}

	log.Printf("Successfully parsed podcast: %s with %d episodes", podcastData.Title, len(episodes))
	return podcastData, episodes, nil
}

// extractImageURL extracts image URL from feed
func extractImageURL(feed *gofeed.Feed) string {
	// Try iTunes image first
	if feed.ITunesExt != nil && feed.ITunesExt.Image != "" {
		return feed.ITunesExt.Image
	}

	// Try standard image
	if feed.Image != nil && feed.Image.URL != "" {
		return feed.Image.URL
	}

	return ""
}

// extractAuthor extracts author from feed
func extractAuthor(feed *gofeed.Feed) string {
	// Try iTunes author first
	if feed.ITunesExt != nil && feed.ITunesExt.Author != "" {
		return feed.ITunesExt.Author
	}

	// Try standard author
	if feed.Author != nil && feed.Author.Name != "" {
		return feed.Author.Name
	}

	return ""
}

// extractAudioURL extracts audio URL from an item
func extractAudioURL(item *gofeed.Item) string {
	// Check enclosures for audio files
	for _, enc := range item.Enclosures {
		if isAudioType(enc.Type) {
			return enc.URL
		}
	}

	// If no audio enclosure, try the link
	if item.Link != "" && (isAudioURL(item.Link)) {
		return item.Link
	}

	return ""
}

// isAudioType checks if a MIME type is an audio type
func isAudioType(mimeType string) bool {
	audioTypes := []string{
		"audio/mpeg",
		"audio/mp3",
		"audio/mp4",
		"audio/x-m4a",
		"audio/aac",
		"audio/ogg",
		"audio/wav",
	}

	for _, at := range audioTypes {
		if mimeType == at {
			return true
		}
	}

	return false
}

// isAudioURL checks if a URL looks like an audio file
func isAudioURL(url string) bool {
	audioExtensions := []string{".mp3", ".m4a", ".mp4", ".aac", ".ogg", ".wav"}

	for _, ext := range audioExtensions {
		if len(url) >= len(ext) && url[len(url)-len(ext):] == ext {
			return true
		}
	}

	return false
}

// parseDuration parses iTunes duration format (HH:MM:SS, MM:SS, or seconds)
func parseDuration(durationStr string) int {
	// Try parsing as HH:MM:SS or MM:SS
	formats := []string{"15:04:05", "04:05", "05"}

	for _, format := range formats {
		if t, err := time.Parse(format, durationStr); err == nil {
			return t.Hour()*3600 + t.Minute()*60 + t.Second()
		}
	}

	// Try parsing as plain seconds
	var seconds int
	if _, err := fmt.Sscanf(durationStr, "%d", &seconds); err == nil {
		return seconds
	}

	return 0
}
