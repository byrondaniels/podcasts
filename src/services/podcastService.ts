import type {
  Podcast,
  SubscribeRequest,
  SubscribeResponse,
  GetPodcastsResponse,
} from '../types/podcast';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api';

class PodcastService {
  /**
   * Subscribe to a podcast using its RSS feed URL
   */
  async subscribe(rssUrl: string): Promise<SubscribeResponse> {
    try {
      const response = await fetch(`${API_BASE_URL}/podcasts/subscribe`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ rss_url: rssUrl } as SubscribeRequest),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({
          message: 'Failed to subscribe to podcast',
        }));
        throw new Error(errorData.message || 'Failed to subscribe to podcast');
      }

      const data: SubscribeResponse = await response.json();
      return data;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred while subscribing');
    }
  }

  /**
   * Get all subscribed podcasts
   */
  async getPodcasts(): Promise<Podcast[]> {
    try {
      const response = await fetch(`${API_BASE_URL}/podcasts`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({
          message: 'Failed to fetch podcasts',
        }));
        throw new Error(errorData.message || 'Failed to fetch podcasts');
      }

      const data: GetPodcastsResponse = await response.json();
      return data.podcasts;
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred while fetching podcasts');
    }
  }

  /**
   * Unsubscribe from a podcast
   */
  async unsubscribe(podcastId: string): Promise<void> {
    try {
      const response = await fetch(`${API_BASE_URL}/podcasts/${podcastId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({
          message: 'Failed to unsubscribe from podcast',
        }));
        throw new Error(errorData.message || 'Failed to unsubscribe from podcast');
      }
    } catch (error) {
      if (error instanceof Error) {
        throw error;
      }
      throw new Error('An unexpected error occurred while unsubscribing');
    }
  }
}

export const podcastService = new PodcastService();
