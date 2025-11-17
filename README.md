# Podcast Manager

A modern React application for managing podcast subscriptions and viewing episode transcripts. Built with TypeScript, React hooks, and a clean, responsive UI.

## Features

### Podcast Subscriptions
- **Subscribe to Podcasts**: Add podcasts using their RSS feed URLs
- **View Subscriptions**: Display all subscribed podcasts with title, description, and thumbnail
- **Unsubscribe**: Remove podcasts from your subscription list
- **Form Validation**: Real-time validation for RSS feed URLs

### Episode Transcripts
- **Browse Episodes**: View episodes from all subscribed podcasts in reverse chronological order
- **Filter Episodes**: Filter by status (All, Completed, Processing)
- **Pagination**: Navigate through episodes with 20 per page
- **View Transcripts**: Read full episode transcripts in a modal viewer
- **Copy to Clipboard**: Easily copy transcript text for external use
- **Status Indicators**: Visual badges showing transcript processing status

### Common Features
- **Loading States**: Skeleton loaders and spinners during API calls
- **Error Handling**: User-friendly error messages with retry options
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices
- **Tab Navigation**: Easy switching between Subscriptions and Transcripts views

## Tech Stack

- **React 18** with TypeScript
- **Vite** for fast development and building
- **CSS3** with modern responsive design
- **Fetch API** for HTTP requests

## Project Structure

```
podcasts/
├── src/
│   ├── components/
│   │   ├── PodcastSubscription.tsx      # Podcast subscription component
│   │   ├── PodcastSubscription.css      # Subscription component styles
│   │   ├── EpisodeTranscripts.tsx       # Episode transcripts component
│   │   ├── EpisodeTranscripts.css       # Transcripts component styles
│   │   ├── TranscriptModal.tsx          # Modal for viewing transcripts
│   │   └── TranscriptModal.css          # Modal styles
│   ├── services/
│   │   ├── podcastService.ts            # Podcast API service
│   │   └── episodeService.ts            # Episode API service
│   ├── types/
│   │   ├── podcast.ts                   # Podcast type definitions
│   │   └── episode.ts                   # Episode type definitions
│   ├── App.tsx                          # Root component with navigation
│   ├── App.css                          # App and navigation styles
│   ├── main.tsx                         # Entry point
│   └── index.css                        # Global styles
├── index.html                           # HTML template
├── package.json                         # Dependencies
├── tsconfig.json                        # TypeScript config
└── vite.config.ts                       # Vite config
```

## Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd podcasts
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Configure environment variables**:
   ```bash
   cp .env.example .env
   ```

   Update `.env` with your API base URL:
   ```
   VITE_API_BASE_URL=http://localhost:3000/api
   ```

4. **Start the development server**:
   ```bash
   npm run dev
   ```

   The application will be available at `http://localhost:5173`

## API Endpoints

The application expects the following API endpoints:

### Podcast Endpoints

#### Subscribe to Podcast
```
POST /api/podcasts/subscribe
Content-Type: application/json

Request Body:
{
  "rss_url": "https://example.com/feed.xml"
}

Response:
{
  "podcast_id": "abc123",
  "title": "Podcast Name",
  "status": "subscribed"
}
```

#### Get All Podcasts
```
GET /api/podcasts

Response:
{
  "podcasts": [
    {
      "podcast_id": "abc123",
      "title": "Podcast Title",
      "description": "Podcast description",
      "image_url": "https://example.com/image.jpg",
      "rss_url": "https://example.com/feed.xml"
    }
  ]
}
```

#### Unsubscribe from Podcast
```
DELETE /api/podcasts/{podcast_id}

Response: 204 No Content or 200 OK
```

### Episode Endpoints

