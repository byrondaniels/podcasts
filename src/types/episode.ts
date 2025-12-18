export type TranscriptStatus = 'pending' | 'processing' | 'completed' | 'failed';
export type ProcessingStep = 'downloading' | 'chunking' | 'transcribing' | 'merging' | 'completed';

export interface Episode {
  episode_id: string;
  podcast_id: string;
  podcast_title: string;
  episode_title: string;
  published_date: string; // ISO 8601 format
  duration_minutes: number;
  transcript_status: TranscriptStatus;
  processing_step?: ProcessingStep;
  transcript_s3_key?: string;
}

export interface GetEpisodesParams {
  status?: TranscriptStatus | 'all';
  page?: number;
  limit?: number;
}

export interface GetEpisodesResponse {
  episodes: Episode[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface TranscriptResponse {
  transcript: string;
}

export interface EpisodeFilter {
  label: string;
  value: TranscriptStatus | 'all';
}
