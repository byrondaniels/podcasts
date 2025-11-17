import { useState, useEffect, FormEvent } from 'react';
import { podcastService } from '../services/podcastService';
import type { Podcast } from '../types/podcast';
import './PodcastSubscription.css';

export const PodcastSubscription = () => {
  const [rssUrl, setRssUrl] = useState('');
  const [podcasts, setPodcasts] = useState<Podcast[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isFetchingPodcasts, setIsFetchingPodcasts] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [validationError, setValidationError] = useState<string | null>(null);

  // Fetch podcasts on component mount
  useEffect(() => {
    fetchPodcasts();
  }, []);

  const fetchPodcasts = async () => {
    setIsFetchingPodcasts(true);
    setError(null);
    try {
      const fetchedPodcasts = await podcastService.getPodcasts();
      setPodcasts(fetchedPodcasts);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load podcasts');
    } finally {
      setIsFetchingPodcasts(false);
    }
  };

  const validateRssUrl = (url: string): boolean => {
    if (!url.trim()) {
      setValidationError('RSS feed URL is required');
      return false;
    }

    try {
      const urlObj = new URL(url);
      if (!['http:', 'https:'].includes(urlObj.protocol)) {
        setValidationError('URL must start with http:// or https://');
        return false;
      }
    } catch {
      setValidationError('Please enter a valid URL');
      return false;
    }

    setValidationError(null);
    return true;
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    if (!validateRssUrl(rssUrl)) {
      return;
    }

    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);

    try {
      const result = await podcastService.subscribe(rssUrl);
      setSuccessMessage(`Successfully subscribed to "${result.title}"!`);
      setRssUrl('');
      // Refresh the podcast list
      await fetchPodcasts();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to subscribe to podcast');
    } finally {
      setIsLoading(false);
    }
  };

  const handleUnsubscribe = async (podcastId: string, title: string) => {
    if (!window.confirm(`Are you sure you want to unsubscribe from "${title}"?`)) {
      return;
    }

    setError(null);
    setSuccessMessage(null);

    try {
      await podcastService.unsubscribe(podcastId);
      setSuccessMessage(`Successfully unsubscribed from "${title}"`);
      // Refresh the podcast list
      await fetchPodcasts();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to unsubscribe from podcast');
    }
  };

  const handleInputChange = (value: string) => {
    setRssUrl(value);
    if (validationError) {
      setValidationError(null);
    }
    if (error) {
      setError(null);
    }
    if (successMessage) {
      setSuccessMessage(null);
    }
  };

  return (
    <div className="podcast-subscription-container">
      <div className="podcast-subscription-header">
        <h1>Podcast Subscriptions</h1>
        <p>Subscribe to your favorite podcasts using their RSS feed URLs</p>
      </div>

      {/* Subscribe Form */}
      <div className="subscribe-form-container">
        <form onSubmit={handleSubmit} className="subscribe-form">
          <div className="form-group">
            <label htmlFor="rss-url" className="form-label">
              RSS Feed URL
            </label>
            <div className="input-button-group">
              <input
                id="rss-url"
                type="text"
                value={rssUrl}
                onChange={(e) => handleInputChange(e.target.value)}
                placeholder="https://example.com/podcast/feed.xml"
                className={`form-input ${validationError ? 'input-error' : ''}`}
                disabled={isLoading}
              />
              <button
                type="submit"
                disabled={isLoading || !rssUrl.trim()}
                className="subscribe-button"
              >
                {isLoading ? (
                  <>
                    <span className="spinner"></span>
                    Subscribing...
                  </>
                ) : (
                  'Subscribe'
                )}
              </button>
            </div>
            {validationError && (
              <p className="error-message validation-error">{validationError}</p>
            )}
          </div>
        </form>
      </div>

      {/* Status Messages */}
      {error && (
        <div className="alert alert-error">
          <svg className="alert-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span>{error}</span>
        </div>
      )}

      {successMessage && (
        <div className="alert alert-success">
          <svg className="alert-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span>{successMessage}</span>
        </div>
      )}

      {/* Podcasts List */}
      <div className="podcasts-section">
        <h2>My Podcasts</h2>

        {isFetchingPodcasts ? (
          <div className="loading-container">
            <span className="spinner large"></span>
            <p>Loading podcasts...</p>
          </div>
        ) : podcasts.length === 0 ? (
          <div className="empty-state">
            <svg className="empty-state-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
            </svg>
            <h3>No podcasts yet</h3>
            <p>Subscribe to your first podcast using the form above!</p>
          </div>
        ) : (
          <div className="podcasts-grid">
            {podcasts.map((podcast) => (
              <div key={podcast.podcast_id} className="podcast-card">
                <div className="podcast-image-container">
                  {podcast.image_url ? (
                    <img
                      src={podcast.image_url}
                      alt={`${podcast.title} cover`}
                      className="podcast-image"
                      onError={(e) => {
                        e.currentTarget.src = 'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="200" height="200"%3E%3Crect fill="%23ddd" width="200" height="200"/%3E%3Ctext fill="%23999" font-family="sans-serif" font-size="20" dy="100" dx="50"%3ENo Image%3C/text%3E%3C/svg%3E';
                      }}
                    />
                  ) : (
                    <div className="podcast-image-placeholder">
                      <svg fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                      </svg>
                    </div>
                  )}
                </div>
                <div className="podcast-content">
                  <h3 className="podcast-title">{podcast.title}</h3>
                  <p className="podcast-description">{podcast.description}</p>
                  <div className="podcast-footer">
                    <a
                      href={podcast.rss_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="rss-link"
                    >
                      <svg className="rss-icon" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M6.503 20.752c0 1.794-1.456 3.248-3.251 3.248-1.796 0-3.252-1.454-3.252-3.248 0-1.794 1.456-3.248 3.252-3.248 1.795.001 3.251 1.454 3.251 3.248zm-6.503-12.572v4.811c6.05.062 10.96 4.966 11.022 11.009h4.817c-.062-8.71-7.118-15.758-15.839-15.82zm0-3.368c10.58.046 19.152 8.594 19.183 19.188h4.817c-.03-13.231-10.755-23.954-24-24v4.812z"/>
                      </svg>
                      RSS Feed
                    </a>
                    <button
                      onClick={() => handleUnsubscribe(podcast.podcast_id, podcast.title)}
                      className="unsubscribe-button"
                    >
                      Unsubscribe
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
