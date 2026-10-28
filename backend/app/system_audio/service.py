"""Capture the audio this computer is playing, then transcribe and summarise it.

Windows: WASAPI loopback through ``soundcard`` (no virtual cable, no driver).
Other platforms work only where the backend can open a loopback/monitor source;
when it cannot, the API reports 503 with a readable message instead of failing
silently. The recording is written as 16-bit PCM WAV while it runs (constant
memory), then an MP3 is encoded with lameenc - no ffmpeg CLI is required.
"""

from __future__ import annotations

import json
import threading
import uuid
import wave
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import lameenc
import numpy as np

from app.config.ai_client import call_ai_text
from app.speech.exceptions import (
    ConflictError,
    NotFoundError,
    ServiceUnavailableError,
    ValidationError,
)
from app.speech.service import SpeechService

try:  # pragma: no cover - platform dependent
    import soundcard as _soundcard
except Exception:  # pragma: no cover
    _soundcard = None

ROOT = Path(__file__).resolve().parents[2] / "storage" / "recordings"
MAX_SECONDS = 90 * 60
BLOCK_FRAMES = 4800  # 100 ms at 48 kHz
STT_BYTES_LIMIT = 24 * 1024 * 1024
TRANSCRIPT_LIMIT = 48_000

SUMMARY_STYLES: dict[str, str] = {
    "minutes": (
        "meeting minutes with a short overview, the key discussion points, "
        "decisions made, action items with owners when named, and open questions"
    ),
    "bullets": "a tight bullet list of the key points in the order they were discussed",
    "study_notes": (
        "study notes: definitions, facts and figures with short explanations, "
        "plus five revision questions with answers"
    ),
    "action_items": "a checklist of action items, owners and deadlines, then risks",
}


def _utc_now() -> str:
    return datetime.now(UTC).isoformat(timespec="seconds")


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _clean_label(label: str | None, fallback: str) -> str:
    text = (label or "").strip()
    return text[:120] if text else fallback


def _loopback_device() -> tuple[Any, str]:
    if _soundcard is None:
        raise ServiceUnavailableError(
            "System-audio capture is not available on this server (soundcard could not load)."
        )
    try:
        speaker = _soundcard.default_speaker()
        mic = None
        if speaker is not None:
            try:
                mic = _soundcard.get_microphone(
                    id=str(speaker.name), include_loopback=True
                )
            except Exception:
                mic = None
        if mic is None:
            loopbacks = [
                m
                for m in _soundcard.all_microphones(include_loopback=True)
                if getattr(m, "isloopback", False)
            ]
            mic = loopbacks[0] if loopbacks else None
        if mic is None:
            raise ServiceUnavailableError(
                "No loopback audio device was found. Play something on this computer "
                "and make sure an output device is enabled."
            )
        return mic, str(mic.name)
    except ServiceUnavailableError:
        raise
    except Exception as exc:  # pragma: no cover - device/driver specific
        raise ServiceUnavailableError(
            f"Could not open the system-audio loopback device: {exc}"
        ) from exc


