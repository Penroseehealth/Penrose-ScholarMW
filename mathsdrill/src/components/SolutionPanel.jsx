import katex from 'katex';
import { IconSparkle } from './icons';

function renderLatex(latex) {
  return katex.renderToString(String(latex || ''), { throwOnError: false, displayMode: false });
}

function RichText({ text }) {
  const value = String(text ?? '');
  const parts = value.split(/(\$[^$]+\$)/g);
  return (
    <>
      {parts.map((part, index) => {
        if (part.length > 2 && part.startsWith('$') && part.endsWith('$')) {
          return (
            <span
              key={index}
              className="math-inline"
              dangerouslySetInnerHTML={{ __html: renderLatex(part.slice(1, -1)) }}
            />
          );
        }
        return <span key={index}>{part}</span>;
      })}
    </>
  );
}

function stepParts(step, index) {
  if (typeof step === 'string') return { label: `Step ${index + 1}`, body: step, latex: '' };
  return {
    label: step.title || step.label || step.heading || step.name || `Step ${index + 1}`,
    body: step.text || step.statement || step.detail || step.description || step.body || step.explanation || '',
    latex: step.latex || step.math || step.expression || '',
  };
}

export default function SolutionPanel({ solution, onDemo }) {
  const busy = solution.status === 'loading';
  const steps = Array.isArray(solution.steps) ? solution.steps : [];

  return (
    <section className="card solution-card" aria-label="Solution">
      <div className="card-head">
        <h2>
          <IconSparkle size={16} /> Problem
        </h2>
        <div className="spacer" />
        {solution.demo ? <span className="badge warn">Demo data</span> : null}
        {solution.source ? <span className="badge ok">{solution.source}</span> : null}
      </div>

      <div className="solution-body">
        {busy ? (
          <div className="empty-state">
            <span className="spinner" /> Working the problem…
          </div>
        ) : null}

        {!busy && solution.status === 'error' ? (
          <div className="empty-state">
            <strong>Could not load a solution</strong>
            {solution.error}
            <div className="hint-row">
              <button type="button" className="ghost-btn" onClick={onDemo}>
                Retry with the provider panel
              </button>
            </div>
          </div>
        ) : null}

        {!busy && solution.status === 'idle' ? (
          <div className="empty-state">
            <strong>No question yet</strong>
            Type a question in the AI Provider panel, upload a file, or use the microphone — the worked
            solution will appear here with a diagram you can edit.
            <div className="hint-row">
              <button type="button" className="ghost-btn" onClick={onDemo}>
                Load example problem (demo data)
              </button>
            </div>
            <p className="demo-note">The example is clearly marked demo content and is never shown as AI output.</p>
          </div>
        ) : null}

        {!busy && solution.status === 'ready' ? (
          <>
            {solution.question ? (
              <p className="question-line">
                <RichText text={solution.question} />
              </p>
            ) : null}

            {steps.length ? (
              steps.map((step, index) => {
                const { label, body, latex } = stepParts(step, index);
                return (
                  <div className="sol-step" key={index}>
                    <span className="step-label">{label}</span>
                    {body ? (
                      <p>
                        <RichText text={body} />
                      </p>
                    ) : null}
                    {latex ? (
                      <span
                        className="math-block"
                        dangerouslySetInnerHTML={{ __html: renderLatex(latex) }}
                      />
                    ) : null}
                  </div>
                );
              })
            ) : (
              <p className="question-line">The provider returned no steps.</p>
            )}

            {solution.answerLatex || solution.answerText ? (
              <div className="sol-answer">
                {solution.answerLatex ? (
                  <span
                    className="math-block"
                    dangerouslySetInnerHTML={{ __html: renderLatex(solution.answerLatex) }}
                  />
                ) : (
                  <RichText text={solution.answerText} />
                )}
              </div>
            ) : null}
          </>
        ) : null}
      </div>
    </section>
  );
}
