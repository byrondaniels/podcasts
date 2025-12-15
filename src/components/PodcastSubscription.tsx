import { useState, useEffect, FormEvent, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { podcastService } from '../services/podcastService';
import { validateUrl } from '../utils';
import { Alert, Button, Spinner, EmptyState, Icon } from './shared';
import type { Podcast } from '../types/podcast';
import './PodcastSubscription.css';

export const PodcastSubscription = () => {
  const navigate = useNavigate();
  const [rssUrl, setRssUrl] = useState('');
  const [podcasts, setPodcasts] = useState<Podcast[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isFetchingPodcasts, setIsFetchingPodcasts] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [validationError, setValidationError] = useState<string | null>(null);

  const fetchPodcasts = useCallback(async () => {
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
  }, []);

  useEffect(() => {
    fetchPodcasts();
  }, [fetchPodcasts]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();

    const validation = validateUrl(rssUrl);
    if (!validation.isValid) {
      setValidationError(validation.error);
      return;
    }

    setIsLoading(true);
    setError(null);
    setSuccessMessage(null);
    setValidationError(null);

    try {
      const result = await podcastService.subscribe(rssUrl);
      const episodeInfo = result.episode_count
        ? ` Found ${result.episode_count} episode${result.episode_count === 1 ? '' : 's'} available for transcription.`
        : '';
      setSuccessMessage(`Successfully subscribed to "${result.title}"!${episodeInfo}`);
      setRssUrl('');
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
      await fetchPodcasts();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to unsubscribe from podcast');
    }
  };

  const handleInputChange = (value: string) => {
    setRssUrl(value);
    setValidationError(null);
    setError(null);
    setSuccessMessage(null);
  };

  const handleViewTranscripts = (podcastId: string) => {
    navigate(`/transcripts?podcast=${podcastId}`);
  };

  return (
    <div className="podcast-subscription-container">
      <div className="podcast-subscription-header">
        <h1>Podcast Subscriptions</h1>
        <p>Subscribe to your favorite podcasts using their RSS feed URLs</p>
      </div>

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
              <Button
                type="submit"
                disabled={isLoading || !rssUrl.trim()}
                isLoading={isLoading}
                className="subscribe-button"
              >
                {isLoading ? 'Subscribing...' : 'Subscribe'}
              </Button>
            </div>
            {validationError && (
              <p className="error-message validation-error">{validationError}</p>
            )}
          </div>
        </form>
      </div>

      {error && <Alert variant="error">{error}</Alert>}
      {successMessage && <Alert variant="success">{successMessage}</Alert>}

      <div className="podcasts-section">
        <h2>My Podcasts</h2>

        {isFetchingPodcasts ? (
          <div className="loading-container">
            <Spinner size="large" />
            <p>Loading podcasts...</p>
          </div>
        ) : podcasts.length === 0 ? (
          <EmptyState
            icon={<Icon name="podcast" size={80} />}
            title="No podcasts yet"
            description="Subscribe to your first podcast using the form above!"
          />
        ) : (
          <div className="podcasts-grid">
            {podcasts.map((podcast) => (
              <div key={podcast.podcast_id} className="podcast-card">
                <div
                  className="podcast-image-container clickable"
                  onClick={() => handleViewTranscripts(podcast.podcast_id)}
                  role="button"
                  tabIndex={0}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      handleViewTranscripts(podcast.podcast_id);
                    }
                  }}
                >
                  {podcast.image_url ? (
                    <img
                      src={podcast.image_url}
                      alt={`${podcast.title} cover`}
                      className="podcast-image"
                      onError={(e) => {
                        e.currentTarget.src =
                          'data:image/svg+xml,%3Csvg xmlns="http://www.w3.org/2000/svg" width="200" height="200"%3E%3Crect fill="%23ddd" width="200" height="200"/%3E%3Ctext fill="%23999" font-family="sans-serif" font-size="20" dy="100" dx="50"%3ENo Image%3C/text%3E%3C/svg%3E';
                      }}
                    />
                  ) : (
                    <div className="podcast-image-placeholder">
                      <Icon name="podcast" />
                    </div>
                  )}
                </div>
                <div className="podcast-content">
                  <h3
                    className="podcast-title clickable"
                    onClick={() => handleViewTranscripts(podcast.podcast_id)}
                    role="button"
                    tabIndex={0}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        handleViewTranscripts(podcast.podcast_id);
                      }
                    }}
                  >
                    {podcast.title}
                  </h3>
                  <p className="podcast-description">{podcast.description}</p>
                  {podcast.episode_count !== undefined && (
                    <p className="podcast-episode-count">
                      <Icon name="document" size={16} />
                      {podcast.episode_count} episode{podcast.episode_count === 1 ? '' : 's'}
                    </p>
                  )}
                  <div className="podcast-actions">
                    <Button
                      onClick={() => handleViewTranscripts(podcast.podcast_id)}
                      variant="primary"
                      size="small"
                    >
                      View Transcripts
                    </Button>
                    <div className="podcast-footer">
                      <a
                        href={podcast.rss_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="rss-link"
                      >
                        <Icon name="rss" className="rss-icon" size={16} />
                        RSS Feed
                      </a>
                      <Button
                        onClick={() => handleUnsubscribe(podcast.podcast_id, podcast.title)}
                        variant="danger"
                        size="small"
                      >
                        Unsubscribe
                      </Button>
                    </div>
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
