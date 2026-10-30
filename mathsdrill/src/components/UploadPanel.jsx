import { useRef, useState } from 'react';
import { IconCloud, IconTrash } from './icons';

const ACCEPTED = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx', '.txt'];
const MAX_BYTES = 10 * 1024 * 1024;

function extensionOf(name) {
  const index = name.lastIndexOf('.');
  return index === -1 ? '' : name.slice(index).toLowerCase();
}

function humanSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function UploadPanel({ onExtractedText }) {
  const inputRef = useRef(null);
  const [files, setFiles] = useState([]);
  const [dragging, setDragging] = useState(false);
  const [message, setMessage] = useState('');

  function addFiles(list) {
    const incoming = Array.from(list || []);
    const next = [];
    const errors = [];

    incoming.forEach((file) => {
      const ext = extensionOf(file.name);
      if (!ACCEPTED.includes(ext)) {
        errors.push(`${file.name}: unsupported type`);
        return;
      }
      if (file.size > MAX_BYTES) {
        errors.push(`${file.name}: larger than 10 MB`);
        return;
      }
      const entry = {
        id: `${file.name}-${file.lastModified}-${Math.random().toString(36).slice(2, 6)}`,
        file,
        name: file.name,
        size: file.size,
        ext,
        status: 'ready',
      };
      next.push(entry);

      if (ext === '.txt') {
        const reader = new FileReader();
        reader.onload = () => {
          const text = String(reader.result || '').slice(0, 4000);
          onExtractedText?.(text);
          setFiles((current) =>
            current.map((item) => (item.id === entry.id ? { ...item, status: 'text added to question' } : item)),
          );
        };
        reader.onerror = () => {
          setFiles((current) =>
            current.map((item) => (item.id === entry.id ? { ...item, status: 'could not read file' } : item)),
          );
        };
        reader.readAsText(file);
      }
    });

    setFiles((current) => [...current, ...next]);
    setMessage(errors.length ? errors.join(' · ') : '');
  }

  function removeFile(id) {
    setFiles((current) => current.filter((item) => item.id !== id));
  }

  return (
    <section className="card" aria-label="Upload a question">
      <div className="card-head">
        <h2>
          <IconCloud size={16} /> Upload File
        </h2>
        <span className="badge">Optional</span>
      </div>
      <div className="panel-body">
        <p className="panel-lead">Upload an image, document or question file instead of audio.</p>

        <div
          className={`dropzone${dragging ? ' dragging' : ''}`}
          onDragOver={(event) => {
            event.preventDefault();
            setDragging(true);
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={(event) => {
            event.preventDefault();
            setDragging(false);
            addFiles(event.dataTransfer.files);
          }}
        >
          <span className="dropzone-icon">
            <IconCloud size={22} />
          </span>
          <div className="dropzone-copy">
            <strong>Choose file or drag and drop</strong>
            PDF, JPG, PNG, DOC, DOCX, TXT · up to 10 MB
            <div style={{ marginTop: 8 }}>
              <button type="button" className="btn primary" onClick={() => inputRef.current?.click()}>
                Choose File
              </button>
              <input
                ref={inputRef}
                type="file"
                multiple
                accept={ACCEPTED.join(',')}
                onChange={(event) => {
                  addFiles(event.target.files);
                  event.target.value = '';
                }}
                style={{ display: 'none' }}
              />
            </div>
          </div>
        </div>

        {files.map((item) => (
          <div className="file-row" key={item.id}>
            <span className="badge">{item.ext.replace('.', '').toUpperCase()}</span>
            <span className="file-name" title={item.name}>
              {item.name}
            </span>
            <span className="file-meta">{humanSize(item.size)}</span>
            <span className="file-status">{item.status}</span>
            <button type="button" className="icon-btn" onClick={() => removeFile(item.id)} aria-label={`Remove ${item.name}`}>
              <IconTrash size={15} />
            </button>
          </div>
        ))}

        {message ? <p className="status-line error">{message}</p> : null}
        {files.some((item) => item.ext !== '.txt') ? (
          <p className="status-line">
            Images and documents are attached for review; text extraction needs the Penrose document service,
            which this build is not connected to.
          </p>
        ) : null}
      </div>
    </section>
  );
}
