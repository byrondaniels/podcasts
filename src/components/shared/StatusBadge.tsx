import type { TranscriptStatus } from '../../types/episode';
import './StatusBadge.css';

interface StatusBadgeProps {
  status: TranscriptStatus;
}

const statusIcons: Record<TranscriptStatus, JSX.Element> = {
  completed: (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
    </svg>
  ),
  processing: (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  ),
  failed: (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M6 18L18 6M6 6l12 12"
      />
    </svg>
  ),
};

export const StatusBadge = ({ status }: StatusBadgeProps) => {
  return (
    <span className={`status-badge status-${status}`}>
      {statusIcons[status]}
      {status}
    </span>
  );
};
