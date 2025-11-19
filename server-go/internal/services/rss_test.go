package services

import (
	"testing"
	"time"

	"github.com/mmcdole/gofeed"
	ext "github.com/mmcdole/gofeed/extensions"
)

func TestIsAudioType(t *testing.T) {
	tests := []struct {
		mimeType string
		expected bool
	}{
		{"audio/mpeg", true},
		{"audio/mp3", true},
		{"audio/mp4", true},
		{"audio/x-m4a", true},
		{"audio/aac", true},
		{"audio/ogg", true},
		{"audio/wav", true},
		{"video/mp4", false},
		{"text/plain", false},
		{"application/pdf", false},
		{"", false},
	}

	for _, tt := range tests {
		t.Run(tt.mimeType, func(t *testing.T) {
			result := isAudioType(tt.mimeType)
			if result != tt.expected {
				t.Errorf("isAudioType(%q) = %v, want %v", tt.mimeType, result, tt.expected)
			}
		})
	}
}

func TestIsAudioURL(t *testing.T) {
	tests := []struct {
		url      string
		expected bool
	}{
		{"https://example.com/podcast.mp3", true},
		{"https://example.com/podcast.m4a", true},
		{"https://example.com/podcast.mp4", true},
		{"https://example.com/podcast.aac", true},
		{"https://example.com/podcast.ogg", true},
		{"https://example.com/podcast.wav", true},
		{"https://example.com/page.html", false},
		{"https://example.com/image.jpg", false},
		{"https://example.com/video.avi", false},
		{"", false},
		{"no-extension", false},
	}

	for _, tt := range tests {
		t.Run(tt.url, func(t *testing.T) {
			result := isAudioURL(tt.url)
			if result != tt.expected {
				t.Errorf("isAudioURL(%q) = %v, want %v", tt.url, result, tt.expected)
			}
		})
	}
}

func TestParseDuration(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected int
	}{
		{
			name:     "HH:MM:SS format",
			input:    "01:23:45",
			expected: 5025,
		},
		{
			name:     "MM:SS format",
			input:    "23:45",
			expected: 1425,
		},
		{
			name:     "seconds only",
			input:    "45",
			expected: 45,
		},
		{
			name:     "plain seconds as number",
			input:    "120",
			expected: 120,
		},
		{
			name:     "invalid format",
			input:    "invalid",
			expected: 0,
		},
		{
			name:     "empty string",
			input:    "",
			expected: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := parseDuration(tt.input)
			if result != tt.expected {
				t.Errorf("parseDuration(%q) = %v, want %v", tt.input, result, tt.expected)
			}
		})
	}
}