@dataclass
class _ActiveRecording:
    id: str
    directory: Path
    microphone: Any
    device: str
    label: str
    sample_rate: int
    channels: int
    started_at: str = field(default_factory=_utc_now)
    wav_path: Path = field(init=False)
    meta_path: Path = field(init=False)
    stop_event: threading.Event = field(default_factory=threading.Event)
    thread: threading.Thread | None = None
    wave_file: wave.Wave_write | None = None
    frames: int = 0
    level: float = 0.0
    error: str | None = None
    finalized: bool = False
    finalize_lock: threading.Lock = field(default_factory=threading.Lock)

    def __post_init__(self) -> None:
        self.wav_path = self.directory / "audio.wav"
        self.meta_path = self.directory / "meta.json"

    @property
    def elapsed(self) -> float:
        return self.frames / float(self.sample_rate) if self.sample_rate else 0.0

    def meta(self) -> dict[str, Any]:
        payload = _read_json(self.meta_path) if self.meta_path.exists() else {}
        payload.update(
            {
                "id": self.id,
                "label": self.label,
                "status": payload.get("status", "recording"),
                "started_at": self.started_at,
                "ended_at": payload.get("ended_at"),
                "duration_seconds": round(
                    payload.get("duration_seconds") or self.elapsed, 2
                ),
                "sample_rate": self.sample_rate,
                "channels": self.channels,
                "device": self.device,
                "wav_bytes": payload.get("wav_bytes", 0),
                "mp3_bytes": payload.get("mp3_bytes", 0),
                "transcript": payload.get("transcript"),
                "summary": payload.get("summary"),
                "summary_style": payload.get("summary_style"),
                "provider": payload.get("provider"),
                "model": payload.get("model"),
                "error": self.error or payload.get("error"),
            }
        )
        return payload

    def save_meta(self, **changes: Any) -> dict[str, Any]:
        payload = self.meta()
        payload.update(changes)
        _write_json(self.meta_path, payload)
        return payload

    def start(self) -> None:
        self.wave_file = wave.open(str(self.wav_path), "wb")
        self.wave_file.setnchannels(self.channels)
        self.wave_file.setsampwidth(2)
        self.wave_file.setframerate(self.sample_rate)
        self.save_meta(status="recording", ended_at=None, duration_seconds=0.0)
        self.thread = threading.Thread(
            target=self._capture, name=f"system-audio-{self.id}", daemon=True
        )
        self.thread.start()

    def _capture(self) -> None:
        assert self.wave_file is not None
        try:
            with self.microphone.recorder(
                samplerate=self.sample_rate,
                channels=self.channels,
                blocksize=BLOCK_FRAMES,
            ) as recorder:
                while not self.stop_event.is_set():
                    block = recorder.record(numframes=BLOCK_FRAMES)
                    if block is None or len(block) == 0:
                        continue
                    samples = np.asarray(block, dtype=np.float32)
                    peak = float(np.max(np.abs(samples))) if samples.size else 0.0
                    self.level = min(1.0, peak)
                    clipped = np.clip(samples, -1.0, 1.0)
                    pcm = (clipped * 32767.0).astype("<i2")
                    self.wave_file.writeframes(pcm.tobytes())
                    self.frames += len(samples)
                    if self.elapsed >= MAX_SECONDS:
                        break
        except Exception as exc:  # pragma: no cover - device/driver specific
            self.error = f"Recording stopped: {exc}"
        finally:
            self.level = 0.0
            try:
                if self.wave_file is not None:
                    self.wave_file.close()
            except Exception:
                pass
            self.wave_file = None
            self.stop_event.set()

    def stop(self) -> None:
        self.stop_event.set()
        if self.thread is not None:
            self.thread.join(timeout=5.0)
        if self.wave_file is not None:
            try:
                self.wave_file.close()
            except Exception:
                pass
            self.wave_file = None


def _encode_mp3(
    wav_path: Path,
    mp3_path: Path,
    *,
    bit_rate: int,
    downmix_mono: bool = False,
) -> int:
    with wave.open(str(wav_path), "rb") as source:
        channels = source.getnchannels()
        encoder = lameenc.Encoder()
        encoder.set_bit_rate(bit_rate)
        encoder.set_in_sample_rate(source.getframerate())
        encoder.set_channels(1 if downmix_mono else channels)
        encoder.set_quality(2)
        chunks = bytearray()
        while True:
            frames = source.readframes(source.getframerate())
            if not frames:
                break
            if downmix_mono and channels == 2:
                stereo = np.frombuffer(frames, dtype="<i2").reshape(-1, 2)
                mono = stereo.mean(axis=1).astype("<i2")
                frames = mono.tobytes()
            chunks += encoder.encode(frames)
        chunks += encoder.flush()
    mp3_path.write_bytes(bytes(chunks))
    return len(chunks)


