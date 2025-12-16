import { useState, useEffect, useCallback } from 'react';
import { useSearchParams } from 'react-router-dom';
import { episodeService } from '../services/episodeService';
import { podcastService } from '../services/podcastService';
import { formatDate, formatDuration } from '../utils';
import { usePagination } from '../hooks';
import { Button, EmptyState, StatusBadge, Icon, Pagination } from './shared';
import { TranscriptModal } from './TranscriptModal';
import type { Episode, TranscriptStatus } from '../types/episode';
import type { Podcast } from '../types/podcast';
import './EpisodeTranscripts.css';

const EPISODES_PER_PAGE = 20;

export const EpisodeTranscripts = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const podcastIdFromUrl = searchParams.get('podcast');

  const [episodes, setEpisodes] = useState<Episode[]>([]);
  const [podcasts, setPodcasts] = useState<Podcast[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [statusFilter, setStatusFilter] = useState<TranscriptStatus | 'all'>('all');
  const [podcastFilter, setPodcastFilter] = useState<string>(podcastIdFromUrl || 'all');
  const [selectedEpisode, setSelectedEpisode] = useState<Episode | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const pagination = usePagination({
    totalItems: total,
    itemsPerPage: EPISODES_PER_PAGE,
    initialPage: 1,
  });

  const fetchPodcasts = useCallback(async () => {
    try {
      const podcastList = await podcastService.getPodcasts();
      setPodcasts(podcastList);
    } catch (err) {
      console.error('Failed to load podcasts:', err);
    }
  }, []);

  const fetchEpisodes = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await episodeService.getEpisodes({
        status: statusFilter,
        page: pagination.currentPage,
        limit: EPISODES_PER_PAGE,
      });

      let filteredEpisodes = response.episodes;

      if (podcastFilter !== 'all') {
        filteredEpisodes = filteredEpisodes.filter(
          (episode) => episode.podcast_id === podcastFilter
        );
      }

      setEpisodes(filteredEpisodes);
      setTotal(filteredEpisodes.length);
      setTotalPages(Math.ceil(filteredEpisodes.length / EPISODES_PER_PAGE));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load episodes');
    } finally {
      setIsLoading(false);
    }
  }, [statusFilter, podcastFilter, pagination.currentPage]);

  useEffect(() => {
    fetchPodcasts();
  }, [fetchPodcasts]);

  useEffect(() => {
    fetchEpisodes();
  }, [fetchEpisodes]);

  useEffect(() => {
    if (podcastIdFromUrl) {
      setPodcastFilter(podcastIdFromUrl);
    }
  }, [podcastIdFromUrl]);

  const handleStatusFilterChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setStatusFilter(e.target.value as TranscriptStatus | 'all');
    pagination.goToPage(1);
  };

  const handlePodcastFilterChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const newPodcastFilter = e.target.value;
    setPodcastFilter(newPodcastFilter);
    pagination.goToPage(1);

    if (newPodcastFilter === 'all') {
      searchParams.delete('podcast');
    } else {
      searchParams.set('podcast', newPodcastFilter);
    }
    setSearchParams(searchParams);
  };

  const handleViewTranscript = (episode: Episode) => {
    setSelectedEpisode(episode);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setTimeout(() => setSelectedEpisode(null), 300);
  };

  const handleDownloadTranscript = async (episode: Episode) => {
    try {
      // Update episode status to processing optimistically
      setEpisodes((prevEpisodes) =>
        prevEpisodes.map((ep) =>
          ep.episode_id === episode.episode_id
            ? { ...ep, transcript_status: 'processing' }
            : ep
        )
      );

      await episodeService.triggerTranscription(episode.episode_id);

      // Refresh episodes list to get updated status
      setTimeout(() => {
        fetchEpisodes();
      }, 1000);
    } catch (err) {
      console.error('Failed to trigger transcription:', err);
      // Revert optimistic update on error
      setEpisodes((prevEpisodes) =>
        prevEpisodes.map((ep) =>
          ep.episode_id === episode.episode_id
            ? { ...ep, transcript_status: episode.transcript_status }
            : ep
        )
      );
      setError(err instanceof Error ? err.message : 'Failed to trigger transcription');
    }
  };

  const renderSkeletonRows = () => {
    return Array.from({ length: 10 }).map((_, index) => (
      <div key={index} className="episode-row skeleton">
        <div className="episode-row-main">
          <div className="skeleton-line skeleton-title"></div>
          <div className="skeleton-line skeleton-subtitle"></div>
          <div className="skeleton-line skeleton-meta"></div>
        </div>
        <div className="episode-row-actions">
          <div className="skeleton-line skeleton-badge"></div>
          <div className="skeleton-line skeleton-button"></div>
        </div>
      </div>
    ));
  };

  return (
    <div className="episode-transcripts-container">
      <div className="episode-transcripts-header">
        <h1>Episode Transcripts</h1>
        <p>Browse and view transcripts from your subscribed podcasts</p>
      </div>

      <div className="filters-container">
        <div className="filter-group">
          <label htmlFor="status-filter" className="filter-label">
            Status
          </label>
          <select
            id="status-filter"
            value={statusFilter}
            onChange={handleStatusFilterChange}
            className="filter-select"
          >
            <option value="all">All Statuses</option>
            <option value="completed">Completed</option>
            <option value="processing">Processing</option>
            <option value="failed">Failed</option>
          </select>
        </div>

        <div className="filter-group">
          <label htmlFor="podcast-filter" className="filter-label">
            Podcast
          </label>
          <select
            id="podcast-filter"
            value={podcastFilter}
            onChange={handlePodcastFilterChange}
            className="filter-select"
          >
            <option value="all">All Podcasts</option>
            {podcasts.map((podcast) => (
              <option key={podcast.podcast_id} value={podcast.podcast_id}>
                {podcast.title}
              </option>
            ))}
          </select>
        </div>

        {!isLoading && (
          <div className="results-count">
            {total} {total === 1 ? 'episode' : 'episodes'}
          </div>
        )}
      </div>

      {error && (
        <div className="episodes-error">
          <Icon name="error" className="error-icon" />
          <p>{error}</p>
          <Button onClick={fetchEpisodes} variant="secondary">
            Try Again
          </Button>
        </div>
      )}

      {!error && (
        <>
          {isLoading ? (
            <div className="episodes-list">{renderSkeletonRows()}</div>
          ) : episodes.length === 0 ? (
            <EmptyState
              icon={<Icon name="podcast" size={80} />}
              title="No episodes found"
              description={
                statusFilter === 'all' && podcastFilter === 'all'
                  ? 'Subscribe to podcasts to see their episodes here'
                  : 'No episodes match the selected filters'
              }
            />
          ) : (
            <>
              <div className="episodes-list">
                {episodes.map((episode) => (
                  <div key={episode.episode_id} className="episode-row">
                    <div className="episode-row-main">
                      <h3 className="episode-title">{episode.episode_title}</h3>
                      <p className="podcast-name">{episode.podcast_title}</p>
                      <div className="episode-meta">
                        <span className="episode-date">
                          <Icon name="calendar" size={16} />
                          {formatDate(episode.published_date)}
                        </span>
                        <span className="episode-duration">
                          <Icon name="clock" size={16} />
                          {formatDuration(episode.duration_minutes)}
                        </span>
                      </div>
                    </div>

                    <div className="episode-row-actions">
                      <StatusBadge status={episode.transcript_status} />
                      {episode.transcript_status === 'completed' && (
                        <Button
                          onClick={() => handleViewTranscript(episode)}
                          variant="primary"
                          leftIcon={<Icon name="eye" size={20} />}
                          className="view-transcript-button"
                        >
                          View
                        </Button>
                      )}
                      {(episode.transcript_status === 'pending' || episode.transcript_status === 'failed') && (
                        <Button
                          onClick={() => handleDownloadTranscript(episode)}
                          variant="secondary"
                          leftIcon={<Icon name="download" size={20} />}
                          className="download-transcript-button"
                        >
                          Download Transcript
                        </Button>
                      )}
                    </div>
                  </div>
                ))}
              </div>

              <Pagination
                currentPage={pagination.currentPage}
                totalPages={totalPages}
                onPageChange={pagination.goToPage}
                pageNumbers={pagination.pageNumbers}
              />

              <div className="results-summary">
                Showing {pagination.startIndex + 1} to {Math.min(pagination.endIndex, total)} of{' '}
                {total} episodes
              </div>
            </>
          )}
        </>
      )}

      {selectedEpisode && (
        <TranscriptModal
          episode={selectedEpisode}
          isOpen={isModalOpen}
          onClose={handleCloseModal}
        />
      )}
    </div>
  );
};
