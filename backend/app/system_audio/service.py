"""Capture the audio this computer is playing, then transcribe and summarise it.

Windows: WASAPI loopback through ``soundcard`` (no virtual cable, no driver).
Other platforms work only where the backend can open a loopback/monitor source;
when it cannot, the API reports 503 with a readable message instead of failing
silently. The recording is written as 16-bit PCM WAV while it runs (constant
memory), then an MP3 is encoded with lameenc - no ffmpeg CLI is required.
"""

from __future__ import annotations

import json
import queue
import re
import shutil
import threading
import time
import uuid
import warnings
import wave
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import quote

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
# One hour is the longest single recording the UI offers; its parts can be
# 10-30 minutes each.
MAX_SEGMENT_SECONDS = 60 * 60
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")
# A large device buffer absorbs Windows scheduling and garbage-collection
# hiccups; the readers then pull it in small pieces. Reading 100 ms out of a
# 100 ms buffer (the old setting) left no headroom and produced dropouts, which
# played back as scratching.
BUFFER_FRAMES = 28800  # 600 ms of device buffer at 48 kHz
BLOCK_FRAMES = 480  # 10 ms of audio per read
FRESH_FRAMES = 2 * BLOCK_FRAMES  # stale device data to drop before recording
MAX_PENDING_FRAMES = 4800  # 100 ms of per-device buffer while polling
DRAIN_TICKS = 4  # extra 10 ms ticks after stop, to keep the last few frames
QUEUE_BLOCKS = 400  # 4 s of slack between the readers and the disk writer
RESYNC_BLOCKS = 300  # only resync on real clock drift (3 s), never on jitter
PREFILL_BLOCKS = 8  # start writing once every input has 80 ms buffered
FADE_FRAMES = 480  # 10 ms fade in/out so the file never clicks
HIGHPASS_HZ = 90.0
# Windows hands loopback packets over in bursts, sometimes more than 100 ms
# apart even while audio is playing. Only after this long without a packet is
# the stream really silent - and filling a real packet with zeros instead is
# heard as a click, so wait generously.
IDLE_GRACE_SECONDS = 0.5
STT_BYTES_LIMIT = 24 * 1024 * 1024
TRANSCRIPT_LIMIT = 48_000

# Virtual recordings are captured in the browser and uploaded here. The browser
# decides the container (WebM on Chromium/Firefox, MP4 on Safari), so the type
# is recorded verbatim and never assumed.
MAX_VIRTUAL_BYTES = 2 * 1024 * 1024 * 1024
VIRTUAL_MIME_EXT: dict[str, str] = {
    "audio/webm": "webm",
    "video/webm": "webm",
    "audio/ogg": "ogg",
    "video/ogg": "ogv",
    "audio/mp4": "m4a",
    "audio/x-m4a": "m4a",
    "video/mp4": "mp4",
    "audio/mpeg": "mp3",
    "audio/mp3": "mp3",
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "video/quicktime": "mov",
}

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


_SOUNDCARD_PATCH_LOCK = threading.Lock()
_SOUNDCARD_PATCHED = False
_PATCH_STATS = {"silence_chunks": 0, "silence_frames": 0}


def _record_chunk_with_grace(self: Any) -> np.ndarray:
    """Drop-in for ``soundcard``'s ``_Recorder._record_chunk``.

    The stock version treats 40 ms without a packet as "the device went quiet"
    and returns synthesised zeros. Windows hands loopback packets over in
    bursts that can be more than 100 ms apart while audio is playing, so those
    zeros land in the middle of real sound (heard as scratching) and duplicate
    the timeline. This waits for the packet and only fills silence after
    ``IDLE_GRACE_SECONDS`` of genuine quiet.
    """
    from soundcard import mediafoundation as backend

    while self._capture_available_frames() == 0:
        now = time.perf_counter()
        if self._idle_start_time is None:
            self._idle_start_time = now
        elif now - self._idle_start_time >= IDLE_GRACE_SECONDS:
            frames = int(self.samplerate * (now - self._idle_start_time))
            self._idle_start_time = now
            if frames > 0:
                _PATCH_STATS["silence_chunks"] += 1
                _PATCH_STATS["silence_frames"] += frames
                channels = len(set(self.channelmap))
                return np.zeros(frames * channels, dtype=np.float32)
        if getattr(self, "_poll_mode", False):
            # The caller paces the stream itself, so never wait here.
            return np.zeros([0], dtype=np.float32)
        time.sleep(0.002)
    self._idle_start_time = None

    data_ptr, nframes, flags = self._capture_buffer()
    channels = len(set(self.channelmap))
    if data_ptr != backend._ffi.NULL:
        chunk = np.frombuffer(
            backend._ffi.buffer(data_ptr, nframes * 4 * channels), dtype="float32"
        ).copy()
    else:  # pragma: no cover - driver failure
        raise RuntimeError("Could not create capture buffer")
    if flags & backend._ole32.AUDCLNT_BUFFERFLAGS_SILENT:
        chunk[:] = 0
    if self._is_first_frame:
        flags &= ~backend._ole32.AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY
        self._is_first_frame = False
    if flags & backend._ole32.AUDCLNT_BUFFERFLAGS_DATA_DISCONTINUITY:
        warnings.warn(
            "data discontinuity in recording", backend.SoundcardRuntimeWarning
        )
    if nframes > 0:
        self._capture_release(nframes)
        return chunk
    return np.zeros([0], dtype="float32")


def _patch_soundcard_idle_policy() -> None:
    """Apply the packet-waiting reader once per process."""
    global _SOUNDCARD_PATCHED
    with _SOUNDCARD_PATCH_LOCK:
        if _SOUNDCARD_PATCHED or _soundcard is None:
            return
        try:
            from soundcard import mediafoundation as backend
        except Exception:  # pragma: no cover - soundcard absent or altered
            return
        recorder = getattr(backend, "_Recorder", None)
        if recorder is None:  # pragma: no cover - soundcard changed API
            return
        recorder._record_chunk = _record_chunk_with_grace  # type: ignore[method-assign]
        _SOUNDCARD_PATCHED = True


def _loopback_device() -> tuple[Any, str]:
    _patch_soundcard_idle_policy()
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


