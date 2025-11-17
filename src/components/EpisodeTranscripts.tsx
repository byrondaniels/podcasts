import { useState, useEffect } from 'react';
import { episodeService } from '../services/episodeService';
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
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [activeFilter, setActiveFilter] = useState<TranscriptStatus | 'all'>('all');
  const [selectedEpisode, setSelectedEpisode] = useState<Episode | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);

  useEffect(() => {
    fetchEpisodes();
  }, [currentPage, activeFilter]);

  const fetchEpisodes = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await episodeService.getEpisodes({
        status: activeFilter,
        page: currentPage,
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
  };

  const handleFilterChange = (filter: TranscriptStatus | 'all') => {
    setActiveFilter(filter);
    setCurrentPage(1); // Reset to first page when filter changes
  };

  const handlePageChange = (page: number) => {
    setCurrentPage(page);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleViewTranscript = (episode: Episode) => {
    setSelectedEpisode(episode);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    // Don't clear selectedEpisode immediately to allow smooth transition
    setTimeout(() => setSelectedEpisode(null), 300);
  };

  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const formatDuration = (minutes: number): string => {
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (hours > 0) {
      return `${hours}h ${mins}m`;
    }
    return `${mins}m`;
  };

  const getStatusBadgeClass = (status: TranscriptStatus): string => {
    switch (status) {
      case 'completed':
        return 'status-badge status-completed';
      case 'processing':
        return 'status-badge status-processing';
      case 'failed':
        return 'status-badge status-failed';
      default:
        return 'status-badge';
    }
  };

  const getStatusIcon = (status: TranscriptStatus) => {
    switch (status) {
      case 'completed':
        return (
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
          </svg>
        );
      case 'processing':
        return (
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        );
      case 'failed':
        return (
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        );
    }
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

  const renderPagination = () => {
    if (totalPages <= 1) return null;

    const pages: (number | string)[] = [];
    const showEllipsis = totalPages > 7;

    if (!showEllipsis) {
      // Show all pages if 7 or fewer
      for (let i = 1; i <= totalPages; i++) {
        pages.push(i);
      }
    } else {
      // Always show first page
      pages.push(1);

      if (currentPage > 3) {
        pages.push('...');
      }

      // Show pages around current page
      for (let i = Math.max(2, currentPage - 1); i <= Math.min(totalPages - 1, currentPage + 1); i++) {
        pages.push(i);
      }

      if (currentPage < totalPages - 2) {
        pages.push('...');
      }

      // Always show last page
      pages.push(totalPages);
    }

    return (
      <div className="pagination">
        <button
          onClick={() => handlePageChange(currentPage - 1)}
          disabled={currentPage === 1}
          className="pagination-button pagination-prev"
          aria-label="Previous page"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
          Previous
        </button>

        <div className="pagination-pages">
          {pages.map((page, index) =>
            typeof page === 'number' ? (
              <button
                key={index}
                onClick={() => handlePageChange(page)}
                className={`pagination-page ${currentPage === page ? 'active' : ''}`}
              >
                {page}
              </button>
            ) : (
              <span key={index} className="pagination-ellipsis">
                {page}
              </span>
            )
          )}
        </div>

        <button
          onClick={() => handlePageChange(currentPage + 1)}
          disabled={currentPage === totalPages}
          className="pagination-button pagination-next"
          aria-label="Next page"
        >
          Next
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>
    );
  };

  return (
    <div className="episode-transcripts-container">
      <div className="episode-transcripts-header">
        <h1>Episode Transcripts</h1>
        <p>Browse and view transcripts from your subscribed podcasts</p>
      </div>

      {/* Filters */}
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

      {/* Error State */}
      {error && (
        <div className="episodes-error">
          <svg className="error-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p>{error}</p>
          <button onClick={fetchEpisodes} className="retry-button">
            Try Again
          </button>
        </div>
      )}

      {/* Episodes Grid */}
      {!error && (
        <>
          {isLoading ? (
            <div className="episodes-grid">{renderSkeletonCards()}</div>
          ) : episodes.length === 0 ? (
            <div className="episodes-empty-state">
              <svg className="empty-state-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
              </svg>
              <h3>No episodes found</h3>
              <p>
                {activeFilter === 'all'
                  ? 'Subscribe to podcasts to see their episodes here'
                  : `No ${activeFilter} episodes at the moment`}
              </p>
            </div>
          ) : (
            <>
              <div className="episodes-grid">
                {episodes.map((episode) => (
                  <div key={episode.episode_id} className="episode-card">
                    <div className="episode-header">
                      <h3 className="episode-title">{episode.episode_title}</h3>
                      <span className={getStatusBadgeClass(episode.transcript_status)}>
                        {getStatusIcon(episode.transcript_status)}
                        {episode.transcript_status}
                      </span>
                    </div>

                    <p className="podcast-name">{episode.podcast_title}</p>

                    <div className="episode-meta">
                      <span className="episode-date">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                        {formatDate(episode.published_date)}
                      </span>
                      <span className="episode-duration">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        {formatDuration(episode.duration_minutes)}
                      </span>
                    </div>

                    {episode.transcript_status === 'completed' && (
                      <button
                        onClick={() => handleViewTranscript(episode)}
                        className="view-transcript-button"
                      >
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                        </svg>
                        View Transcript
                      </button>
                    )}

                    {episode.transcript_status === 'processing' && (
                      <div className="processing-indicator">
                        <span className="spinner small"></span>
                        <span>Transcript processing...</span>
                      </div>
                    )}

                    {episode.transcript_status === 'failed' && (
                      <div className="failed-indicator">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <span>Transcript failed to process</span>
                      </div>
                    )}
                  </div>
                ))}
              </div>

              {/* Pagination */}
              {renderPagination()}

              {/* Results Summary */}
              <div className="results-summary">
                Showing {(currentPage - 1) * EPISODES_PER_PAGE + 1} to{' '}
                {Math.min(currentPage * EPISODES_PER_PAGE, total)} of {total} episodes
              </div>
            </>
          )}
        </>
      )}

      {/* Transcript Modal */}
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
