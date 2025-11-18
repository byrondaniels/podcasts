import { useState, useEffect, FormEvent } from 'react';
import { bulkTranscribeService, BulkTranscribeJob } from '../services/bulkTranscribeService';
import { validateUrl } from '../utils';
import { Alert, Button, Spinner, EmptyState, Icon, StatusBadge } from './shared';
import './BulkTranscriber.css';

export const BulkTranscriber = () => {
  const [rssUrl, setRssUrl] = useState('');
  const [maxEpisodes, setMaxEpisodes] = useState<string>('');
  const [jobs, setJobs] = useState<BulkTranscribeJob[]>([]);
  const [currentJob, setCurrentJob] = useState<BulkTranscribeJob | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isFetchingJobs, setIsFetchingJobs] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [validationError, setValidationError] = useState<string | null>(null);

  // Fetch jobs on mount
  useEffect(() => {
    fetchJobs();
  }, []);

  // Poll current job for updates
  useEffect(() => {
    if (!currentJob || ['completed', 'failed', 'cancelled'].includes(currentJob.status)) {
      return;
    }

    const interval = setInterval(async () => {
      try {
        const updated = await bulkTranscribeService.getJob(currentJob.job_id);
        setCurrentJob(updated);

        // If job completed, refresh job list
        if (['completed', 'failed', 'cancelled'].includes(updated.status)) {
          fetchJobs();
        }
      } catch (err) {
        console.error('Error polling job:', err);
      }
    }, 3000); // Poll every 3 seconds

    return () => clearInterval(interval);
  }, [currentJob]);

  const fetchJobs = async () => {
    setIsFetchingJobs(true);
    try {
      const result = await bulkTranscribeService.listJobs();
      setJobs(result.jobs);
    } catch (err) {
      console.error('Error fetching jobs:', err);
    } finally {
      setIsFetchingJobs(false);
    }
  };

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
      const maxEpisodesNum = maxEpisodes ? parseInt(maxEpisodes, 10) : undefined;
      const job = await bulkTranscribeService.startBulkTranscribe({
        rss_url: rssUrl,
        max_episodes: maxEpisodesNum,
      });

      setSuccessMessage(`Bulk transcription job started! Processing ${job.total_episodes} episodes.`);
      setCurrentJob(job);
      setRssUrl('');
      setMaxEpisodes('');
      fetchJobs();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to start bulk transcription');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancel = async (jobId: string) => {
    try {
      await bulkTranscribeService.cancelJob(jobId);
      setSuccessMessage('Job cancellation requested');
      fetchJobs();
      if (currentJob?.job_id === jobId) {
        setCurrentJob(null);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to cancel job');
    }
  };

  const handleViewJob = async (jobId: string) => {
    try {
      const job = await bulkTranscribeService.getJob(jobId);
      setCurrentJob(job);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load job details');
    }
  };

  const getStatusBadgeVariant = (status: string) => {
    switch (status) {
      case 'completed':
        return 'success';
      case 'failed':
        return 'error';
      case 'running':
      case 'processing':
        return 'warning';
      case 'cancelled':
        return 'default';
      default:
        return 'info';
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString();
  };

  const getProgressPercentage = (job: BulkTranscribeJob) => {
    if (job.total_episodes === 0) return 0;
    return Math.round((job.processed_episodes / job.total_episodes) * 100);
  };

  return (
    <div className="bulk-transcriber">
      <div className="bulk-transcriber-header">
        <h1>
          <Icon name="microphone" />
          Bulk Transcription (Dev Only)
        </h1>
        <p className="bulk-transcriber-description">
          Process all episodes from a podcast RSS feed using local Whisper transcription.
          This feature uses a containerized Whisper instance to avoid API costs.
        </p>
      </div>

      {error && <Alert variant="error" message={error} onClose={() => setError(null)} />}
      {successMessage && (
        <Alert variant="success" message={successMessage} onClose={() => setSuccessMessage(null)} />
      )}

      <div className="bulk-transcriber-content">
        {/* Start New Job Form */}
        <div className="bulk-transcriber-form-section">
          <h2>Start New Job</h2>
          <form onSubmit={handleSubmit} className="bulk-transcriber-form">
            <div className="form-group">
              <label htmlFor="rss-url">RSS Feed URL</label>
              <input
                type="url"
                id="rss-url"
                value={rssUrl}
                onChange={(e) => {
                  setRssUrl(e.target.value);
                  setValidationError(null);
                }}
                placeholder="https://example.com/podcast/feed.rss"
                required
                disabled={isLoading}
                className={validationError ? 'input-error' : ''}
              />
              {validationError && <p className="error-text">{validationError}</p>}
            </div>

            <div className="form-group">
              <label htmlFor="max-episodes">Max Episodes (optional)</label>
              <input
                type="number"
                id="max-episodes"
                value={maxEpisodes}
                onChange={(e) => setMaxEpisodes(e.target.value)}
                placeholder="Leave empty to process all"
                min="1"
                disabled={isLoading}
              />
              <p className="help-text">Limit the number of episodes to process (default: all)</p>
            </div>

            <Button
              type="submit"
              variant="primary"
              disabled={isLoading || !rssUrl}
              isLoading={isLoading}
            >
              {isLoading ? 'Starting...' : 'Start Bulk Transcription'}
            </Button>
          </form>
        </div>

        {/* Current Job Progress */}
        {currentJob && (
          <div className="current-job-section">
            <h2>Current Job Progress</h2>
            <div className="job-card current">
              <div className="job-header">
                <div>
                  <h3>{currentJob.rss_url}</h3>
                  <p className="job-meta">
                    Job ID: {currentJob.job_id} • Started: {formatDate(currentJob.created_at)}
                  </p>
                </div>
                <StatusBadge
                  status={currentJob.status}
                  variant={getStatusBadgeVariant(currentJob.status)}
                />
              </div>

              <div className="job-progress">
                <div className="progress-bar-container">
                  <div
                    className="progress-bar"
                    style={{ width: `${getProgressPercentage(currentJob)}%` }}
                  />
                </div>
                <div className="progress-stats">
                  <span>
                    {currentJob.processed_episodes} / {currentJob.total_episodes} episodes (
                    {getProgressPercentage(currentJob)}%)
                  </span>
                  <span className="success-count">✓ {currentJob.successful_episodes}</span>
                  {currentJob.failed_episodes > 0 && (
                    <span className="error-count">✗ {currentJob.failed_episodes}</span>
                  )}
                </div>
              </div>

              {currentJob.current_episode && (
                <div className="current-episode">
                  <Icon name="play" />
                  <span>Processing: {currentJob.current_episode}</span>
                </div>
              )}

              {currentJob.episodes && currentJob.episodes.length > 0 && (
                <div className="episode-list">
                  <h4>Episode Details</h4>
                  <div className="episode-items">
                    {currentJob.episodes.map((episode, idx) => (
                      <div key={idx} className="episode-item">
                        <StatusBadge
                          status={episode.status}
                          variant={getStatusBadgeVariant(episode.status)}
                        />
                        <span className="episode-title">{episode.title}</span>
                        {episode.error_message && (
                          <span className="episode-error">{episode.error_message}</span>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {currentJob.status === 'running' && (
                <Button
                  variant="danger"
                  onClick={() => handleCancel(currentJob.job_id)}
                  className="cancel-button"
                >
                  Cancel Job
                </Button>
              )}
            </div>
          </div>
        )}

        {/* Job History */}
        <div className="job-history-section">
          <h2>
            Job History
            {isFetchingJobs && <Spinner size="small" />}
          </h2>

          {jobs.length === 0 ? (
            <EmptyState
              icon="inbox"
              title="No jobs yet"
              message="Start a bulk transcription job to see it here"
            />
          ) : (
            <div className="job-list">
              {jobs.map((job) => (
                <div key={job.job_id} className="job-card">
                  <div className="job-header">
                    <div>
                      <h3>{job.rss_url}</h3>
                      <p className="job-meta">
                        {formatDate(job.created_at)} •{' '}
                        {job.processed_episodes}/{job.total_episodes} episodes
                      </p>
                    </div>
                    <StatusBadge
                      status={job.status}
                      variant={getStatusBadgeVariant(job.status)}
                    />
                  </div>

                  <div className="job-stats">
                    <span>✓ {job.successful_episodes} successful</span>
                    <span>✗ {job.failed_episodes} failed</span>
                  </div>

                  <div className="job-actions">
                    <Button
                      variant="secondary"
                      size="small"
                      onClick={() => handleViewJob(job.job_id)}
                    >
                      View Details
                    </Button>
                    {job.status === 'running' && (
                      <Button
                        variant="danger"
                        size="small"
                        onClick={() => handleCancel(job.job_id)}
                      >
                        Cancel
                      </Button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
