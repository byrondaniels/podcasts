import { useEffect, useState } from 'react';
import { episodeService } from '../services/episodeService';
import type { Episode } from '../types/episode';
import './TranscriptModal.css';

interface TranscriptModalProps {
  episode: Episode;
  isOpen: boolean;
  onClose: () => void;
}

export const TranscriptModal = ({ episode, isOpen, onClose }: TranscriptModalProps) => {
  const [transcript, setTranscript] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [copySuccess, setCopySuccess] = useState(false);

  useEffect(() => {
    if (isOpen && !transcript) {
      fetchTranscript();
    }
  }, [isOpen, episode.episode_id]);

  useEffect(() => {
    // Handle ESC key to close modal
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose();
      }
    };

    // Prevent body scroll when modal is open
    if (isOpen) {
      document.body.style.overflow = 'hidden';
      document.addEventListener('keydown', handleEscape);
    }

    return () => {
      document.body.style.overflow = 'unset';
      document.removeEventListener('keydown', handleEscape);
    };
  }, [isOpen, onClose]);

  const fetchTranscript = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const transcriptText = await episodeService.getTranscript(episode.episode_id);
      setTranscript(transcriptText);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load transcript');
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopyToClipboard = async () => {
    if (!transcript) return;

    try {
      await navigator.clipboard.writeText(transcript);
      setCopySuccess(true);
      setTimeout(() => setCopySuccess(false), 2000);
    } catch (err) {
      console.error('Failed to copy transcript:', err);
    }
  };

  const handleBackdropClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <div className="transcript-modal-backdrop" onClick={handleBackdropClick}>
      <div className="transcript-modal">
        {/* Modal Header */}
        <div className="transcript-modal-header">
          <div className="transcript-modal-title-section">
            <h2 className="transcript-modal-title">{episode.episode_title}</h2>
            <p className="transcript-modal-subtitle">{episode.podcast_title}</p>
          </div>
          <button
            onClick={onClose}
            className="transcript-modal-close-button"
            aria-label="Close modal"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {/* Modal Content */}
        <div className="transcript-modal-content">
          {isLoading && (
            <div className="transcript-loading">
              <span className="spinner large"></span>
              <p>Loading transcript...</p>
            </div>
          )}

          {error && (
            <div className="transcript-error">
              <svg className="transcript-error-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <p>{error}</p>
              <button onClick={fetchTranscript} className="transcript-retry-button">
                Try Again
              </button>
            </div>
          )}

          {transcript && !isLoading && !error && (
            <>
              <div className="transcript-actions">
                <button
                  onClick={handleCopyToClipboard}
                  className={`copy-button ${copySuccess ? 'copy-success' : ''}`}
                >
                  {copySuccess ? (
                    <>
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                      </svg>
                      Copied!
                    </>
                  ) : (
                    <>
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                      </svg>
                      Copy to Clipboard
                    </>
                  )}
                </button>
              </div>
              <div className="transcript-text">
                {transcript}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};
