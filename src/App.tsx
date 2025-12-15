import { Routes, Route, NavLink, Navigate } from 'react-router-dom';
import { SubscriptionsPage, TranscriptsPage, BulkTranscribePage } from './pages';
import { Icon } from './components/shared';
import './App.css';

const isDevelopment = import.meta.env.DEV;

function App() {
  return (
    <div className="app">
      <nav className="app-nav">
        <div className="nav-container">
          <div className="nav-brand">
            <Icon name="podcast" size={32} />
            <span className="nav-title">Podcast Manager</span>
          </div>
          <div className="nav-tabs">
            <NavLink
              to="/subscriptions"
              className={({ isActive }) => `nav-tab ${isActive ? 'active' : ''}`}
            >
              <Icon name="podcast" size={20} />
              Subscriptions
            </NavLink>
            <NavLink
              to="/transcripts"
              className={({ isActive }) => `nav-tab ${isActive ? 'active' : ''}`}
            >
              <Icon name="document" size={20} />
              Transcripts
            </NavLink>
            {isDevelopment && (
              <NavLink
                to="/bulk-transcribe"
                className={({ isActive }) => `nav-tab ${isActive ? 'active' : ''}`}
              >
                <Icon name="microphone" size={20} />
                Bulk Transcribe
                <span className="dev-badge">DEV</span>
              </NavLink>
            )}
          </div>
        </div>
      </nav>

      <main className="app-content">
        <Routes>
          <Route path="/" element={<Navigate to="/subscriptions" replace />} />
          <Route path="/subscriptions" element={<SubscriptionsPage />} />
          <Route path="/transcripts" element={<TranscriptsPage />} />
          {isDevelopment && (
            <Route path="/bulk-transcribe" element={<BulkTranscribePage />} />
          )}
        </Routes>
      </main>
    </div>
  );
}

export default App;