class SystemAudioManager:
    def __init__(self, root: Path = ROOT) -> None:
        self.root = root
        self._lock = threading.Lock()
        self._active: _ActiveRecording | None = None

    # -- recording lifecycle -------------------------------------------------

    def start(
        self,
        *,
        label: str | None = None,
        sample_rate: int = 48000,
        channels: int = 2,
    ) -> dict[str, Any]:
        with self._lock:
            if self._active is not None and not self._active.finalized:
                if not self._active.stop_event.is_set():
                    raise ConflictError(
                        "A system-audio recording is already running. Stop it first."
                    )
                self._finalize(self._active)
            microphone, device = _loopback_device()
            recording_id = uuid.uuid4().hex[:12]
            directory = self.root / recording_id
            directory.mkdir(parents=True, exist_ok=True)
            recording = _ActiveRecording(
                id=recording_id,
                directory=directory,
                microphone=microphone,
                device=device,
                label=_clean_label(label, f"Recording {datetime.now():%d %b %H:%M}"),
                sample_rate=sample_rate,
                channels=channels,
            )
            try:
                recording.start()
            except Exception as exc:
                raise ServiceUnavailableError(
                    f"Could not start capture: {exc}"
                ) from exc
            self._active = recording
            return {
                "recording_id": recording.id,
                "label": recording.label,
                "status": "recording",
                "started_at": recording.started_at,
                "sample_rate": recording.sample_rate,
                "channels": recording.channels,
                "device": recording.device,
                "max_seconds": MAX_SECONDS,
            }

    def status(self) -> dict[str, Any]:
        active = self._active
        if active is None:
            return {"active": False, "max_seconds": MAX_SECONDS}
        if active.stop_event.is_set() and not active.finalized:
            self._finalize(active)
        return {
            "active": not active.finalized,
            "recording_id": active.id,
            "label": active.label,
            "status": "recording" if not active.finalized else "ready",
            "device": active.device,
            "started_at": active.started_at,
            "elapsed_seconds": round(active.elapsed, 2),
            "level": round(active.level, 4),
            "sample_rate": active.sample_rate,
            "channels": active.channels,
            "max_seconds": MAX_SECONDS,
            "error": active.error,
        }

    def stop(self) -> dict[str, Any]:
        with self._lock:
            active = self._active
            if active is None:
                raise ConflictError("There is no system-audio recording to stop.")
            active.stop()
            self._finalize(active)
            return active.meta()

    def _finalize(self, recording: _ActiveRecording) -> None:
        if recording.finalized:
            return
        with recording.finalize_lock:
            if recording.finalized:
                return
            recording.stop()
            status = "ready" if not recording.error else "failed"
            wav_bytes = (
                recording.wav_path.stat().st_size if recording.wav_path.exists() else 0
            )
            mp3_bytes = 0
            error = recording.error
            if wav_bytes > 44:
                try:
                    mp3_bytes = _encode_mp3(
                        recording.wav_path,
                        recording.directory / "audio.mp3",
                        bit_rate=128,
                    )
                    _encode_mp3(
                        recording.wav_path,
                        recording.directory / "speech.mp3",
                        bit_rate=64,
                        downmix_mono=True,
                    )
                except Exception as exc:  # pragma: no cover - encoder dependent
                    error = f"MP3 encoding failed: {exc}"
                    status = "failed"
            else:
                status = "failed"
                error = (
                    error or "Nothing was captured. Is audio playing on this device?"
                )
            recording.finalized = True
            recording.save_meta(
                status=status,
                ended_at=_utc_now(),
                duration_seconds=round(recording.elapsed, 2),
                wav_bytes=wav_bytes,
                mp3_bytes=mp3_bytes,
                error=error,
            )

    # -- library -------------------------------------------------------------

    def list_recordings(self) -> list[dict[str, Any]]:
        if not self.root.exists():
            return []
        items: list[dict[str, Any]] = []
        for directory in self.root.iterdir():
            meta = directory / "meta.json"
            if not directory.is_dir() or not meta.exists():
                continue
            try:
                items.append(_read_json(meta))
            except Exception:
                continue
        items.sort(key=lambda item: item.get("started_at") or "", reverse=True)
        return items

    def get(self, recording_id: str) -> dict[str, Any]:
        directory = self._directory(recording_id)
        return _read_json(directory / "meta.json")

    def path_for(self, recording_id: str, fmt: str) -> Path:
        directory = self._directory(recording_id)
        name = "audio.wav" if fmt == "wav" else "audio.mp3"
        path = directory / name
        if not path.exists():
            raise NotFoundError("Recording file", f"{recording_id}.{fmt}")
        return path

    def delete(self, recording_id: str) -> None:
        active = self._active
        if active is not None and active.id == recording_id and not active.finalized:
            raise ConflictError("Stop the recording before deleting it.")
        directory = self._directory(recording_id)
        for child in directory.iterdir():
            child.unlink(missing_ok=True)
        directory.rmdir()

    def _directory(self, recording_id: str) -> Path:
        if not recording_id or any(ch not in "0123456789abcdef" for ch in recording_id):
            raise NotFoundError("Recording", recording_id)
        directory = self.root / recording_id
        if not directory.is_dir():
            raise NotFoundError("Recording", recording_id)
        return directory

    # -- AI ------------------------------------------------------------------

    def transcribe(
        self, recording_id: str, language: str | None = None
    ) -> dict[str, Any]:
        meta = self._finalize_if_needed(recording_id)
        directory = self._directory(recording_id)
        source = directory / "speech.mp3"
        if not source.exists():
            source = directory / "audio.mp3"
        if not source.exists():
            raise ValidationError("This recording has no audio to transcribe.")
        if source.stat().st_size > STT_BYTES_LIMIT:
            raise ValidationError(
                "This recording is too long for one transcription request "
                "(about 50 minutes of MP3). Split it into shorter recordings."
            )
        result = SpeechService().transcribe(
            source.read_bytes(), "audio/mpeg", language=language
        )
        transcript = (result.get("transcript") or "").strip()
        if not transcript:
            raise ServiceUnavailableError("Transcription returned no text.")
        (directory / "transcript.txt").write_text(transcript, encoding="utf-8")
        meta = self._update_meta(
            recording_id,
            status="transcribed",
            transcript=transcript,
            provider=result.get("provider"),
            model=result.get("model"),
            error=None,
        )
        return meta

    async def summarize(
        self,
        recording_id: str,
        *,
        style: str = "minutes",
        language: str | None = None,
    ) -> dict[str, Any]:
        meta = self.get(recording_id)
        transcript = (meta.get("transcript") or "").strip()
        if not transcript:
            raise ValidationError(
                "Transcribe the recording before asking for a summary."
            )
        style_key = style if style in SUMMARY_STYLES else "minutes"
        excerpt = transcript
        truncated = len(excerpt) > TRANSCRIPT_LIMIT
        if truncated:
            excerpt = excerpt[:TRANSCRIPT_LIMIT]
        language_line = (
            f"Write the result in {language}." if language else "Write in English."
        )
        messages = [
            {
                "role": "system",
                "content": (
                    "You are an accurate meeting and lecture summariser. Work only "
                    "from the transcript. Never invent names, numbers or decisions. "
                    "If something is unclear, say so. Output Markdown."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"Produce {SUMMARY_STYLES[style_key]}. {language_line}\n\n"
                    f"Transcript:\n{excerpt}"
                    + (
                        "\n\n[Transcript truncated for length; summarise what is present.]"
                        if truncated
                        else ""
                    )
                ),
            },
        ]
        try:
            summary = await call_ai_text(
                messages, max_tokens=1600, temperature=0.3, timeout=90.0
            )
        except Exception as exc:
            raise ServiceUnavailableError(
                f"The AI summary could not be generated: {exc}"
            ) from exc
        summary = summary.strip()
        if not summary:
            raise ServiceUnavailableError("The AI returned an empty summary.")
        (self._directory(recording_id) / "summary.md").write_text(
            summary, encoding="utf-8"
        )
        return self._update_meta(
            recording_id,
            status="summarised",
            summary=summary,
            summary_style=style_key,
            error=None,
        )

    def _update_meta(self, recording_id: str, **changes: Any) -> dict[str, Any]:
        directory = self._directory(recording_id)
        meta = _read_json(directory / "meta.json")
        meta.update(changes)
        _write_json(directory / "meta.json", meta)
        return meta

    def _finalize_if_needed(self, recording_id: str) -> dict[str, Any]:
        active = self._active
        if active is not None and active.id == recording_id:
            if active.stop_event.is_set() and not active.finalized:
                self._finalize(active)
        return self.get(recording_id)


_manager: SystemAudioManager | None = None
_manager_lock = threading.Lock()


def get_manager() -> SystemAudioManager:
    global _manager
    with _manager_lock:
        if _manager is None:
            _manager = SystemAudioManager()
        return _manager
