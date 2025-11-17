import { useEffect, useState, useCallback } from 'react';
import { episodeService } from '../services/episodeService';
import { useClipboard } from '../hooks';
import { Button, Spinner, Icon } from './shared';
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
  const { isCopied, copy } = useClipboard();

  const fetchTranscript = useCallback(async () => {
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
  }, [episode.episode_id]);

  useEffect(() => {
    if (isOpen && !transcript) {
      fetchTranscript();
    }
  }, [isOpen, transcript, fetchTranscript]);

  useEffect(() => {
    if (!isOpen) return;

    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };

    document.body.style.overflow = 'hidden';
    document.addEventListener('keydown', handleEscape);

    return () => {
      document.body.style.overflow = 'unset';
      document.removeEventListener('keydown', handleEscape);
    };
  }, [isOpen, onClose]);

  const handleCopyToClipboard = () => {
    if (transcript) {
      copy(transcript);
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
            <Icon name="close" />
          </button>
        </div>

        <div className="transcript-modal-content">
          {isLoading && (
            <div className="transcript-loading">
              <Spinner size="large" />
              <p>Loading transcript...</p>
            </div>
          )}

          {error && (
            <div className="transcript-error">
              <Icon name="error" className="transcript-error-icon" />
              <p>{error}</p>
              <Button onClick={fetchTranscript} variant="secondary">
                Try Again
              </Button>
            </div>
          )}

          {transcript && !isLoading && !error && (
            <>
              <div className="transcript-actions">
                <Button
                  onClick={handleCopyToClipboard}
                  variant={isCopied ? 'secondary' : 'primary'}
                  leftIcon={<Icon name={isCopied ? 'check' : 'copy'} size={20} />}
                >
                  {isCopied ? 'Copied!' : 'Copy to Clipboard'}
                </Button>
              </div>
              <div className="transcript-text">{transcript}</div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};
