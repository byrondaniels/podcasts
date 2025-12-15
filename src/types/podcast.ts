export interface Podcast {
  podcast_id: string;
  title: string;
  description: string;
  image_url: string;
  rss_url: string;
  episode_count?: number;
}

export interface SubscribeRequest {
  rss_url: string;
}

export interface SubscribeResponse {
  podcast_id: string;
  title: string;
  status: 'subscribed';
  episode_count?: number;
}

export interface GetPodcastsResponse {
  podcasts: Podcast[];
}

export interface ApiError {
  message: string;
  error?: string;
}
