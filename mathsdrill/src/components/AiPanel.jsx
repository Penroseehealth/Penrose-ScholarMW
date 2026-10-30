import { useEffect, useRef, useState } from 'react';
import { ApiError, apiRequest, discoverProviders } from '../lib/api';
import { IconSend, IconSettings, IconSparkle } from './icons';

export default function AiPanel({ question, setQuestion, focusToken, onStart, onResult, onFailure }) {
  const [providers, setProviders] = useState([]);
  const [providerId, setProviderId] = useState('');
  const [modelId, setModelId] = useState('');
  const [generating, setGenerating] = useState(false);
  const [error, setError] = useState('');
  const [hint, setHint] = useState('');
  const textareaRef = useRef(null);
  const lastQuestion = useRef('');

  useEffect(() => {
    let cancelled = false;
    discoverProviders().then((list) => {
      if (cancelled) return;
      setProviders(list);
      if (list[0]) {
        setProviderId(list[0].id);
        setModelId(list[0].models[0]?.id || '');
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (focusToken) textareaRef.current?.focus();
  }, [focusToken]);

  const provider = providers.find((entry) => entry.id === providerId);

  async function generate(text) {
    const value = (text ?? question).trim();
    if (!value || generating) return;
    lastQuestion.current = value;
    setGenerating(true);
    setError('');
    setHint('');
    onStart();
    try {
      const payload = await apiRequest('/mathsdrill/solve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: value }),
      });
      onResult({
        question: payload.question || value,
        steps: payload.steps || [],
        answerLatex: payload.answer_latex || payload.answerLatex || '',
        answerText: payload.answer_text || payload.answerText || '',
        source: payload.source || 'provider',
        visual: payload.visual || null,
      });
      setHint(payload.verification_detail || '');
    } catch (caught) {
      const message = caught instanceof ApiError ? caught.message : 'Something went wrong. Try again.';
      setError(message);
      onFailure(message);
    } finally {
      setGenerating(false);
    }
  }

  return (
    <section className="card" aria-label="AI provider">
      <div className="card-head">
        <h2>
          <IconSparkle size={16} /> AI Provider
        </h2>
        <div className="spacer" />
        <span className={`badge${providers.length ? ' ok' : ' warn'}`}>
          {providers.length ? 'Connected' : 'Not configured'}
        </span>
      </div>

      <div className="panel-body">
        <p className="panel-lead">
          Ask a question or upload a file and let AI generate the problem, solution and diagram.
        </p>

        <div className="ai-row">
          <label className="provider-select" style={{ flex: 1 }}>
            <select
              value={providerId}
              onChange={(event) => {
                setProviderId(event.target.value);
                const next = providers.find((entry) => entry.id === event.target.value);
                setModelId(next?.models[0]?.id || '');
              }}
              aria-label="AI provider"
              disabled={!providers.length}
            >
              {providers.length ? (
                providers.map((entry) => (
                  <option key={entry.id} value={entry.id}>
                    {entry.name}
                  </option>
                ))
              ) : (
                <option value="">No provider reported by the service</option>
              )}
            </select>
          </label>

          {provider && provider.models.length > 1 ? (
            <label className="provider-select">
              <select value={modelId} onChange={(event) => setModelId(event.target.value)} aria-label="AI model">
                {provider.models.map((model) => (
                  <option key={model.id} value={model.id}>
                    {model.name}
                  </option>
                ))}
              </select>
            </label>
          ) : null}

          <button type="button" className="ghost-btn" title="Provider settings" aria-label="Provider settings">
            <IconSettings size={15} /> Settings
          </button>
        </div>

        <label htmlFor="mathdrill-question" className="status-line">
          Question
        </label>
        <textarea
          id="mathdrill-question"
          ref={textareaRef}
          className="ai-textarea"
          placeholder="Type your question here… (e.g. “Solve 3x + 7 = 22 and draw the graph”)"
          value={question}
          onChange={(event) => setQuestion(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) {
              event.preventDefault();
              generate();
            }
          }}
        />

        <div className="ai-footer">
          <button type="button" className="btn primary" onClick={() => generate()} disabled={generating}>
            {generating ? <span className="spinner" /> : <IconSend size={15} />} {generating ? 'Solving…' : 'Solve'}
          </button>

          {generating ? <span className="status-line">Waiting for the provider…</span> : null}

          {!generating && error ? (
            <span className="status-line error">
              {error}{' '}
              <button type="button" onClick={() => generate(lastQuestion.current || question)}>
                Retry
              </button>
            </span>
          ) : null}

          {!generating && !error && hint ? <span className="status-line ok">{hint}</span> : null}

          {!generating && !error && !hint && !providers.length ? (
            <span className="status-line">
              Providers are read from the Penrose backend, so this standalone build has none until it is served by
              the app.
            </span>
          ) : null}
        </div>
      </div>
    </section>
  );
}