def _microphone_device() -> tuple[Any, str]:
    """The default recording microphone (the one the voice tools use)."""
    if _soundcard is None:
        raise ServiceUnavailableError(
            "Microphone capture is not available on this server (soundcard could not load)."
        )
    try:
        mic = _soundcard.default_microphone()
    except Exception:  # pragma: no cover - device/driver specific
        mic = None
    if mic is None:
        try:
            candidates = _soundcard.all_microphones(include_loopback=False)
        except Exception:  # pragma: no cover - device/driver specific
            candidates = []
        mic = candidates[0] if candidates else None
    if mic is None:
        raise ServiceUnavailableError(
            "No microphone was found. Plug one in or allow microphone access, then try again."
        )
    return mic, str(mic.name)


@dataclass(frozen=True)
class _CaptureInput:
    """One physical input feeding a recording."""

    device: Any
    name: str
    role: str  # "system" (loopback) or "mic"

    @property
    def highpass(self) -> bool:
        # The local microphone picks up room rumble, fans and DC offset; a
        # 90 Hz high-pass keeps the voice and drops the noise underneath it.
        return self.role == "mic"


def _design_highpass(
    sample_rate: int, cutoff: float = HIGHPASS_HZ, taps: int = 401
) -> np.ndarray:
    """A linear-phase high-pass FIR, built from a windowed ideal low-pass."""
    if taps % 2 == 0:
        taps += 1
    offsets = np.arange(taps, dtype=np.float64) - (taps - 1) / 2.0
    normalized = cutoff / float(sample_rate)
    ideal = 2.0 * normalized * np.sinc(2.0 * normalized * offsets)
    lowpass = ideal * np.blackman(taps)
    lowpass /= lowpass.sum()
    highpass = -lowpass
    highpass[(taps - 1) // 2] += 1.0
    return highpass.astype(np.float32)


class _Highpass:
    """Streaming high-pass filter with block carry-over (no clicks at edges)."""

    def __init__(self, sample_rate: int) -> None:
        self.kernel = _design_highpass(sample_rate)
        self._tail: np.ndarray | None = None

    def process(self, block: np.ndarray) -> np.ndarray:
        channels = block.shape[1]
        if self._tail is None or self._tail.shape[1] != channels:
            self._tail = np.zeros((len(self.kernel) - 1, channels), dtype=np.float32)
        padded = np.concatenate([self._tail, block], axis=0)
        output = np.empty_like(block, dtype=np.float32)
        for channel in range(channels):
            output[:, channel] = np.convolve(
                padded[:, channel], self.kernel, mode="valid"
            )[: len(block)]
        self._tail = padded[-(len(self.kernel) - 1) :].copy()
        return output


def _input_devices(source: str) -> tuple[list[_CaptureInput], str, str]:
    """Resolve a recording source to the devices it needs.

    Returns (inputs, device label, canonical source key). Recording both lets a
    meeting be captured end to end: the other participants arrive through the
    loopback and the local speaker through the microphone.
    """
    key = source if source in {"system", "mic", "both"} else "both"
    if key == "system":
        mic, name = _loopback_device()
        return [_CaptureInput(mic, name, "system")], name, key
    if key == "mic":
        mic, name = _microphone_device()
        return [_CaptureInput(mic, name, "mic")], name, key

    inputs: list[_CaptureInput] = []
    try:
        loopback, loop_name = _loopback_device()
        inputs.append(_CaptureInput(loopback, loop_name, "system"))
    except ServiceUnavailableError:
        pass
    try:
        microphone, mic_name = _microphone_device()
        inputs.append(_CaptureInput(microphone, mic_name, "mic"))
    except ServiceUnavailableError:
        pass
    if not inputs:
        raise ServiceUnavailableError(
            "No audio input was found. Make sure an output device and a microphone are enabled."
        )
    if len(inputs) == 1:
        return inputs, inputs[0].name, inputs[0].role
    return inputs, " + ".join(item.name for item in inputs), "both"


@dataclass
class _ActiveRecording:
    id: str
    directory: Path
    inputs: list[_CaptureInput]
    device: str
    label: str
    sample_rate: int
    channels: int
    source: str = "system"
    segment_seconds: int = 0
    started_at: str = field(default_factory=_utc_now)
    meta_path: Path = field(init=False)
    stop_event: threading.Event = field(default_factory=threading.Event)
    thread: threading.Thread | None = None
    reader: threading.Thread | None = None
    streams: dict[str, queue.Queue] = field(default_factory=dict)
    stream_lock: threading.Lock = field(default_factory=threading.Lock)
    mic_enabled: bool = False
    mic_error: str | None = None
    mic_denied: bool = False
    wave_file: wave.Wave_write | None = None
    wave_path: Path | None = None
    segment_index: int = 0
    segment_frames: int = 0
    segments: list[dict[str, Any]] = field(default_factory=list)
    compress_queue: queue.Queue = field(default_factory=queue.Queue)
    compressor: threading.Thread | None = None
    compressing: int = 0
    compress_error: str | None = None
    fade_next: bool = True
    frames: int = 0
    level: float = 0.0
    peak: float = 0.0
    max_rms: float = 0.0
    dropped: int = 0
    error: str | None = None
    finalized: bool = False
    finalize_lock: threading.Lock = field(default_factory=threading.Lock)
    # Three threads persist meta (reader on mic toggles, writer on segment
    # roll, compressor on each finished part); overlapping rewrites fail on
    # Windows with a sharing violation, so every write takes this lock.
    meta_lock: threading.RLock = field(default_factory=threading.RLock)

    def __post_init__(self) -> None:
        self.meta_path = self.directory / "meta.json"
        self.mic_enabled = any(capture.role == "mic" for capture in self.inputs)

    @property
    def has_system(self) -> bool:
        return any(capture.role == "system" for capture in self.inputs)

    @property
    def elapsed(self) -> float:
        return self.frames / float(self.sample_rate) if self.sample_rate else 0.0

    @property
    def segment_remaining(self) -> float:
        """Seconds until the current segment is full (0 when not segmenting)."""
        if not self.segment_seconds:
            return 0.0
        return max(0.0, self.segment_seconds - self.segment_frames / self.sample_rate)

    def wav_bytes(self) -> int:
        total = sum(int(item.get("wav_bytes") or 0) for item in self.segments)
        path = self.wave_path
        if path is not None and path.exists():
            try:
                total += path.stat().st_size
            except OSError:
                pass
        return total

    def mp3_bytes(self) -> int:
        return sum(int(item.get("mp3_bytes") or 0) for item in self.segments)

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
                "source": self.source,
                "silent": payload.get("silent", False),
                "wav_bytes": payload.get("wav_bytes") or self.wav_bytes(),
                "mp3_bytes": payload.get("mp3_bytes") or self.mp3_bytes(),
                "segmentation_seconds": self.segment_seconds,
                "segments": payload.get("segments") or list(self.segments),
                "compressing": self.compressing,
                "mic_enabled": self.mic_enabled,
                "mic_error": self.mic_error,
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
        with self.meta_lock:
            payload = self.meta()
            payload.update(changes)
            _write_json(self.meta_path, payload)
            return payload

    def start(self) -> None:
        self.save_meta(status="recording", ended_at=None, duration_seconds=0.0)
        self.compressor = threading.Thread(
            target=self._compress_loop,
            name=f"system-audio-{self.id}-compress",
            daemon=True,
        )
        self.compressor.start()
        self.thread = threading.Thread(
            target=self._capture, name=f"system-audio-{self.id}", daemon=True
        )
        self.thread.start()

    # -- microphone ----------------------------------------------------------

    def set_microphone(self, enabled: bool) -> None:
        """Turn the microphone on or off without touching the system stream."""
        if self.finalized or self.stop_event.is_set():
            raise ConflictError("This recording has already stopped.")
        if not self.has_system and not enabled:
            raise ValidationError(
                "This recording is microphone-only, so it cannot be muted. Start a "
                "System audio + Mic recording to toggle the microphone live."
            )
        self.mic_enabled = enabled
        if enabled:
            # A previous permission/device failure must not block a fresh attempt.
            self.mic_denied = False
            self.mic_error = None
        self.save_meta(
            mic_enabled=enabled, mic_error=None if enabled else self.mic_error
        )

    # -- capture pipeline ----------------------------------------------------

    def _capture(self) -> None:
        """Writer thread: owns the WAV files and consumes the reader queues."""
        try:
            self._open_wave()
            self.reader = threading.Thread(
                target=self._read,
                name=f"system-audio-{self.id}-capture",
                daemon=True,
            )
            self.reader.start()
            self._write_loop()
        except Exception as exc:  # pragma: no cover - device/driver specific
            self.error = self.error or f"Recording stopped: {exc}"
            self.stop_event.set()
        finally:
            self.stop_event.set()
            self.level = 0.0
            self._finish_segment()

    def _safe_meta(self, **changes: Any) -> None:
        """Persist state from the audio thread without ever stopping capture."""
        try:
            self.save_meta(**changes)
        except Exception:  # pragma: no cover - disk hiccup
            pass

    def _register_stream(self, role: str) -> None:
        with self.stream_lock:
            self.streams[role] = queue.Queue(maxsize=QUEUE_BLOCKS)

    def _drop_stream(self, role: str) -> None:
        with self.stream_lock:
            self.streams.pop(role, None)

    def _open_device(self, capture: _CaptureInput, role: str) -> Any:
        recorder = capture.device.recorder(
            samplerate=self.sample_rate,
            channels=self.channels,
            blocksize=BUFFER_FRAMES,
        )
        recorder.__enter__()
        self.dropped += self._drain_backlog(recorder)
        recorder._poll_mode = True
        self._register_stream(role)
        return recorder

    def _read(self) -> None:
        """Reader thread: hand every open device the same 10 ms block, every 10 ms.

        One thread for all devices keeps them sample-aligned: each tick
        contributes exactly one block per input. A thread per device drifts and
        starves, which slides the microphone against the loopback by whole
        blocks - a voice heard on both then cancels and returns, and that is
        audible as scratching.

        The microphone is opened and closed *inside* this loop so it can be
        toggled mid-recording: the system stream keeps ticking at exactly the
        same pace whether the microphone is on or off.
        """
        recorders: dict[str, Any] = {}
        filters: dict[str, _Highpass | None] = {}
        pending: dict[str, np.ndarray] = {}
        drained = 0
        try:
            for capture in self.inputs:
                try:
                    recorders[capture.role] = self._open_device(capture, capture.role)
                except Exception as exc:
                    if capture.role == "mic":
                        self.mic_error = f"Microphone unavailable: {exc}"
                        self.mic_enabled = False
                        self.mic_denied = True
                        continue
                    raise
                filters[capture.role] = (
                    _Highpass(self.sample_rate) if capture.highpass else None
                )
                pending[capture.role] = np.zeros((0, self.channels), dtype=np.float32)

            tick = BLOCK_FRAMES / float(self.sample_rate)
            next_tick = time.perf_counter()
            while True:
                stopping = self.stop_event.is_set()
                if stopping and drained >= DRAIN_TICKS:
                    break
                self._sync_microphone(recorders, filters, pending)
                for role, recorder in list(recorders.items()):
                    pending[role] = self._collect(recorder, pending[role])
                    block, pending[role] = self._take(pending[role])
                    highpass = filters.get(role)
                    if highpass is not None:
                        block = highpass.process(block)
                    sink = self.streams.get(role)
                    if sink is None:
                        continue
                    try:
                        sink.put_nowait(block)
                    except queue.Full:
                        self.dropped += 1
                if stopping:
                    drained += 1
                next_tick += tick
                delay = next_tick - time.perf_counter()
                if delay > 0:
                    time.sleep(delay)
                elif delay < -1.0:
                    # Far behind (suspend, heavy load): do not try to replay
                    # the lost wall time as audio.
                    next_tick = time.perf_counter()
        except Exception as exc:  # pragma: no cover - device/driver specific
            self.error = self.error or f"Recording stopped: {exc}"
            self.stop_event.set()
        finally:
            for recorder in recorders.values():
                try:
                    recorder.__exit__(None, None, None)
                except Exception:  # pragma: no cover - device teardown
                    pass

    def _sync_microphone(
        self,
        recorders: dict[str, Any],
        filters: dict[str, _Highpass | None],
        pending: dict[str, np.ndarray],
    ) -> None:
        """Open the microphone when the user turns it on, close it when off."""
        if self.mic_enabled and "mic" not in recorders and not self.mic_denied:
            try:
                device, _name = _microphone_device()
                recorders["mic"] = self._open_device(
                    _CaptureInput(device, _name, "mic"), "mic"
                )
            except ServiceUnavailableError as exc:
                self.mic_error = f"Microphone unavailable: {exc}"
                self.mic_enabled = False
                self.mic_denied = True
                self._safe_meta(mic_enabled=False, mic_error=self.mic_error)
                return
            filters["mic"] = _Highpass(self.sample_rate)
            pending["mic"] = np.zeros((0, self.channels), dtype=np.float32)
            self.mic_error = None
            self._safe_meta(mic_enabled=True, mic_error=None)
        elif not self.mic_enabled and "mic" in recorders:
            if self.has_system:
                try:
                    recorders["mic"].__exit__(None, None, None)
                except Exception:  # pragma: no cover - device teardown
                    pass
                recorders.pop("mic", None)
                filters.pop("mic", None)
                pending.pop("mic", None)
                self._drop_stream("mic")

    def _collect(self, recorder: Any, pending: np.ndarray) -> np.ndarray:
        """Append whatever a device has ready to its pending buffer."""
        chunk = np.asarray(recorder.record(numframes=None), dtype=np.float32)
        if chunk.size == 0:
            return pending
        chunk = self._widen(chunk)
        merged = chunk if not len(pending) else np.concatenate([pending, chunk], axis=0)
        if len(merged) > MAX_PENDING_FRAMES:
            # Kept only when a device clock runs fast; drop the oldest audio
            # so the delay does not grow without bound.
            merged = merged[-MAX_PENDING_FRAMES:].copy()
            self.dropped += 1
        return merged

    def _take(self, pending: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        """Cut one block off a pending buffer, padding if the device is late."""
        if len(pending) >= BLOCK_FRAMES:
            return pending[:BLOCK_FRAMES], pending[BLOCK_FRAMES:].copy()
        block = np.zeros((BLOCK_FRAMES, self.channels), dtype=np.float32)
        if len(pending):
            block[: len(pending)] = pending
        return block, np.zeros((0, self.channels), dtype=np.float32)

    def _drain_backlog(self, recorder: Any) -> int:
        """Discard frames that piled up in a device before capture started."""
        dropped = 0
        try:
            available = int(recorder._capture_available_frames())
            while available > FRESH_FRAMES:
                block = recorder.record(numframes=min(BLOCK_FRAMES, available))
                dropped += len(block)
                available = int(recorder._capture_available_frames())
        except Exception:  # pragma: no cover - not every backend exposes it
            return dropped
        return dropped

    def _write_loop(self) -> None:
        self._await_prefill()
        fade = min(FADE_FRAMES, BLOCK_FRAMES)
        while True:
            readers_done = self.reader is None or not self.reader.is_alive()
            idle = all(sink.empty() for sink in list(self.streams.values()))
            if self.stop_event.is_set() and readers_done and idle:
                break
            blocks = self._pull_blocks()
            samples = self._mix(blocks)
            if self.fade_next and len(samples):
                self._fade(samples, fade, fade_in=True)
                self.fade_next = False
            if self.stop_event.is_set() and readers_done and idle and len(samples):
                self._fade(samples, fade, fade_in=False)
            peak = float(np.max(np.abs(samples))) if samples.size else 0.0
            rms = float(np.sqrt(np.mean(samples * samples))) if samples.size else 0.0
            self.peak = max(self.peak, peak)
            self.max_rms = max(self.max_rms, rms)
            self.level = min(1.0, peak)
            if len(samples):
                pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2")
                assert self.wave_file is not None
                self.wave_file.writeframes(pcm.tobytes())
                self.frames += len(samples)
                self.segment_frames += len(samples)
                if (
                    self.segment_seconds
                    and self.segment_frames >= self.segment_seconds * self.sample_rate
                    and not self.stop_event.is_set()
                ):
                    self._roll_segment()
            if self.elapsed >= MAX_SECONDS:
                self.stop_event.set()
                break

    def _await_prefill(self) -> None:
        """Start writing once every input has a few blocks buffered.

        The reader feeds all inputs in lock-step, so the queues stay equally
        full; this only avoids writing the first few milliseconds as zeros.
        """
        deadline = time.monotonic() + 3.0
        while time.monotonic() < deadline and not self.stop_event.is_set():
            with self.stream_lock:
                sinks = list(self.streams.values())
            if sinks and all(sink.qsize() >= PREFILL_BLOCKS for sink in sinks):
                return
            if self.reader is None or not self.reader.is_alive():
                return
            time.sleep(0.005)

    def _pull_blocks(self) -> list[np.ndarray]:
        blocks: list[np.ndarray] = []
        empty = np.zeros((BLOCK_FRAMES, self.channels), dtype=np.float32)
        with self.stream_lock:
            sinks = list(self.streams.values())
        for sink in sinks:
            if sink.qsize() > RESYNC_BLOCKS:
                # A real clock difference between the devices, not jitter: keep
                # the backlog short instead of letting the streams slide apart.
                while sink.qsize() > PREFILL_BLOCKS:
                    try:
                        sink.get_nowait()
                    except queue.Empty:
                        break
                self.dropped += 1
            try:
                block = sink.get(timeout=0.5)
            except queue.Empty:
                block = None
            blocks.append(empty.copy() if block is None else block)
        return blocks

    def _mix(self, blocks: list[np.ndarray]) -> np.ndarray:
        """Combine the concurrent inputs into one stereo block.

        The inputs are summed at full level, so a meeting through the loopback
        keeps its original loudness while the microphone adds the local speaker.
        If both are loud at once the block is scaled back instead of clipping.
        """
        if not blocks:
            return np.zeros((BLOCK_FRAMES, self.channels), dtype=np.float32)
        if len(blocks) == 1:
            mixed = blocks[0]
        else:
            length = max(len(block) for block in blocks)
            mixed = np.zeros((length, self.channels), dtype=np.float32)
            for block in blocks:
                mixed[: len(block)] += block
        peak = float(np.max(np.abs(mixed))) if mixed.size else 0.0
        if peak > 0.99:
            mixed = mixed * (0.99 / peak)
        return mixed

    def _fade(self, samples: np.ndarray, frames: int, *, fade_in: bool) -> None:
        frames = min(frames, len(samples))
        if frames <= 0:
            return
        ramp = np.linspace(0.0, 1.0, frames, dtype=np.float32)
        if fade_in:
            samples[:frames] *= ramp[:, None]
        else:
            samples[-frames:] *= ramp[::-1, None]

    def _widen(self, block: np.ndarray) -> np.ndarray:
        """Normalise any input block to the recording's channel count."""
        if block.ndim == 1:
            block = block.reshape(-1, 1)
        if block.shape[1] == 1 and self.channels == 2:
            return np.repeat(block, 2, axis=1)
        if block.shape[1] > self.channels:
            return block[:, : self.channels]
        if block.shape[1] < self.channels:
            repeats = int(np.ceil(self.channels / block.shape[1]))
            return np.tile(block, (1, repeats))[:, : self.channels]
        return block

    # -- segmentation --------------------------------------------------------

    def _open_wave(self) -> None:
        name = (
            f"audio-{self.segment_index + 1:02d}.wav"
            if self.segment_seconds
            else "audio.wav"
        )
        path = self.directory / name
        handle = wave.open(str(path), "wb")
        handle.setnchannels(self.channels)
        handle.setsampwidth(2)
        handle.setframerate(self.sample_rate)
        self.segment_index += 1
        self.wave_file = handle
        self.wave_path = path
        self.segment_frames = 0
        self.fade_next = True

    def _roll_segment(self) -> None:
        """Close the full segment, queue its compression, and carry on."""
        self._finish_segment()
        if not self.stop_event.is_set():
            self._open_wave()

    def _finish_segment(self) -> None:
        handle = self.wave_file
        if handle is None:
            return
        path = self.wave_path
        frames = self.segment_frames
        try:
            handle.close()
        except Exception:  # pragma: no cover - already closed
            pass
        self.wave_file = None
        self.wave_path = None
        self.segment_frames = 0
        if path is None or not path.exists():
            return
        try:
            size = path.stat().st_size
        except OSError:
            return
        if size <= 44 or frames <= 0:
            # Nothing was written (a start that failed before audio arrived).
            try:
                path.unlink(missing_ok=True)
            except OSError:
                pass
            return
        entry = {
            "index": self.segment_index,
            "file": path.name,
            "duration_seconds": round(frames / float(self.sample_rate), 2),
            "wav_bytes": size,
            "mp3_bytes": 0,
            "speech_bytes": 0,
            "status": "compressing",
            "error": None,
        }
        self.segments.append(entry)
        self.compress_queue.put((len(self.segments) - 1, path))
        self.save_meta(segments=list(self.segments))

    def _compress_loop(self) -> None:
        """Compress finished segments in the background, in order."""
        while True:
            item = self.compress_queue.get()
            if item is None:
                return
            position, path = item
            self.compressing += 1
            try:
                mp3_path = path.with_suffix(".mp3")
                mp3_bytes = _encode_mp3(path, mp3_path, bit_rate=160)
                speech_path = path.with_name(f"{path.stem}.speech.mp3")
                speech_bytes = _encode_mp3(
                    path, speech_path, bit_rate=64, downmix_mono=True
                )
                self._update_segment(
                    position,
                    status="compressed",
                    mp3_bytes=mp3_bytes,
                    speech_bytes=speech_bytes,
                    error=None,
                )
            except Exception as exc:  # pragma: no cover - encoder dependent
                self.compress_error = f"Compression failed: {exc}"
                self._update_segment(
                    position, status="failed", error=f"Compression failed: {exc}"
                )
            finally:
                self.compressing -= 1

    def _update_segment(self, position: int, **changes: Any) -> None:
        if 0 <= position < len(self.segments):
            self.segments[position].update(changes)
            self.save_meta(segments=list(self.segments))

    def wait_for_compression(self, timeout: float = 1800.0) -> None:
        compressor = self.compressor
        if compressor is None:
            return
        self.compress_queue.put(None)
        compressor.join(timeout=timeout)

    def stop(self) -> None:
        self.stop_event.set()
        if self.thread is not None:
            self.thread.join(timeout=8.0)
        if self.reader is not None:
            self.reader.join(timeout=2.0)
        self._finish_segment()


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
        source: str = "both",
        segment_seconds: int = 0,
    ) -> dict[str, Any]:
        with self._lock:
            if self._active is not None and not self._active.finalized:
                if not self._active.stop_event.is_set():
                    raise ConflictError(
                        "A system-audio recording is already running. Stop it first."
                    )
                self._finalize(self._active)
            microphones, device, resolved_source = _input_devices(source)
            recording_id = uuid.uuid4().hex[:12]
            directory = self.root / recording_id
            directory.mkdir(parents=True, exist_ok=True)
            recording = _ActiveRecording(
                id=recording_id,
                directory=directory,
                inputs=microphones,
                device=device,
                label=_clean_label(label, f"Recording {datetime.now():%d %b %H:%M}"),
                sample_rate=sample_rate,
                channels=channels,
                source=resolved_source,
                segment_seconds=max(0, min(MAX_SEGMENT_SECONDS, int(segment_seconds))),
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
                "source": recording.source,
                "segment_seconds": recording.segment_seconds,
                "mic_enabled": recording.mic_enabled,
                "mic_error": recording.mic_error,
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
            "source": active.source,
            "started_at": active.started_at,
            "elapsed_seconds": round(active.elapsed, 2),
            "level": round(active.level, 4),
            "sample_rate": active.sample_rate,
            "channels": active.channels,
            "max_seconds": MAX_SECONDS,
            "segment_seconds": active.segment_seconds,
            "segments_completed": len(active.segments),
            "segment_elapsed_seconds": round(
                active.segment_frames / float(active.sample_rate), 2
            ),
            "compressing": active.compressing,
            "mic_enabled": active.mic_enabled,
            "mic_error": active.mic_error,
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
            # Compression of the finished parts runs in a background thread so
            # it never interrupts capture. A stop waits for it, so the sizes the
            # user sees before saving or sharing are the real final sizes.
            recording.wait_for_compression()
            wav_bytes = recording.wav_bytes()
            mp3_bytes = recording.mp3_bytes()
            error = recording.error or recording.compress_error
            # Peak alone is not enough: one click in an otherwise silent file
            # would mark it as containing audio. Use the loudest 10 ms block.
            silent = recording.max_rms < 3e-4
            status = "ready" if not recording.error else "failed"
            if wav_bytes <= 44:
                status = "failed"
                error = (
                    error or "Nothing was captured. Is audio playing on this device?"
                )
            elif any(part.get("status") == "failed" for part in recording.segments):
                error = error or "Some parts could not be compressed to MP3."
            recording.finalized = True
            recording.save_meta(
                status=status,
                ended_at=_utc_now(),
                duration_seconds=round(recording.elapsed, 2),
                wav_bytes=wav_bytes,
                mp3_bytes=mp3_bytes,
                silent=silent,
                error=error,
                segments=list(recording.segments),
                compressing=0,
                mic_enabled=recording.mic_enabled,
                mic_error=recording.mic_error,
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
        path = directory / ("audio.wav" if fmt == "wav" else "audio.mp3")
        if path.exists():
            return path
        # Segmented recordings keep one file per part; the first part stands in
        # for "the recording" when a client asks for a single file.
        for entry in self.get(recording_id).get("segments") or []:
            stem = Path(str(entry.get("file") or "")).stem
            candidate = directory / f"{stem}.{fmt}"
            if candidate.exists():
                return candidate
        raise NotFoundError("Recording file", f"{recording_id}.{fmt}")

    def path_for_segment(self, recording_id: str, index: int, fmt: str) -> Path:
        if index < 1:
            raise ValidationError("Segment numbers start at 1.")
        directory = self._directory(recording_id)
        candidate = directory / f"audio-{index:02d}.{fmt}"
        if not candidate.exists():
            raise NotFoundError(
                "Recording part", f"{recording_id} part {index} ({fmt})"
            )
        return candidate

    # -- virtual (browser-captured) recordings ------------------------------

    def save_virtual(
        self,
        *,
        data: bytes,
        label: str | None,
        duration_seconds: float,
        mime_type: str,
        media_type: str,
        sources: list[str],
        started_at: str | None = None,
        speech_data: bytes | None = None,
        speech_mime: str | None = None,
    ) -> dict[str, Any]:
        """Store one finished browser capture in the shared recordings store.

        [data] is the exact blob the browser produced (audio or video). When a
        video recording was captured, [speech_data] carries the parallel
        audio-only track so transcription does not depend on the video
        container being accepted by the speech provider.
        """
        if not data:
            raise ValidationError("The browser produced an empty recording.")
        if len(data) > MAX_VIRTUAL_BYTES:
            raise ValidationError(
                "The recording is larger than the 2 GB limit. Record a shorter "
                "session or lower the browser capture quality."
            )
        base_mime = (mime_type or "").split(";")[0].strip().lower()
        media = (media_type or "audio").strip().lower()
        if media not in {"audio", "video"}:
            raise ValidationError("Media type must be audio or video.")
        if base_mime not in VIRTUAL_MIME_EXT:
            raise ValidationError(
                f"The browser reported an unsupported recording type '{mime_type}'. "
                f"Supported formats: {', '.join(sorted(VIRTUAL_MIME_EXT))}."
            )
        if not base_mime.startswith(f"{media}/"):
            raise ValidationError(
                f"The recording type '{base_mime}' does not match a {media} recording."
            )
        duration = max(0.0, float(duration_seconds or 0.0))
        if duration > MAX_SECONDS:
            raise ValidationError(
                "The recording is longer than the 90 minute limit. Save a shorter "
                "session so the library stays usable."
            )

        recording_id = uuid.uuid4().hex[:12]
        directory = self.root / recording_id
        directory.mkdir(parents=True, exist_ok=False)
        extension = VIRTUAL_MIME_EXT[base_mime]
        main_name = f"media.{extension}"
        try:
            (directory / main_name).write_bytes(data)

            speech_name: str | None = None
            speech_type: str | None = None
            if speech_data:
                speech_base = (
                    (speech_mime or "audio/webm").split(";")[0].strip().lower()
                )
                speech_ext = VIRTUAL_MIME_EXT.get(speech_base, "webm")
                speech_name = f"speech.{speech_ext}"
                speech_type = speech_base
                (directory / speech_name).write_bytes(speech_data)
            elif media == "audio":
                speech_name = main_name
                speech_type = base_mime

            now = _utc_now()
            meta: dict[str, Any] = {
                "id": recording_id,
                "label": _clean_label(label, "Virtual recording"),
                "status": "ready",
                "kind": "virtual",
                "media_type": media,
                "format": extension,
                "mime_type": base_mime,
                "size_bytes": len(data),
                "sources": sources,
                "file": main_name,
                "speech_file": speech_name,
                "speech_mime": speech_type,
                "started_at": started_at or now,
                "ended_at": now,
                "duration_seconds": round(duration, 3),
                "sample_rate": 0,
                "channels": 0,
                "device": "Browser capture",
                "source": "virtual",
                "silent": False,
                "wav_bytes": 0,
                "mp3_bytes": 0,
                "segmentation_seconds": 0,
                "segments": [],
                "compressing": 0,
                "mic_enabled": "mic" in sources,
                "mic_error": None,
                "transcript": None,
                "summary": None,
                "summary_style": None,
                "provider": None,
                "model": None,
                "error": None,
                "translation": None,
                "translation_language": None,
                "playable": True,
            }
            _write_json(directory / "meta.json", meta)
            return meta
        except Exception:
            # A partially written directory would show up in the library as a
            # broken recording, so remove it and let the caller report failure.
            shutil.rmtree(directory, ignore_errors=True)
            raise

    def path_for_media(self, recording_id: str) -> tuple[Path, str]:
        """The playable file for any recording and its real content type."""
        meta = self.get(recording_id)
        if meta.get("kind") == "virtual":
            name = meta.get("file")
            if isinstance(name, str) and name:
                path = self._directory(recording_id) / name
                if path.exists():
                    mime = str(
                        meta.get("mime_type") or "application/octet-stream"
                    ).split(";")[0]
                    return path, mime
            raise NotFoundError("Recording media", recording_id)
        return self.path_for(recording_id, "mp3"), "audio/mpeg"

    def rename(self, recording_id: str, label: str) -> dict[str, Any]:
        cleaned = (label or "").strip()
        if not cleaned:
            raise ValidationError("Enter a name for the recording.")
        return self._update_meta(recording_id, label=cleaned[:120])

    def _delivery_files(
        self, recording_id: str, formats: list[str]
    ) -> list[tuple[str, Path]]:
        """The exact files to copy or send, in part order."""
        directory = self._directory(recording_id)
        meta = self.get(recording_id)
        if meta.get("kind") == "virtual":
            path, _ = self.path_for_media(recording_id)
            return [(path.name, path)]
        files: list[tuple[str, Path]] = []
        for entry in meta.get("segments") or []:
            stem = Path(str(entry.get("file") or "audio.wav")).stem
            for fmt in formats:
                path = directory / f"{stem}.{fmt}"
                if path.exists():
                    files.append((path.name, path))
        if not files:
            for fmt in formats:
                path = directory / f"audio.{fmt}"
                if path.exists():
                    files.append((path.name, path))
        return files

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

    def set_microphone(self, enabled: bool) -> dict[str, Any]:
        """Turn the microphone on or off while system audio keeps recording."""
        active = self._active
        if active is None or active.finalized:
            raise ConflictError("Start a recording before toggling the microphone.")
        active.set_microphone(enabled)
        return self.status()

    # -- delivery ------------------------------------------------------------

    def deliver(
        self,
        recording_id: str,
        *,
        folder: str | None = None,
        create_folder: bool = True,
        whatsapp: str | None = None,
        email: str | None = None,
        formats: list[str] | None = None,
        include_summary: bool = True,
        note: str | None = None,
    ) -> dict[str, Any]:
        """Save to a folder and/or prepare WhatsApp and email hand-offs.

        A folder copy happens here, on the machine running the backend. WhatsApp
        and email need the user's own app (a browser cannot attach a file to a
        wa.me or mailto link), so those return an actionable link plus the file
        names to attach - the documented fallback rather than a silent failure.
        """
        meta = self._finalize_if_needed(recording_id)
        wanted = [f for f in (formats or ["mp3"]) if f in {"wav", "mp3"}] or ["mp3"]
        files = self._delivery_files(recording_id, wanted)
        if not files:
            raise ValidationError(
                "This recording has no finished audio files to deliver yet."
            )
        if folder is None and not whatsapp and not email:
            raise ValidationError(
                "Choose at least one destination: a folder, WhatsApp or email."
            )
        results: list[dict[str, Any]] = []
        if folder is not None:
            results.append(self._deliver_folder(files, folder, create_folder))
        if whatsapp:
            results.append(
                self._deliver_link(
                    "whatsapp", files, whatsapp, meta, include_summary, note
                )
            )
        if email:
            results.append(
                self._deliver_link("email", files, email, meta, include_summary, note)
            )
        return {
            "recording_id": recording_id,
            "label": meta.get("label"),
            "files": [
                {"name": name, "bytes": path.stat().st_size} for name, path in files
            ],
            "results": results,
        }

    def _deliver_folder(
        self, files: list[tuple[str, Path]], folder: str, create_folder: bool
    ) -> dict[str, Any]:
        raw = (folder or "").strip()
        if not raw:
            raise ValidationError("Enter the folder where the recordings should go.")
        target = Path(raw).expanduser()
        if not target.is_absolute():
            raise ValidationError(
                "Enter an absolute folder path, for example "
                r"C:\Users\You\Music\Penrose recordings."
            )
        try:
            if not target.exists():
                if not create_folder:
                    raise ValidationError(
                        f'{target} does not exist. Tick "Create the folder" to make it.'
                    )
                target.mkdir(parents=True, exist_ok=True)
            if not target.is_dir():
                raise ValidationError(f"{target} is a file, not a folder.")
        except ValidationError:
            raise
        except OSError as exc:
            raise ServiceUnavailableError(
                f"Could not open {target}: {exc}. Check the path and permissions."
            ) from exc
        saved: list[dict[str, Any]] = []
        failed: list[dict[str, Any]] = []
        for name, path in files:
            destination = target / name
            try:
                shutil.copy2(path, destination)
                saved.append(
                    {
                        "name": name,
                        "path": str(destination),
                        "bytes": destination.stat().st_size,
                    }
                )
            except OSError as exc:
                failed.append({"name": name, "error": str(exc)})
        status = "saved" if saved and not failed else ("partial" if saved else "failed")
        detail = (
            f"Saved {len(saved)} file(s) to {target}."
            if saved and not failed
            else (
                f"Saved {len(saved)} file(s); {len(failed)} could not be copied."
                if saved
                else f"Nothing could be saved to {target}."
            )
        )
        return {
            "destination": "folder",
            "status": status,
            "folder": str(target),
            "detail": detail,
            "files": saved,
            "failed": failed,
        }

    def _deliver_link(
        self,
        destination: str,
        files: list[tuple[str, Path]],
        address: str,
        meta: dict[str, Any],
        include_summary: bool,
        note: str | None,
    ) -> dict[str, Any]:
        label = (meta.get("label") or "Penrose recording").strip()
        total = sum(path.stat().st_size for _name, path in files)
        lines = [label, ""]
        if note and note.strip():
            lines += [note.strip(), ""]
        lines.append(
            "Recording: "
            f"{round(float(meta.get('duration_seconds') or 0) / 60, 1)} min, "
            f"{len(files)} file(s), {total / (1024 * 1024):.1f} MB."
        )
        if include_summary:
            summary = (meta.get("summary") or "").strip()
            if summary:
                lines += ["", summary[:1800]]
        lines += ["", "Files: " + ", ".join(name for name, _ in files)]
        body = "\n".join(lines)

        if destination == "email":
            target = (address or "").strip()
            if not EMAIL_PATTERN.match(target):
                raise ValidationError(
                    "Enter a valid email address, for example name@example.com."
                )
            subject = quote(f"Penrose recording — {label}")
            link = f"mailto:{quote(target)}?subject={subject}&body={quote(body)}"
            detail = (
                "Email needs your mail app, which a web page cannot open with a "
                "file attached. The files were prepared; open the link, then attach them."
            )
            return {
                "destination": "email",
                "status": "action_required",
                "address": target,
                "link": link,
                "files": [name for name, _ in files],
                "detail": detail,
            }

        digits = re.sub(r"\D", "", address or "")
        if not 8 <= len(digits) <= 15:
            raise ValidationError(
                "Enter a WhatsApp number with its country code, for example +265 991 123 456."
            )
        link = f"https://wa.me/{digits}?text={quote(body)}"
        detail = (
            "WhatsApp needs its own app to attach a file. The chat opens with the "
            "message; attach the downloaded files."
        )
        return {
            "destination": "whatsapp",
            "status": "action_required",
            "address": f"+{digits}",
            "link": link,
            "files": [name for name, _ in files],
            "detail": detail,
        }

    # -- AI ------------------------------------------------------------------

    def transcribe(
        self, recording_id: str, language: str | None = None
    ) -> dict[str, Any]:
        meta = self._finalize_if_needed(recording_id)
        directory = self._directory(recording_id)
        sources = self._speech_media(recording_id)
        if not sources:
            raise ValidationError("This recording has no audio to transcribe.")
        parts: list[str] = []
        provider: str | None = None
        model: str | None = None
        for index, (source, mime) in enumerate(sources, start=1):
            if source.stat().st_size > STT_BYTES_LIMIT:
                raise ValidationError(
                    f"{source.name} is too long for one transcription request "
                    "(about 50 minutes of MP3). Use a shorter segment length so "
                    "each part stays under the limit."
                )
            result = SpeechService().transcribe(
                source.read_bytes(), mime, language=language
            )
            transcript_part = (result.get("transcript") or "").strip()
            provider = provider or result.get("provider")
            model = model or result.get("model")
            if transcript_part:
                parts.append(
                    transcript_part
                    if len(sources) == 1
                    else f"[Part {index}]\n{transcript_part}"
                )
        transcript = "\n\n".join(parts).strip()
        if not transcript:
            raise ServiceUnavailableError("Transcription returned no text.")
        (directory / "transcript.txt").write_text(transcript, encoding="utf-8")
        meta = self._update_meta(
            recording_id,
            status="transcribed",
            transcript=transcript,
            provider=provider,
            model=model,
            error=None,
        )
        return meta

    def _speech_media(self, recording_id: str) -> list[tuple[Path, str]]:
        """The speech files for a recording, one per part, with their real type.

        Browser captures store a parallel audio-only track when the main media
        is video, so the provider receives a format it accepts instead of a
        video container.
        """
        directory = self._directory(recording_id)
        meta = self.get(recording_id)
        if meta.get("kind") == "virtual":
            name = meta.get("speech_file")
            if isinstance(name, str) and name:
                path = directory / name
                if path.exists():
                    mime = str(meta.get("speech_mime") or "")
                    if not mime:
                        mime = {
                            "webm": "audio/webm",
                            "ogg": "audio/ogg",
                            "m4a": "audio/mp4",
                            "mp3": "audio/mpeg",
                            "wav": "audio/wav",
                        }.get(path.suffix.lstrip(".").lower(), "audio/webm")
                    return [(path, mime.split(";")[0].strip())]
            return []
        segments = meta.get("segments") or []
        sources: list[tuple[Path, str]] = []
        if segments:
            for entry in segments:
                stem = Path(str(entry.get("file") or "audio.wav")).stem
                for candidate in (
                    directory / f"{stem}.speech.mp3",
                    directory / f"{stem}.mp3",
                ):
                    if candidate.exists():
                        sources.append((candidate, "audio/mpeg"))
                        break
            return sources
        for name in ("speech.mp3", "audio.speech.mp3", "audio.mp3"):
            candidate = directory / name
            if candidate.exists():
                sources.append((candidate, "audio/mpeg"))
                break
        return sources

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

    async def translate(
        self, recording_id: str, target_language: str
    ) -> dict[str, Any]:
        """Translate the stored transcript with the configured AI service.

        Translation only ever works from a transcript that already exists, so
        the UI cannot imply that capturing media performed speech recognition
        or translation by itself.
        """
        meta = self.get(recording_id)
        transcript = (meta.get("transcript") or "").strip()
        if not transcript:
            raise ValidationError("Transcribe the recording before translating it.")
        language = (target_language or "").strip()
        if len(language) < 2:
            raise ValidationError("Choose the language to translate into.")
        excerpt = transcript[:TRANSCRIPT_LIMIT]
        messages = [
            {
                "role": "system",
                "content": (
                    "You are an accurate translator. Translate the transcript "
                    "faithfully into the requested language. Preserve names, "
                    "numbers and meaning; never add commentary. Output only the "
                    "translated text in Markdown."
                ),
            },
            {
                "role": "user",
                "content": (
                    f"Translate this transcript into {language}.\n\n{excerpt}"
                    + (
                        "\n\n[Transcript truncated for length.]"
                        if len(transcript) > TRANSCRIPT_LIMIT
                        else ""
                    )
                ),
            },
        ]
        try:
            translation = await call_ai_text(
                messages, max_tokens=2400, temperature=0.2, timeout=120.0
            )
        except Exception as exc:
            raise ServiceUnavailableError(
                f"The translation could not be generated: {exc}"
            ) from exc
        translation = translation.strip()
        if not translation:
            raise ServiceUnavailableError("The AI returned an empty translation.")
        (self._directory(recording_id) / "translation.md").write_text(
            translation, encoding="utf-8"
        )
        return self._update_meta(
            recording_id,
            translation=translation,
            translation_language=language,
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
