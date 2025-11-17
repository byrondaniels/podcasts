# Podcast Subscription Manager

A modern React application for managing podcast subscriptions via RSS feeds. Built with TypeScript, React hooks, and a clean, responsive UI.

## Features

- **Subscribe to Podcasts**: Add podcasts using their RSS feed URLs
- **View Subscriptions**: Display all subscribed podcasts with title, description, and thumbnail
- **Unsubscribe**: Remove podcasts from your subscription list
- **Form Validation**: Real-time validation for RSS feed URLs
- **Loading States**: Visual feedback during API calls
- **Error Handling**: User-friendly error messages
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices

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
│   │   ├── PodcastSubscription.tsx    # Main component
│   │   └── PodcastSubscription.css    # Component styles
│   ├── services/
│   │   └── podcastService.ts          # API service layer
│   ├── types/
│   │   └── podcast.ts                 # TypeScript interfaces
│   ├── App.tsx                        # Root component
│   ├── App.css                        # App styles
│   ├── main.tsx                       # Entry point
│   └── index.css                      # Global styles
├── index.html                         # HTML template
├── package.json                       # Dependencies
├── tsconfig.json                      # TypeScript config
└── vite.config.ts                     # Vite config
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

### Subscribe to Podcast
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

### Get All Podcasts
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

### Unsubscribe from Podcast
```
DELETE /api/podcasts/{podcast_id}

Response: 204 No Content or 200 OK
```

## Component Usage

The `PodcastSubscription` component can be used in your React application:

```tsx
import { PodcastSubscription } from './components/PodcastSubscription';

function App() {
  return (
    <div className="app">
      <PodcastSubscription />
    </div>
  );
}
```

## Features in Detail

### Form Validation
- Validates that the RSS URL is not empty
- Ensures the URL uses http:// or https:// protocol
- Provides real-time feedback to users

### Loading States
- Displays spinners during API calls
- Disables inputs while processing
- Shows "Loading podcasts..." message when fetching data

### Error Handling
- Catches network errors
- Displays user-friendly error messages
- Handles API errors gracefully

### Responsive Design
- Grid layout adapts to screen size
- Mobile-friendly form inputs
- Touch-optimized buttons
- Breakpoints at 768px and 480px

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

- Search and filter podcasts
- Episode listing and playback
- Podcast categories and tags
- Import/export OPML files
- Dark mode support
- Offline support with Service Workers

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
