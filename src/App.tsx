import { useState } from 'react';
import { PodcastSubscription } from './components/PodcastSubscription';
import { EpisodeTranscripts } from './components/EpisodeTranscripts';
import './App.css';

type Tab = 'subscriptions' | 'transcripts';

function App() {
  const [activeTab, setActiveTab] = useState<Tab>('subscriptions');

  return (
    <div className="app">
      <nav className="app-nav">
        <div className="nav-container">
          <div className="nav-brand">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
            </svg>
            <span className="nav-title">Podcast Manager</span>
          </div>
          <div className="nav-tabs">
            <button
              onClick={() => setActiveTab('subscriptions')}
              className={`nav-tab ${activeTab === 'subscriptions' ? 'active' : ''}`}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
              </svg>
              Subscriptions
            </button>
            <button
              onClick={() => setActiveTab('transcripts')}
              className={`nav-tab ${activeTab === 'transcripts' ? 'active' : ''}`}
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              Transcripts
            </button>
          </div>
        </div>
      </nav>

      <main className="app-content">
        {activeTab === 'subscriptions' && <PodcastSubscription />}
        {activeTab === 'transcripts' && <EpisodeTranscripts />}
      </main>
    </div>
  );
}

export default App;
