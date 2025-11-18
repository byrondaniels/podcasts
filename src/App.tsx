import { useState } from 'react';
import { PodcastSubscription } from './components/PodcastSubscription';
import { EpisodeTranscripts } from './components/EpisodeTranscripts';
import { BulkTranscriber } from './components/BulkTranscriber';
import { Icon } from './components/shared';
import './App.css';

type Tab = 'subscriptions' | 'transcripts' | 'bulk-transcribe';

const isDevelopment = import.meta.env.DEV;

function App() {
  const [activeTab, setActiveTab] = useState<Tab>('subscriptions');

  return (
    <div className="app">
      <nav className="app-nav">
        <div className="nav-container">
          <div className="nav-brand">
            <Icon name="podcast" size={32} />
            <span className="nav-title">Podcast Manager</span>
          </div>
          <div className="nav-tabs">
            <button
              onClick={() => setActiveTab('subscriptions')}
              className={`nav-tab ${activeTab === 'subscriptions' ? 'active' : ''}`}
            >
              <Icon name="podcast" size={20} />
              Subscriptions
            </button>
            <button
              onClick={() => setActiveTab('transcripts')}
              className={`nav-tab ${activeTab === 'transcripts' ? 'active' : ''}`}
            >
              <Icon name="document" size={20} />
              Transcripts
            </button>
            {isDevelopment && (
              <button
                onClick={() => setActiveTab('bulk-transcribe')}
                className={`nav-tab ${activeTab === 'bulk-transcribe' ? 'active' : ''}`}
              >
                <Icon name="microphone" size={20} />
                Bulk Transcribe
                <span className="dev-badge">DEV</span>
              </button>
            )}
          </div>
        </div>
      </nav>

      <main className="app-content">
        {activeTab === 'subscriptions' && <PodcastSubscription />}
        {activeTab === 'transcripts' && <EpisodeTranscripts />}
        {activeTab === 'bulk-transcribe' && isDevelopment && <BulkTranscriber />}
      </main>
    </div>
  );
}

export default App;