func TestExtractImageURL(t *testing.T) {
	tests := []struct {
		name     string
		feed     *gofeed.Feed
		expected string
	}{
		{
			name: "iTunes image present",
			feed: &gofeed.Feed{
				ITunesExt: &ext.ITunesFeedExtension{
					Image: "https://example.com/itunes.jpg",
				},
				Image: &gofeed.Image{
					URL: "https://example.com/standard.jpg",
				},
			},
			expected: "https://example.com/itunes.jpg",
		},
		{
			name: "standard image only",
			feed: &gofeed.Feed{
				Image: &gofeed.Image{
					URL: "https://example.com/standard.jpg",
				},
			},
			expected: "https://example.com/standard.jpg",
		},
		{
			name:     "no image",
			feed:     &gofeed.Feed{},
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractImageURL(tt.feed)
			if result != tt.expected {
				t.Errorf("extractImageURL() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestExtractAuthor(t *testing.T) {
	tests := []struct {
		name     string
		feed     *gofeed.Feed
		expected string
	}{
		{
			name: "iTunes author present",
			feed: &gofeed.Feed{
				ITunesExt: &ext.ITunesFeedExtension{
					Author: "iTunes Author",
				},
				Author: &gofeed.Person{
					Name: "Standard Author",
				},
			},
			expected: "iTunes Author",
		},
		{
			name: "standard author only",
			feed: &gofeed.Feed{
				Author: &gofeed.Person{
					Name: "Standard Author",
				},
			},
			expected: "Standard Author",
		},
		{
			name:     "no author",
			feed:     &gofeed.Feed{},
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractAuthor(tt.feed)
			if result != tt.expected {
				t.Errorf("extractAuthor() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestExtractAudioURL(t *testing.T) {
	tests := []struct {
		name     string
		item     *gofeed.Item
		expected string
	}{
		{
			name: "audio enclosure present",
			item: &gofeed.Item{
				Enclosures: []*gofeed.Enclosure{
					{URL: "https://example.com/audio.mp3", Type: "audio/mpeg"},
				},
			},
			expected: "https://example.com/audio.mp3",
		},
		{
			name: "multiple enclosures, first is audio",
			item: &gofeed.Item{
				Enclosures: []*gofeed.Enclosure{
					{URL: "https://example.com/audio.mp3", Type: "audio/mpeg"},
					{URL: "https://example.com/video.mp4", Type: "video/mp4"},
				},
			},
			expected: "https://example.com/audio.mp3",
		},
		{
			name: "fallback to link with audio extension",
			item: &gofeed.Item{
				Link: "https://example.com/podcast.mp3",
			},
			expected: "https://example.com/podcast.mp3",
		},
		{
			name: "no audio URL",
			item: &gofeed.Item{
				Link: "https://example.com/page.html",
			},
			expected: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractAudioURL(tt.item)
			if result != tt.expected {
				t.Errorf("extractAudioURL() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestNewRSSParser(t *testing.T) {
	parser := NewRSSParser()
	if parser == nil {
		t.Fatal("NewRSSParser() returned nil")
	}
	if parser.parser == nil {
		t.Error("RSSParser.parser is nil")
	}
}

func TestSortEpisodesByDate(t *testing.T) {
	time1 := time.Date(2023, 1, 1, 0, 0, 0, 0, time.UTC)
	time2 := time.Date(2023, 2, 1, 0, 0, 0, 0, time.UTC)
	time3 := time.Date(2023, 3, 1, 0, 0, 0, 0, time.UTC)

	tests := []struct {
		name     string
		input    []EpisodeData
		expected []EpisodeData
	}{
		{
			name: "already sorted",
			input: []EpisodeData{
				{Title: "Episode 1", PublishedDate: &time1},
				{Title: "Episode 2", PublishedDate: &time2},
				{Title: "Episode 3", PublishedDate: &time3},
			},
			expected: []EpisodeData{
				{Title: "Episode 1", PublishedDate: &time1},
				{Title: "Episode 2", PublishedDate: &time2},
				{Title: "Episode 3", PublishedDate: &time3},
			},
		},
		{
			name: "reverse order",
			input: []EpisodeData{
				{Title: "Episode 3", PublishedDate: &time3},
				{Title: "Episode 2", PublishedDate: &time2},
				{Title: "Episode 1", PublishedDate: &time1},
			},
			expected: []EpisodeData{
				{Title: "Episode 1", PublishedDate: &time1},
				{Title: "Episode 2", PublishedDate: &time2},
				{Title: "Episode 3", PublishedDate: &time3},
			},
		},
		{
			name: "mixed order",
			input: []EpisodeData{
				{Title: "Episode 2", PublishedDate: &time2},
				{Title: "Episode 1", PublishedDate: &time1},
				{Title: "Episode 3", PublishedDate: &time3},
			},
			expected: []EpisodeData{
				{Title: "Episode 1", PublishedDate: &time1},
				{Title: "Episode 2", PublishedDate: &time2},
				{Title: "Episode 3", PublishedDate: &time3},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			episodes := make([]EpisodeData, len(tt.input))
			copy(episodes, tt.input)
			sortEpisodesByDate(episodes)

			for i := range episodes {
				if episodes[i].Title != tt.expected[i].Title {
					t.Errorf("sortEpisodesByDate() index %d = %v, want %v", i, episodes[i].Title, tt.expected[i].Title)
				}
			}
		})
	}
}