#### Get Episodes
```
GET /api/episodes?status=completed&page=1&limit=20

Query Parameters:
- status (optional): Filter by transcript status ("completed", "processing", "failed")
- page (optional): Page number (default: 1)
- limit (optional): Items per page (default: 20)

Response:
{
  "episodes": [
    {
      "episode_id": "ep123",
      "podcast_id": "abc123",
      "podcast_title": "Podcast Name",
      "episode_title": "Episode Title",
      "published_date": "2025-11-16T10:00:00Z",
      "duration_minutes": 45,
      "transcript_status": "completed",
      "transcript_s3_key": "transcripts/ep123.txt"
    }
  ],
  "total": 150,
  "page": 1,
  "limit": 20,
  "totalPages": 8
}
```

#### Get Episode Transcript
```
GET /api/episodes/{episode_id}/transcript

Response:
{
  "transcript": "Full transcript text here..."
}
```

## Component Usage

The application includes two main components that can be used independently:

### Podcast Subscription Component
```tsx
import { PodcastSubscription } from './components/PodcastSubscription';

function App() {
  return <PodcastSubscription />;
}
```

### Episode Transcripts Component
```tsx
import { EpisodeTranscripts } from './components/EpisodeTranscripts';

function App() {
  return <EpisodeTranscripts />;
}
```

### Full Application with Navigation
```tsx
import { useState } from 'react';
import { PodcastSubscription } from './components/PodcastSubscription';
import { EpisodeTranscripts } from './components/EpisodeTranscripts';

function App() {
  const [activeTab, setActiveTab] = useState('subscriptions');

  return (
    <div>
      <nav>
        <button onClick={() => setActiveTab('subscriptions')}>Subscriptions</button>
        <button onClick={() => setActiveTab('transcripts')}>Transcripts</button>
      </nav>
      {activeTab === 'subscriptions' && <PodcastSubscription />}
      {activeTab === 'transcripts' && <EpisodeTranscripts />}
    </div>
  );
}
```

## Features in Detail

### Podcast Subscriptions

#### Form Validation
- Validates that the RSS URL is not empty
- Ensures the URL uses http:// or https:// protocol
- Provides real-time feedback to users
- Clears validation errors as user types

#### Subscription Management
- Grid-based card layout for podcasts
- Podcast thumbnails with fallback placeholders
- Confirmation dialog before unsubscribing
- Automatic list refresh after actions

### Episode Transcripts

#### Filtering System
- Filter by transcript status: All, Completed, Processing
- Active filter highlighted in UI
- Episode count displayed for current filter
- Maintains filter state during navigation

#### Pagination
- 20 episodes per page
- Smart page number display with ellipsis
- Previous/Next navigation buttons
- Automatic scroll to top on page change
- Results summary showing current range

#### Transcript Viewer
- Modal overlay for focused reading
- Full-screen on mobile devices
- Copy to clipboard with visual confirmation
- Keyboard support (ESC to close)
- Loading states while fetching transcript
- Error handling with retry functionality

#### Skeleton Loaders
- Animated skeleton cards during initial load
- Shimmer effect for visual feedback
- Preserves layout to prevent content jump

### Common Features

#### Loading States
- Spinners during API calls
- Disabled inputs while processing
- Skeleton loaders for content
- Processing indicators for background tasks

#### Error Handling
- Catches network errors
- Displays user-friendly error messages
- Retry buttons for failed operations
- Handles API errors gracefully

#### Responsive Design
- Grid layout adapts to screen size
- Mobile-friendly form inputs
- Touch-optimized buttons
- Sticky navigation header
- Breakpoints at 768px and 480px
- Tab labels hidden on very small screens

## Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## Future Enhancements

- **Search Functionality**: Search episodes by title or podcast name
- **Audio Playback**: Play episodes directly in the browser
- **Transcript Search**: Search within transcript text
- **Download Transcripts**: Export transcripts as PDF or text files
- **Podcast Categories**: Organize podcasts by categories and tags
- **Import/Export**: OPML file support for bulk operations
- **Dark Mode**: Theme toggle for better viewing in different lighting
- **Offline Support**: Service Workers for offline access to transcripts
- **Bookmarking**: Save favorite episodes and transcript sections
- **Sharing**: Share episodes and transcript highlights

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
