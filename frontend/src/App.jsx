import { useEffect, useState } from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

import {
  Activity,
  Zap,
  Users,
  Bot,
  Send,
  RefreshCw,
} from "lucide-react";

import "./App.css";

const API_URL = import.meta.env.VITE_API_URL;

function MetricCard({ title, value, unit, icon: Icon }) {
  return (
    <div className="metric-card">
      <div className="metric-heading">
        <span>{title}</span>
        <Icon size={20} />
      </div>

      <h2>
        {value ?? "--"} <small>{unit}</small>
      </h2>
    </div>
  );
}

function App() {
  const [telemetry, setTelemetry] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [question, setQuestion] = useState("");
  const [answer, setAnswer] = useState(null);
  const [chatLoading, setChatLoading] = useState(false);
  const [chatError, setChatError] = useState("");

  const siteId = "building-01";

  async function loadTelemetry() {
    setLoading(true);
    setError("");

    try {
      const response = await fetch(
        `${API_URL}/telemetry?site_id=${encodeURIComponent(siteId)}`
      );

      if (!response.ok) {
        throw new Error(`Telemetry API returned ${response.status}`);
      }

      const data = await response.json();

      setTelemetry(data.readings || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadTelemetry();
  }, []);

  const averagePower = telemetry.length
    ? telemetry.reduce((sum, item) => sum + Number(item.power_kw), 0)
        / telemetry.length
    : null;

  const maximumPower = telemetry.length
    ? Math.max(...telemetry.map(item => Number(item.power_kw)))
    : null;

  const averageOccupancy = telemetry.length
    ? telemetry.reduce((sum, item) => sum + Number(item.occupancy), 0)
        / telemetry.length
    : null;

  const chartData = telemetry.map(item => ({
    ...item,
    time: new Date(item.timestamp).toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    }),
  }));

  async function askAssistant(event) {
    event.preventDefault();

    if (!question.trim()) return;

    setChatLoading(true);
    setChatError("");
    setAnswer(null);

    try {
      const response = await fetch(`${API_URL}/ask`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          question,
          site_id: siteId,
        }),
      });

      if (!response.ok) {
        throw new Error(`AI API returned ${response.status}`);
      }

      const data = await response.json();
      setAnswer(data);
      setQuestion("");
    } catch (err) {
      setChatError(err.message);
    } finally {
      setChatLoading(false);
    }
  }

  return (
    <main className="dashboard">
      <header className="topbar">
        <div>
          <h1>GreenEdge AI</h1>
          <p>Sustainability Operations Platform</p>
        </div>

        <div className="site-badge">
          <Activity size={16} />
          {siteId}
        </div>
      </header>

      <section className="intro">
        <div>
          <h2>Building Overview</h2>
          <p>Energy and occupancy monitoring · Last 24 hours</p>
        </div>

        <button
          className="refresh-button"
          onClick={loadTelemetry}
          disabled={loading}
        >
          <RefreshCw size={16} />
          Refresh
        </button>
      </section>

      {error && <p className="error">{error}</p>}

      <section className="metrics-grid">
        <MetricCard
          title="Average Power"
          value={averagePower === null ? null : averagePower.toFixed(2)}
          unit="kW"
          icon={Zap}
        />

        <MetricCard
          title="Maximum Power"
          value={maximumPower === null ? null : maximumPower.toFixed(2)}
          unit="kW"
          icon={Activity}
        />

        <MetricCard
          title="Average Occupancy"
          value={averageOccupancy === null ? null : averageOccupancy.toFixed(1)}
          unit="people"
          icon={Users}
        />

        <MetricCard
          title="Total Readings"
          value={telemetry.length}
          unit="events"
          icon={Activity}
        />
      </section>

      <section className="chart-card">
        <div className="section-heading">
          <div>
            <h2>Power Consumption</h2>
            <p>Power readings over the last 24 hours</p>
          </div>
        </div>

        {loading ? (
          <p>Loading telemetry...</p>
        ) : chartData.length === 0 ? (
          <p>No telemetry readings available.</p>
        ) : (
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis unit=" kW" />
              <Tooltip />
              <Line
                type="monotone"
                dataKey="power_kw"
                name="Power"
                stroke="#16a36a"
                strokeWidth={2}
                dot={false}
              />
            </LineChart>
          </ResponsiveContainer>
        )}
      </section>

      <section className="chart-card">
        <h2>Occupancy Monitoring</h2>
        <p>People detected across the building</p>

        {loading ? (
          <p>Loading occupancy...</p>
        ) : chartData.length === 0 ? (
          <p>No occupancy readings available.</p>
        ) : (
          <ResponsiveContainer width="100%" height={260}>
            <LineChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Line
                type="monotone"
                dataKey="occupancy"
                name="Occupancy"
                stroke="#3979d5"
                strokeWidth={2}
                dot={false}
              />
            </LineChart>
          </ResponsiveContainer>
        )}
      </section>

      <section className="chat-card">
        <div className="chat-heading">
          <Bot size={24} />
          <div>
            <h2>GreenEdge AI Assistant</h2>
            <p>Ask questions about building sustainability</p>
          </div>
        </div>

        <form onSubmit={askAssistant} className="chat-form">
          <input
            value={question}
            onChange={event => setQuestion(event.target.value)}
            placeholder="How can I reduce HVAC energy costs?"
          />

          <button type="submit" disabled={chatLoading || !question.trim()}>
            <Send size={18} />
            {chatLoading ? "Analyzing..." : "Ask"}
          </button>
        </form>

        {chatError && <p className="error">{chatError}</p>}

        {answer && (
          <div className="answer-panel">
            <h3>AI Analysis</h3>

            <div className="answer-text">
              {answer.answer}
            </div>

            <h3>Telemetry Evidence</h3>

            <pre>
              {JSON.stringify(answer.telemetry_evidence, null, 2)}
            </pre>

            <h3>Knowledge Sources</h3>

            <ul>
              {answer.knowledge_sources?.map((source, index) => (
                <li key={`${source.chunk_id}-${index}`}>
                  {source.source}
                  {" — "}
                  Similarity distance: {Number(source.distance).toFixed(4)}
                </li>
              ))}
            </ul>

            {answer.insufficient_evidence && (
              <p className="warning">
                Available evidence may be insufficient for this question.
              </p>
            )}
          </div>
        )}
      </section>

      <footer>
        GreenEdge AI · Sustainability insights powered by cloud analytics and AI
      </footer>
    </main>
  );
}

export default App;