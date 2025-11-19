package main

import (
	"testing"

	"github.com/mmcdole/gofeed"
)

func TestGenerateEpisodeID(t *testing.T) {
	tests := []struct {
		name     string
		audioURL string
	}{
		{
			name:     "standard URL",
			audioURL: "https://example.com/podcast.mp3",
		},
		{
			name:     "different URL",
			audioURL: "https://example.com/different.mp3",
		},
		{
			name:     "empty URL",
			audioURL: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := generateEpisodeID(tt.audioURL)
			if result == "" {
				t.Error("generateEpisodeID() returned empty string")
			}
			if len(result) != 64 {
				t.Errorf("generateEpisodeID() returned %d characters, want 64", len(result))
			}

			result2 := generateEpisodeID(tt.audioURL)
			if result != result2 {
				t.Error("generateEpisodeID() should return same ID for same URL")
			}
		})
	}
}

func TestGenerateEpisodeIDConsistency(t *testing.T) {
	url1 := "https://example.com/podcast.mp3"
	url2 := "https://example.com/different.mp3"

	id1 := generateEpisodeID(url1)
	id2 := generateEpisodeID(url2)

	if id1 == id2 {
		t.Error("Different URLs should generate different episode IDs")
	}

	id1Again := generateEpisodeID(url1)
	if id1 != id1Again {
		t.Error("Same URL should generate same episode ID")
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
					{
						URL:  "https://example.com/podcast.mp3",
						Type: "audio/mpeg",
					},
				},
			},
			expected: "https://example.com/podcast.mp3",
		},
		{
			name: "multiple enclosures, first is audio",
			item: &gofeed.Item{
				Enclosures: []*gofeed.Enclosure{
					{
						URL:  "https://example.com/podcast.mp3",
						Type: "audio/mpeg",
					},
					{
						URL:  "https://example.com/video.mp4",
						Type: "video/mp4",
					},
				},
			},
			expected: "https://example.com/podcast.mp3",
		},
		{
			name: "non-audio enclosure, fallback to link",
			item: &gofeed.Item{
				Enclosures: []*gofeed.Enclosure{
					{
						URL:  "https://example.com/image.jpg",
						Type: "image/jpeg",
					},
				},
				Link: "https://example.com/episode.html",
			},
			expected: "https://example.com/episode.html",
		},
		{
			name: "no enclosures, use link",
			item: &gofeed.Item{
				Link: "https://example.com/episode.html",
			},
			expected: "https://example.com/episode.html",
		},
		{
			name:     "no audio URL available",
			item:     &gofeed.Item{},
			expected: "",
		},
		{
			name: "audio type with short string",
			item: &gofeed.Item{
				Enclosures: []*gofeed.Enclosure{
					{
						URL:  "https://example.com/test.mp3",
						Type: "audio",
					},
				},
				Link: "https://example.com/fallback.html",
			},
			expected: "https://example.com/fallback.html",
		},
		{
			name: "various audio types",
			item: &gofeed.Item{
				Enclosures: []*gofeed.Enclosure{
					{
						URL:  "https://example.com/test.m4a",
						Type: "audio/mp4",
					},
				},
			},
			expected: "https://example.com/test.m4a",
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

func TestExtractAudioURLEdgeCases(t *testing.T) {
	t.Run("enclosure with empty type", func(t *testing.T) {
		item := &gofeed.Item{
			Enclosures: []*gofeed.Enclosure{
				{
					URL:  "https://example.com/podcast.mp3",
					Type: "",
				},
			},
			Link: "https://example.com/fallback.html",
		}
		result := extractAudioURL(item)
		if result != "https://example.com/fallback.html" {
			t.Errorf("Expected fallback to link, got %v", result)
		}
	})

	t.Run("nil enclosures slice", func(t *testing.T) {
		item := &gofeed.Item{
			Enclosures: nil,
			Link:       "https://example.com/link.html",
		}
		result := extractAudioURL(item)
		if result != "https://example.com/link.html" {
			t.Errorf("Expected link, got %v", result)
		}
	})
}
