import type {
  GetEpisodesParams,
  GetEpisodesResponse,
  TranscriptResponse,
} from '../types/episode';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api';

class EpisodeService {
  /**
   * Get episodes with optional filtering and pagination
   */
  async getEpisodes(params: GetEpisodesParams = {}): Promise<GetEpisodesResponse> {
    const { status = 'all', page = 1, limit = 20 } = params;

    const queryParams = new URLSearchParams({
      page: page.toString(),
      limit: limit.toString(),
    });

    // Only add status filter if it's not 'all'
    if (status !== 'all') {
      queryParams.append('status', status);
    }

    try {
      const response = await fetch(`${API_BASE_URL}/episodes?${queryParams.toString()}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({
          message: 'Failed to fetch episodes',
        }));
        throw new Error(errorData.message || 'Failed to fetch episodes');
      }

      const data: GetEpisodesResponse = await response.json();

      // Calculate total pages if not provided by API
      const totalPages = data.totalPages || Math.ceil(data.total / (data.limit || limit));

      return {
        ...data,
        totalPages,
      };
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred while fetching episodes');
    }
  }

  /**
   * Get transcript for a specific episode
   */
  async getTranscript(episodeId: string): Promise<string> {
    try {
      const response = await fetch(`${API_BASE_URL}/episodes/${episodeId}/transcript`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({
          message: 'Failed to fetch transcript',
        }));
        throw new Error(errorData.message || 'Failed to fetch transcript');
      }

      const data: TranscriptResponse = await response.json();
      return data.transcript;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred while fetching transcript');
    }
  }

  /**
   * Trigger transcription for a specific episode
   */
  async triggerTranscription(episodeId: string): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/episodes/${episodeId}/transcribe`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({
          detail: 'Failed to trigger transcription',
        }));
        throw new Error(errorData.detail || 'Failed to trigger transcription');
      }
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred while triggering transcription');
    }
  }

  /**
   * Retry transcription for a failed episode
   */
  async retryTranscription(episodeId: string): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/transcription/retry/${episodeId}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({
          detail: 'Failed to retry transcription',
        }));
        throw new Error(errorData.detail || 'Failed to retry transcription');
      }
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred while retrying transcription');
    }
  }
}

export const episodeService = new EpisodeService();
