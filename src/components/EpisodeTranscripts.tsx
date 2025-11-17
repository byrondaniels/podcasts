import { useState, useEffect, useCallback } from 'react';
import { episodeService } from '../services/episodeService';
import { formatDate, formatDuration } from '../utils';
import { usePagination } from '../hooks';
import { Button, Spinner, EmptyState, StatusBadge, Icon, Pagination } from './shared';
import { TranscriptModal } from './TranscriptModal';
import type { Episode, TranscriptStatus, EpisodeFilter } from '../types/episode';
import './EpisodeTranscripts.css';

const EPISODES_PER_PAGE = 20;

const FILTERS: EpisodeFilter[] = [
  { label: 'All', value: 'all' },
  { label: 'Completed', value: 'completed' },
  { label: 'Processing', value: 'processing' },
];

export const EpisodeTranscripts = () => {
  const [episodes, setEpisodes] = useState<Episode[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  const [activeFilter, setActiveFilter] = useState<TranscriptStatus | 'all'>('all');
  const [selectedEpisode, setSelectedEpisode] = useState<Episode | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const pagination = usePagination({
    totalItems: total,
    itemsPerPage: EPISODES_PER_PAGE,
    initialPage: 1,
  });

  const fetchEpisodes = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await episodeService.getEpisodes({
        status: activeFilter,
        page: pagination.currentPage,
        limit: EPISODES_PER_PAGE,
      });

      setEpisodes(response.episodes);
      setTotal(response.total);
      setTotalPages(response.totalPages);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load episodes');
    } finally {
      setIsLoading(false);
    }
  }, [activeFilter, pagination.currentPage]);

  useEffect(() => {
    fetchEpisodes();
  }, [fetchEpisodes]);

  const handleFilterChange = (filter: TranscriptStatus | 'all') => {
    setActiveFilter(filter);
    pagination.goToPage(1);
  };

  const handleViewTranscript = (episode: Episode) => {
    setSelectedEpisode(episode);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setTimeout(() => setSelectedEpisode(null), 300);
  };

  const renderSkeletonCards = () => {
    return Array.from({ length: 6 }).map((_, index) => (
      <div key={index} className="episode-card skeleton">
        <div className="skeleton-line skeleton-title"></div>
        <div className="skeleton-line skeleton-subtitle"></div>
        <div className="skeleton-line skeleton-meta"></div>
        <div className="skeleton-line skeleton-button"></div>
      </div>
    ));
  };

  const renderEpisodeActions = (episode: Episode) => {
    switch (episode.transcript_status) {
      case 'completed':
        return (
          <Button
            onClick={() => handleViewTranscript(episode)}
            variant="primary"
            leftIcon={<Icon name="eye" size={20} />}
            className="view-transcript-button"
          >
            View Transcript
          </Button>
        );
      case 'processing':
        return (
          <div className="processing-indicator">
            <Spinner size="small" />
            <span>Transcript processing...</span>
          </div>
        );
      case 'failed':
        return (
          <div className="failed-indicator">
            <Icon name="error" size={16} />
            <span>Transcript failed to process</span>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="episode-transcripts-container">
      <div className="episode-transcripts-header">
        <h1>Episode Transcripts</h1>
        <p>Browse and view transcripts from your subscribed podcasts</p>
      </div>

      <div className="filters-container">
        <div className="filters">
          {FILTERS.map((filter) => (
            <button
              key={filter.value}
              onClick={() => handleFilterChange(filter.value)}
              className={`filter-button ${activeFilter === filter.value ? 'active' : ''}`}
            >
              {filter.label}
              {!isLoading && activeFilter === filter.value && (
                <span className="filter-count">({total})</span>
              )}
            </button>
          ))}
        </div>
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
            <div className="episodes-grid">{renderSkeletonCards()}</div>
          ) : episodes.length === 0 ? (
            <EmptyState
              icon={<Icon name="podcast" size={80} />}
              title="No episodes found"
              description={
                activeFilter === 'all'
                  ? 'Subscribe to podcasts to see their episodes here'
                  : `No ${activeFilter} episodes at the moment`
              }
            />
          ) : (
            <>
              <div className="episodes-grid">
                {episodes.map((episode) => (
                  <div key={episode.episode_id} className="episode-card">
                    <div className="episode-header">
                      <h3 className="episode-title">{episode.episode_title}</h3>
                      <StatusBadge status={episode.transcript_status} />
                    </div>

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

                    {renderEpisodeActions(episode)}
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
