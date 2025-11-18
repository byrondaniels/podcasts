/**
 * Service for bulk transcription operations
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

export interface BulkTranscribeRequest {
  rss_url: string;
  max_episodes?: number;
}

export interface BulkTranscribeEpisodeProgress {
  episode_id: string;
  title: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  error_message?: string;
  started_at?: string;
  completed_at?: string;
}

export interface BulkTranscribeJob {
  job_id: string;
  rss_url: string;
  status: 'pending' | 'running' | 'paused' | 'completed' | 'failed' | 'cancelled';
  total_episodes: number;
  processed_episodes: number;
  successful_episodes: number;
  failed_episodes: number;
  created_at: string;
  updated_at: string;
  completed_at?: string;
  current_episode?: string;
  episodes?: BulkTranscribeEpisodeProgress[];
}

export interface BulkTranscribeJobList {
  jobs: BulkTranscribeJob[];
  total: number;
}

class BulkTranscribeService {
  /**
   * Start a new bulk transcription job
   */
  async startBulkTranscribe(request: BulkTranscribeRequest): Promise<BulkTranscribeJob> {
    const response = await fetch(`${API_URL}/api/dev/bulk-transcribe`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(request),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Failed to start bulk transcription');
    }

    return response.json();
  }

  /**
   * Get job status
   */
  async getJob(jobId: string): Promise<BulkTranscribeJob> {
    const response = await fetch(`${API_URL}/api/dev/bulk-transcribe/${jobId}`);

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Failed to fetch job status');
    }

    return response.json();
  }

  /**
   * List all jobs
   */
  async listJobs(limit: number = 50): Promise<BulkTranscribeJobList> {
    const response = await fetch(`${API_URL}/api/dev/bulk-transcribe?limit=${limit}`);

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Failed to fetch jobs');
    }

    return response.json();
  }

  /**
   * Cancel a job
   */
  async cancelJob(jobId: string): Promise<void> {
    const response = await fetch(`${API_URL}/api/dev/bulk-transcribe/${jobId}/cancel`, {
      method: 'POST',
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.detail || 'Failed to cancel job');
    }
  }
}

export const bulkTranscribeService = new BulkTranscribeService();
