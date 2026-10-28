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
import threading
import time
import uuid
import warnings
import wave
from contextlib import ExitStack
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
    started_at: str = field(default_factory=_utc_now)
    wav_path: Path = field(init=False)
    meta_path: Path = field(init=False)
    stop_event: threading.Event = field(default_factory=threading.Event)
    thread: threading.Thread | None = None
    readers: list[threading.Thread] = field(default_factory=list)
    queues: list[queue.Queue[np.ndarray]] = field(default_factory=list)
    wave_file: wave.Wave_write | None = None
    frames: int = 0
    level: float = 0.0
    peak: float = 0.0
    max_rms: float = 0.0
    dropped: int = 0
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
                "source": self.source,
                "silent": payload.get("silent", False),
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
        self.save_meta(status="recording", ended_at=None, duration_seconds=0.0)
        self.thread = threading.Thread(
            target=self._capture, name=f"system-audio-{self.id}", daemon=True
        )
        self.thread.start()

    # -- capture pipeline ----------------------------------------------------

    def _capture(self) -> None:
        """Writer thread: owns the WAV file and consumes the reader queues."""
        try:
            self.wave_file = wave.open(str(self.wav_path), "wb")
            self.wave_file.setnchannels(self.channels)
            self.wave_file.setsampwidth(2)
            self.wave_file.setframerate(self.sample_rate)
            self.queues = [queue.Queue(maxsize=QUEUE_BLOCKS) for _ in self.inputs]
            self.readers = [
                threading.Thread(
                    target=self._read,
                    name=f"system-audio-{self.id}-capture",
                    daemon=True,
                )
            ]
            for reader in self.readers:
                reader.start()
            self._write_loop()
        except Exception as exc:  # pragma: no cover - device/driver specific
            self.error = self.error or f"Recording stopped: {exc}"
            self.stop_event.set()
        finally:
            self.stop_event.set()
            self.level = 0.0
            self._close_wave()

    def _read(self) -> None:
        """Reader thread: hand every device the same 10 ms block, every 10 ms.

        One thread for all devices keeps them sample-aligned: each tick
        contributes exactly one block per input. A thread per device drifts and
        starves, which slides the microphone against the loopback by whole
        blocks - a voice heard on both then cancels and returns, and that is
        audible as scratching.

        Reads are polled rather than blocking, and the tick is paced by the
        wall clock. A blocking read lets one device (a quiet loopback, a mic
        that pauses) hold up the others; the lagging device then overflows its
        buffer and audio is lost. Polling keeps the clock honest and the disk
        writer in its own thread, so a slow write can never interrupt a read.
        """
        drained = 0
        try:
            with ExitStack() as stack:
                recorders = [
                    stack.enter_context(
                        capture.device.recorder(
                            samplerate=self.sample_rate,
                            channels=self.channels,
                            blocksize=BUFFER_FRAMES,
                        )
                    )
                    for capture in self.inputs
                ]
                for recorder in recorders:
                    # Start near-live: whatever the device buffered before we
                    # opened it is stale and would only delay this stream.
                    self.dropped += self._drain_backlog(recorder)
                    recorder._poll_mode = True
                filters = [
                    _Highpass(self.sample_rate) if capture.highpass else None
                    for capture in self.inputs
                ]
                pending = [
                    np.zeros((0, self.channels), dtype=np.float32) for _ in recorders
                ]
                tick = BLOCK_FRAMES / float(self.sample_rate)
                next_tick = time.perf_counter()
                while True:
                    stopping = self.stop_event.is_set()
                    if stopping and drained >= DRAIN_TICKS:
                        break
                    pending = self._collect(recorders, pending)
                    for index in range(len(recorders)):
                        block, pending[index] = self._take(pending[index])
                        highpass = filters[index]
                        if highpass is not None:
                            block = highpass.process(block)
                        try:
                            self.queues[index].put_nowait(block)
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

    def _collect(
        self, recorders: list[Any], pending: list[np.ndarray]
    ) -> list[np.ndarray]:
        """Append whatever each device has ready to its pending buffer."""
        for index, recorder in enumerate(recorders):
            chunk = np.asarray(recorder.record(numframes=None), dtype=np.float32)
            if chunk.size == 0:
                continue
            chunk = self._widen(chunk)
            pending[index] = (
                chunk
                if not len(pending[index])
                else np.concatenate([pending[index], chunk], axis=0)
            )
            if len(pending[index]) > MAX_PENDING_FRAMES:
                # Kept only when a device clock runs fast; drop the oldest audio
                # so the delay does not grow without bound.
                pending[index] = pending[index][-MAX_PENDING_FRAMES:].copy()
                self.dropped += 1
        return pending

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
        first_block = True
        while True:
            readers_done = not any(reader.is_alive() for reader in self.readers)
            if (
                self.stop_event.is_set()
                and readers_done
                and all(sink.empty() for sink in self.queues)
            ):
                break
            blocks = self._pull_blocks()
            samples = self._mix(blocks)
            if first_block and len(samples):
                self._fade(samples, fade, fade_in=True)
                first_block = False
            if (
                self.stop_event.is_set()
                and readers_done
                and all(sink.empty() for sink in self.queues)
                and len(samples)
            ):
                self._fade(samples, fade, fade_in=False)
            peak = float(np.max(np.abs(samples))) if samples.size else 0.0
            rms = float(np.sqrt(np.mean(samples * samples))) if samples.size else 0.0
            self.peak = max(self.peak, peak)
            self.max_rms = max(self.max_rms, rms)
            self.level = min(1.0, peak)
            pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2")
            assert self.wave_file is not None
            self.wave_file.writeframes(pcm.tobytes())
            self.frames += len(samples)
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
            if all(sink.qsize() >= PREFILL_BLOCKS for sink in self.queues):
                return
            if not any(reader.is_alive() for reader in self.readers):
                return
            time.sleep(0.005)

    def _pull_blocks(self) -> list[np.ndarray]:
        blocks: list[np.ndarray] = []
        empty = np.zeros((BLOCK_FRAMES, self.channels), dtype=np.float32)
        for sink in self.queues:
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
            return np.zeros((0, self.channels), dtype=np.float32)
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

    def _close_wave(self) -> None:
        try:
            if self.wave_file is not None:
                self.wave_file.close()
        except Exception:
            pass
        self.wave_file = None

    def stop(self) -> None:
        self.stop_event.set()
        if self.thread is not None:
            self.thread.join(timeout=8.0)
        for reader in self.readers:
            reader.join(timeout=2.0)
        self._close_wave()


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
            # Peak alone is not enough: one click in an otherwise silent file
            # would mark it as containing audio. Use the loudest 10 ms block.
            silent = recording.max_rms < 3e-4
            if wav_bytes > 44:
                try:
                    mp3_bytes = _encode_mp3(
                        recording.wav_path,
                        recording.directory / "audio.mp3",
                        bit_rate=160,
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
                silent=silent,
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
