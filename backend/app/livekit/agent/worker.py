"""LiveKit voice-agent worker for ScholarMW.

Composes four fully local / free components into a real-time voice tutor:

* STT  -> vosk (offline Kaldi small English model)
* VAD  -> silero (livekit-plugins-silero ONNX model)
* LLM  -> app.config.ai_client provider chain (HuggingFace -> Groq -> Cloudflare)
* TTS  -> edge-tts (free Microsoft neural voices)

Run as its own process (kept separate from the FastAPI server):

    python -m app.livekit.agent.worker dev   # run from the backend/ directory

The worker registers itself with LiveKit Cloud (`LIVEKIT_*` from backend/.env)
and answers jobs for room-based voice sessions.  The Flutter client connects to
the same room using a token from ``POST /livekit/token``.
"""

from __future__ import annotations

import asyncio
import json
import logging
import math
import os
import sys
import time
import uuid
from array import array
from functools import lru_cache
from pathlib import Path
from typing import Any

from livekit import rtc
from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    JobContext,
    llm,
    stt,
    tts,
    utils,
)
from livekit.agents.stt.stream_adapter import StreamAdapter, StreamAdapterWrapper
from livekit.agents.types import DEFAULT_API_CONNECT_OPTIONS, NOT_GIVEN
from livekit.agents.vad import VADEventType
from livekit.plugins import silero

from app.config.ai_client import call_ai_stream_with_fallback
from app.config.settings import get_settings

log = logging.getLogger("scholar.livekit")

# ---------------------------------------------------------------------------
# Tuning constants
# ---------------------------------------------------------------------------

EDGE_TTS_VOICE = "en-US-EmmaMultilingualNeural"
EDGE_TTS_RATE = "+0%"
EDGE_TTS_VOLUME = "+0%"
EDGE_TTS_PITCH = "+0Hz"
EDGE_TTS_SAMPLE_RATE = 24000
EDGE_TTS_CHANNELS = 1

VOSK_TARGET_SAMPLE_RATE = 16000  # vosk models are built for 16 kHz mono
VOSK_MODEL_NAME = "vosk-model-small-en-us-0.15"

# STT-only relay mode: when a web client joins a room whose name starts with
# this prefix, the worker does NOT run the conversational agent (LLM/TTS/OOD
# loop).  Instead it transcribes the participant's microphone with vosk and
# relays each final transcript back over a LiveKit data channel under STT_TOPIC.
STT_RELAY_ROOM_PREFIX = "scholar-stt-"
STT_RELAY_TOPIC = "scholar.stt"


def _frame_stats(frame: rtc.AudioFrame) -> tuple[float, str, int]:
    """Return (rms, data-type-name, num-int16-samples) for a debug frame."""
    data = frame.data
    dtype = type(data).__name__
    n = 0
    rms = 0.0
    try:
        if isinstance(data, memoryview):
            raw = data.tobytes()
        elif isinstance(data, (bytes, bytearray)):
            raw = bytes(data)
        else:
            raw = array("h", data).tobytes()
        usable = len(raw) - (len(raw) % 2)
        if usable:
            samples = array("h")
            samples.frombytes(raw[:usable])
            n = len(samples)
            rms = math.sqrt(sum(x * x for x in samples) / n) if samples else 0.0
    except Exception as e:  # noqa: BLE001 - debug logging must never raise
        rms = float("nan")
        dtype = f"{dtype}({type(e).__name__}: {e})"
    return rms, dtype, n


def _wrap_vad_debug(v: silero.VAD) -> silero.VAD:
    """Temporary: log VAD stream creation, pushed frames, and events."""

    orig_stream = v.stream

    def _stream_with_debug(*args: Any, **kwargs: Any) -> Any:
        s = orig_stream(*args, **kwargs)
        log.info("VAD_STREAM_CREATED")
        orig_push = s.push_frame
        cnt: dict[str, Any] = {"n": 0, "peak": 0.0}

        def _push(frame: rtc.AudioFrame) -> None:
            rms, dtype, n = _frame_stats(frame)
            cnt["n"] += 1
            if rms == rms:
                cnt["peak"] = max(cnt["peak"], float(rms))
            if cnt["n"] <= 3 or cnt["n"] % 100 == 0:
                log.info(
                    "VAD_PUSH n=%d rms=%.1f peak=%.1f sr=%d ch=%d dtype=%s samples=%d",
                    cnt["n"],
                    rms,
                    cnt["peak"],
                    frame.sample_rate,
                    frame.num_channels,
                    dtype,
                    n,
                )
            orig_push(frame)

        s.push_frame = _push
        return s

    v.stream = _stream_with_debug
    return v


@lru_cache(maxsize=1)
def _silero_vad() -> silero.VAD:
    """Shared silero VAD instance (one ONNX model load)."""
    return _wrap_vad_debug(silero.VAD.load())


# ---------------------------------------------------------------------------
# STT: vosk (offline)
# ---------------------------------------------------------------------------


class VoskSTT(stt.STT):
    """Offline speech-to-text built on the vosk Kaldi recognizer.

    This implementation only supports the ``recognize()`` path; it is combined
    with a silero ``StreamAdapter`` in the session so that LiveKit can stream
    microphone audio into it while the VAD marks speech segments.
    """

    def __init__(self, *, model_path: str | None = None) -> None:
        super().__init__(
            capabilities=stt.STTCapabilities(
                streaming=False,
                interim_results=False,
                offline_recognize=True,
            )
        )
        self._model_path = model_path or os.getenv("VOSK_MODEL_PATH", "")
        self._model: Any = None
        self._load_error: Exception | None = None
        self._lock = asyncio.Lock()

    @property
    def model(self) -> str:
        return "vosk-model-small-en-us"

    @property
    def provider(self) -> str:
        return "vosk"

    # -- model loading ------------------------------------------------------

    async def _ensure_model(self) -> Any:
        async with self._lock:
            if self._model is None and self._load_error is None:
                try:
                    self._model = await asyncio.to_thread(self._load_model)
                except Exception as e:  # noqa: BLE001 - surfaced to the caller
                    self._load_error = e
                    raise
            if self._load_error is not None:
                raise self._load_error
            return self._model

    def _load_model(self) -> Any:
        import vosk

        path = self._model_path
        if path and Path(path).is_dir():
            log.info("Loading vosk model from %s", path)
            return vosk.Model(path)

        log.info("Loading vosk model '%s' (auto-download if missing)", VOSK_MODEL_NAME)
        return vosk.Model(model_name=VOSK_MODEL_NAME)

    @classmethod
    def describe_model_issue(cls, err: Exception) -> str:
        return (
            "Vosk speech model unavailable: %s. "
            "Set VOSK_MODEL_PATH to an extracted model directory (e.g. "
            "vosk-model-small-en-us-0.15) or allow the auto-download from "
            "alphacephei.com/vosk/models." % err
        )

    # -- audio pipeline -----------------------------------------------------

    @staticmethod
    def _frame_to_mono_pcm16(frame: rtc.AudioFrame) -> bytes:
        data = frame.data
        if isinstance(data, memoryview):
            raw = data.tobytes()
        elif isinstance(data, (bytes, bytearray)):
            raw = bytes(data)
        else:
            raw = array("h", data).tobytes()
        if frame.num_channels == 1:
            return raw[: len(raw) - (len(raw) % 2)]
        values = array("h")
        values.frombytes(raw[: len(raw) - (len(raw) % 2)])
        count = frame.num_channels
        n = len(values) // count
        mono = array(
            "h",
            (sum(values[i * count : (i + 1) * count]) // count for i in range(n)),
        )
        return mono.tobytes()

    def _buffer_to_16k_mono_pcm(
        self, buffer: rtc.AudioFrame | list[rtc.AudioFrame] | tuple[rtc.AudioFrame, ...]
    ) -> bytes:
        frames = buffer if isinstance(buffer, (list, tuple)) else [buffer]
        chunks: list[bytes] = []
        resampler: rtc.AudioResampler | None = None
        for frame in frames:
            if frame.sample_rate != VOSK_TARGET_SAMPLE_RATE:
                if resampler is None:
                    resampler = rtc.AudioResampler(
                        frame.sample_rate,
                        VOSK_TARGET_SAMPLE_RATE,
                        quality=rtc.AudioResamplerQuality.HIGH,
                    )
                for resampled in resampler.push(frame):
                    chunks.append(self._frame_to_mono_pcm16(resampled))
            else:
                chunks.append(self._frame_to_mono_pcm16(frame))
        if resampler is not None:
            for resampled in resampler.flush():
                chunks.append(self._frame_to_mono_pcm16(resampled))
        return b"".join(chunks)

    # -- recognition --------------------------------------------------------

    async def _recognize_impl(
        self,
        buffer: rtc.AudioFrame | list[rtc.AudioFrame] | tuple[rtc.AudioFrame, ...],
        *,
        language: Any = NOT_GIVEN,
        conn_options: Any = DEFAULT_API_CONNECT_OPTIONS,
    ) -> stt.SpeechEvent:
        import vosk

        model = await self._ensure_model()
        pcm = await asyncio.to_thread(self._buffer_to_16k_mono_pcm, buffer)

        def _transcribe() -> str:
            recognizer = vosk.KaldiRecognizer(model, VOSK_TARGET_SAMPLE_RATE)
            recognizer.AcceptWaveform(pcm)
            return str(json.loads(recognizer.FinalResult()).get("text") or "").strip()

        text = await asyncio.to_thread(_transcribe)
        log.info("STT_FINAL bytes=%d text=%r", len(pcm), text[:120])
        request_id = uuid.uuid4().hex
        if not text:
            return stt.SpeechEvent(
                type=stt.SpeechEventType.FINAL_TRANSCRIPT, request_id=request_id
            )

        return stt.SpeechEvent(
            type=stt.SpeechEventType.FINAL_TRANSCRIPT,
            request_id=request_id,
            alternatives=[stt.SpeechData(language="en", text=text)],
        )


# ---------------------------------------------------------------------------
# STT: ElevenLabs Scribe (cloud) — used when ELEVENLABS_API_KEY is set
# ---------------------------------------------------------------------------


class ElevenLabsSTT(stt.STT):
    """Cloud speech-to-text via ElevenLabs Scribe.

    Offline path only (like vosk): the session StreamAdapter collects a VAD
    speech segment and calls ``recognize()`` with a buffer of PCM16 frames, which
    we send to the ElevenLabs ``/v1/speech-to-text`` endpoint and return the
    final transcript. LiveKit remains the transport; only the recognizer is
    swapped. Falls back to ``VoskSTT`` in ``_build_stt`` when no API key is set.
    """

    ELEVEN_STT_URL = "https://api.elevenlabs.io/v1/speech-to-text"

    def __init__(self, *, language: str = "en") -> None:
        super().__init__(
            capabilities=stt.STTCapabilities(
                streaming=False,
                interim_results=False,
                offline_recognize=True,
            )
        )
        self._language = language

    @property
    def model(self) -> str:
        return get_settings().ELEVENLABS_STT_MODEL

    @property
    def provider(self) -> str:
        return "elevenlabs"

    async def _recognize_impl(
        self,
        buffer: rtc.AudioFrame | list[rtc.AudioFrame] | tuple[rtc.AudioFrame, ...],
        *,
        language: Any = NOT_GIVEN,
        conn_options: Any = DEFAULT_API_CONNECT_OPTIONS,
    ) -> stt.SpeechEvent:
        import httpx

        s = get_settings()
        if not s.ELEVENLABS_API_KEY:
            return stt.SpeechEvent(
                type=stt.SpeechEventType.FINAL_TRANSCRIPT,
                request_id=uuid.uuid4().hex,
            )

        pcm = await asyncio.to_thread(VoskSTT._buffer_to_16k_mono_pcm, buffer)
        if not pcm:
            return stt.SpeechEvent(
                type=stt.SpeechEventType.FINAL_TRANSCRIPT,
                request_id=uuid.uuid4().hex,
            )

        headers = {
            "xi-api-key": s.ELEVENLABS_API_KEY,
            "Accept": "application/json",
        }
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(
                    self.ELEVEN_STT_URL,
                    headers=headers,
                    files={
                        "file": ("audio.pcm", pcm, "audio/pcm"),
                    },
                    data={
                        "model_id": s.ELEVENLABS_STT_MODEL,
                        "language_code": self._language,
                    },
                )
                resp.raise_for_status()
                data = resp.json()
        except Exception as e:  # noqa: BLE001 - surfaced to caller as empty
            log.warning("ElevenLabs STT request failed: %s", e)
            return stt.SpeechEvent(
                type=stt.SpeechEventType.FINAL_TRANSCRIPT,
                request_id=uuid.uuid4().hex,
            )

        text = (data.get("text") or "").strip() if isinstance(data, dict) else ""
        log.info("ELEVEN_STT_FINAL bytes=%d text=%r", len(pcm), text[:120])
        request_id = uuid.uuid4().hex
        if not text:
            return stt.SpeechEvent(
                type=stt.SpeechEventType.FINAL_TRANSCRIPT, request_id=request_id
            )

        return stt.SpeechEvent(
            type=stt.SpeechEventType.FINAL_TRANSCRIPT,
            request_id=request_id,
            alternatives=[stt.SpeechData(language=self._language, text=text)],
        )


# ---------------------------------------------------------------------------
# TTS: edge-tts (free Microsoft neural voices)
# ---------------------------------------------------------------------------


class EdgeTTS(tts.TTS):
    def __init__(
        self,
        *,
        voice: str = EDGE_TTS_VOICE,
        rate: str = EDGE_TTS_RATE,
        volume: str = EDGE_TTS_VOLUME,
        pitch: str = EDGE_TTS_PITCH,
    ) -> None:
        # edge-tts exposes synthesize() (a ChunkedStream that decodes mp3 into
        # PCM frames via the AudioEmitter). It is NOT a native streaming TTS, so
        # report streaming=False; the AgentSession voice pipeline then wraps it in
        # its own StreamAdapter (which sentence-tokenizes and calls synthesize()).
        # Declaring streaming=True skips that adapter and hits TTS.stream(), which
        # the edge-tts plugin does not implement -> NotImplementedError.
        super().__init__(
            capabilities=tts.TTSCapabilities(streaming=False),
            sample_rate=EDGE_TTS_SAMPLE_RATE,
            num_channels=EDGE_TTS_CHANNELS,
        )
        self._voice = voice
        self._rate = rate
        self._volume = volume
        self._pitch = pitch

    def synthesize(
        self,
        text: str,
        *,
        conn_options: Any = DEFAULT_API_CONNECT_OPTIONS,
    ) -> tts.ChunkedStream:
        return EdgeChunkedStream(self, input_text=text, conn_options=conn_options)


class EdgeChunkedStream(tts.ChunkedStream):
    def __init__(
        self,
        tts_instance: EdgeTTS,
        *,
        input_text: str,
        conn_options: Any,
    ) -> None:
        super().__init__(
            tts=tts_instance, input_text=input_text, conn_options=conn_options
        )

    async def _run(self, output_emitter: tts.AudioEmitter) -> None:
        import edge_tts

        edge: EdgeTTS = self._tts  # type: ignore[assignment]

        output_emitter.initialize(
            request_id=uuid.uuid4().hex,
            sample_rate=edge.sample_rate,
            num_channels=edge.num_channels,
            mime_type="audio/mpeg",  # edge-tts streams mp3 bytes; the emitter decodes them
        )

        communicate = edge_tts.Communicate(
            self.input_text,
            edge._voice,
            rate=edge._rate,
            volume=edge._volume,
            pitch=edge._pitch,
        )

        log.info("TTS_SYNTH text=%r", self.input_text[:500])
        async for msg in communicate.stream():
            if msg["type"] == "audio":
                output_emitter.push(msg["data"])


# ---------------------------------------------------------------------------
# LLM: reuse the app-wide AI provider chain
# ---------------------------------------------------------------------------


def _chat_ctx_to_messages(chat_ctx: llm.ChatContext) -> list[dict[str, str]]:
    messages: list[dict[str, str]] = []
    for msg in chat_ctx.messages():
        parts = [str(item) for item in msg.content if isinstance(item, str)]
        content = "\n".join(p for p in parts if p.strip())
        if content.strip():
            messages.append({"role": str(msg.role), "content": content})
    return messages


class ScholarLLM(llm.LLM):
    """LLM adapter that routes through ``call_ai_stream_with_fallback``."""

    @property
    def provider(self) -> str:
        return "app.ai_client"

    @property
    def model(self) -> str:
        return "huggingface->groq->cloudflare"

    def chat(
        self,
        *,
        chat_ctx: llm.ChatContext,
        tools: list[llm.Tool] | None = None,
        conn_options: Any = DEFAULT_API_CONNECT_OPTIONS,
        parallel_tool_calls: Any = NOT_GIVEN,
        tool_choice: Any = NOT_GIVEN,
        extra_kwargs: Any = NOT_GIVEN,
    ) -> llm.LLMStream:
        messages = _chat_ctx_to_messages(chat_ctx)
        return ScholarLLMStream(
            llm=self,
            chat_ctx=chat_ctx,
            tools=tools or [],
            conn_options=conn_options,
            messages=messages,
        )


class ScholarLLMStream(llm.LLMStream):
    def __init__(
        self,
        llm: ScholarLLM,
        *,
        chat_ctx: llm.ChatContext,
        tools: list[llm.Tool],
        conn_options: Any,
        messages: list[dict[str, str]],
    ) -> None:
        super().__init__(
            llm=llm, chat_ctx=chat_ctx, tools=tools, conn_options=conn_options
        )
        self._messages = messages

    async def _run(self) -> None:
        request_id = f"llm_{uuid.uuid4().hex}"
        async for chunk_text in call_ai_stream_with_fallback(self._messages):
            self._event_ch.send_nowait(
                llm.ChatChunk(
                    id=request_id,
                    delta=llm.ChoiceDelta(role="assistant", content=chunk_text),
                )
            )


# ---------------------------------------------------------------------------
# Turn plan: one reusable session builder
# ---------------------------------------------------------------------------


def _build_stt() -> stt.STT:
    # STT recognition uses the fully offline vosk engine. LiveKit remains the
    # mic-audio transport. (The ElevenLabsSTT class is kept for a future swap,
    # but Scribe is not the default while the API keys reject it with
    # "missing_permissions speech_to_text".)
    log.info("Building STT: vosk (offline)")
    return _DebugStreamAdapter(stt=VoskSTT(), vad=_silero_vad())


class _DebugStreamAdapter(StreamAdapter):
    """Temporary: logs audio frames and VAD events to bisect silent input."""

    def stream(
        self,
        *,
        language: Any = NOT_GIVEN,
        conn_options: Any = DEFAULT_API_CONNECT_OPTIONS,
    ) -> stt.RecognizeStream:
        return _DebugStreamAdapterWrapper(
            self,
            vad=self._vad,
            wrapped_stt=self._stt,
            language=language,
            conn_options=conn_options,
        )


class _DebugStreamAdapterWrapper(StreamAdapterWrapper):
    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self._frame_count = 0
        self._peak_rms = 0.0

    def push_frame(self, frame: rtc.AudioFrame) -> None:
        # loudness of the raw input frame (int16 pcm)
        rms, dtype, n = _frame_stats(frame)
        self._frame_count += 1
        if rms == rms:
            self._peak_rms = max(self._peak_rms, rms)
        if self._frame_count == 1 or self._frame_count % 200 == 0:
            log.info(
                "VAD_INPUT count=%d rms=%.1f peak=%.1f sr=%d ch=%d dtype=%s samples=%d",
                self._frame_count,
                rms,
                self._peak_rms,
                frame.sample_rate,
                frame.num_channels,
                dtype,
                n,
            )
        super().push_frame(frame)

    async def _run(self) -> None:
        vad_stream = self._vad.stream()

        async def _forward_input() -> None:
            async for input in self._input_ch:
                if isinstance(input, self._FlushSentinel):
                    vad_stream.flush()
                    continue
                vad_stream.push_frame(input)
            vad_stream.end_input()

        async def _recognize() -> None:
            async for event in vad_stream:
                log.info("VAD_EVENT type=%s frames=%d", event.type, len(event.frames))
                if event.type == VADEventType.START_OF_SPEECH:
                    self._event_ch.send_nowait(
                        stt.SpeechEvent(stt.SpeechEventType.START_OF_SPEECH)
                    )
                elif event.type == VADEventType.END_OF_SPEECH:
                    speech_end_time = (
                        time.time() - event.silence_duration - event.inference_duration
                    )
                    self._event_ch.send_nowait(
                        stt.SpeechEvent(
                            type=stt.SpeechEventType.END_OF_SPEECH,
                            speech_end_time=speech_end_time,
                        )
                    )
                    merged_frames = utils.merge_frames(event.frames)
                    log.info(
                        "STT_BATCH bytes=%d rms=%.1f",
                        merged_frames.data.nbytes
                        if hasattr(merged_frames, "data")
                        else -1,
                        self._peak_rms,
                    )
                    t_event = await self._wrapped_stt.recognize(
                        buffer=merged_frames,
                        language=self._language,
                        conn_options=self._wrapped_stt_conn_options,
                    )
                    if len(t_event.alternatives) == 0:
                        continue
                    elif not t_event.alternatives[0].text:
                        continue
                    self._event_ch.send_nowait(
                        stt.SpeechEvent(
                            type=stt.SpeechEventType.FINAL_TRANSCRIPT,
                            alternatives=[t_event.alternatives[0]],
                            speech_end_time=(
                                t_event.speech_end_time
                                if t_event.speech_end_time is not None
                                else speech_end_time
                            ),
                        )
                    )

        tasks = [
            asyncio.create_task(_forward_input(), name="forward_input"),
            asyncio.create_task(_recognize(), name="recognize"),
        ]
        try:
            await asyncio.gather(*tasks)
        finally:
            await utils.aio.cancel_and_wait(*tasks)
            await vad_stream.aclose()


async def _run_session(ctx: JobContext) -> None:
    await ctx.connect()

    session = AgentSession(
        stt=_build_stt(),
        llm=ScholarLLM(),
        tts=EdgeTTS(),
        vad=_silero_vad(),
    )

    agent = Agent(
        instructions=(
            "You are Nkhani, the friendly voice tutor of ScholarMW — the AI-powered "
            "academic intelligence and learning platform for Malawi.\n\n"
            "Guidelines for spoken answers:\n"
            "- Always answer in clear, simple English (or Chichewa if the learner asks).\n"
            "- Keep answers short and conversational: one or two sentences per idea.\n"
            "- Pause naturally between ideas; never dump long lists or heavy markdown.\n"
            "- When the learner is confused, re-explain with a fresh example.\n"
            "- Relate examples to Malawi where possible (exams, MoEST syllabus, daily life).\n"
            "- If audio is unclear, gently ask the learner to repeat themselves.\n"
            "- Encourage the learner: praise effort, then gently correct mistakes."
        )
    )

    log.info(
        "Voice session ready for room %s (remotes=%s)",
        ctx.room.name,
        [p.identity for p in ctx.room.remote_participants.values()],
    )
    await session.start(room=ctx.room, agent=agent)


async def _run_stt_relay(ctx: JobContext) -> None:
    """STT-only mode: transcribe a participant's mic with vosk and relay the
    transcripts back to the web client over a LiveKit data channel.

    A room whose name starts with ``STT_RELAY_ROOM_PREFIX`` triggers this
    handler instead of the conversational voice tutor.  The web client publishes
    microphone audio; the worker feeds it through VAD + vosk and publishes each
    final transcript as JSON ``{"type": "stt", "text": "..."}`` on
    ``STT_RELAY_TOPIC`` via ``room.local_participant.publish_data``.
    """
    await ctx.connect()
    room = ctx.room
    log.info("STT relay session ready for room %s", room.name)

    recognizer = _build_stt()
    rec = recognizer.stream(language="en")

    async def _relay_transcripts() -> None:
        async for event in rec:
            if (
                event.type == stt.SpeechEventType.FINAL_TRANSCRIPT
                and event.alternatives
            ):
                text = event.alternatives[0].text.strip()
                if not text:
                    continue
                log.info("STT_RELAY text=%r", text)
                await room.local_participant.publish_data(
                    json.dumps({"type": "stt", "text": text}),
                    topic=STT_RELAY_TOPIC,
                )

    async def _feed_track(track: rtc.Track) -> None:
        stream = rtc.AudioStream(track, sample_rate=VOSK_TARGET_SAMPLE_RATE)
        try:
            async for ev in stream:
                frame = ev.frame if hasattr(ev, "frame") else ev
                rec.push_frame(frame)
        finally:
            await stream.aclose()

    feeder_tasks: set[asyncio.Task] = set()

    def _subscribe(track: rtc.Track) -> None:
        if track.kind != rtc.TrackKind.KIND_AUDIO:
            return
        task = asyncio.create_task(_feed_track(track))
        feeder_tasks.add(task)
        task.add_done_callback(feeder_tasks.discard)

    @room.on("track_subscribed")
    def _on_track_subscribed(
        track: rtc.Track,
        publication: rtc.RemoteTrackPublication,
        participant: rtc.RemoteParticipant,
    ) -> None:
        _subscribe(track)

    for participant in room.remote_participants.values():
        for publication in participant.track_publications.values():
            track = publication.track
            if track is not None:
                _subscribe(track)

    relay_task = asyncio.create_task(_relay_transcripts())

    try:
        # Run until the room is closed (the job is cancelled by the server).
        while True:
            await asyncio.sleep(3600)
    except asyncio.CancelledError:
        raise
    finally:
        relay_task.cancel()
        for t in feeder_tasks:
            t.cancel()
        try:
            await rec.aclose()
        except Exception:  # noqa: BLE001 - best-effort cleanup
            pass


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------


async def _main() -> None:
    log_level = os.getenv("LIVEKIT_AGENT_LOG_LEVEL", "INFO").upper()
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    logging.getLogger("livekit").setLevel(log_level)
    settings = get_settings()
    if not settings.livekit_configured:
        log.error(
            "LiveKit is not configured (LIVEKIT_URL / LIVEKIT_API_KEY / "
            "LIVEKIT_API_SECRET). Nothing to do."
        )
        return

    # The LiveKit server selects dispatch candidates by job-request "affinity",
    # computed as max(0, targetLoad - reportedLoad). The default SDK load_fnc
    # reports host CPU percent (psutil), which on busy dev boxes frequently
    # exceeds the server's target load (default 0.7) and drops the worker's
    # affinity to exactly 0.0. psrpc then treats the worker as a non-match and
    # dispatch fails with "no servers available (received 1 responses)". Report
    # load 0 so this single worker always remains a dispatch candidate.
    def _report_load(_worker: object) -> float:
        return 0.0

    server = AgentServer(
        ws_url=settings.LIVEKIT_URL,
        api_key=settings.LIVEKIT_API_KEY,
        api_secret=settings.LIVEKIT_API_SECRET,
        host=os.getenv("LIVEKIT_AGENT_HOST", "0.0.0.0"),
        port=0,  # dev health server: pick a free port
        log_level=log_level,
        load_fnc=_report_load,
    )

    # A named agent allows explicit dispatch (POST /livekit token + dispatch),
    # but names are not reliable on every self-hosted server (see
    # livekit/livekit#3879).  Default: register anonymously (LIVEKIT_AGENT_NAME
    # unset/empty) and get auto-dispatched when a participant joins a room.
    # Set LIVEKIT_AGENT_NAME=scholar-mw for explicit/token dispatch.
    agent_name = os.getenv("LIVEKIT_AGENT_NAME", "").strip() or None

    @server.rtc_session(agent_name=agent_name)
    async def scholar_session(ctx: JobContext) -> None:
        if ctx.room.name.startswith(STT_RELAY_ROOM_PREFIX):
            await _run_stt_relay(ctx)
        else:
            await _run_session(ctx)

    devmode = "dev" in sys.argv[1:]
    log.info("Starting ScholarMW voice-agent worker (devmode=%s)", devmode)
    try:
        await server.run(devmode=devmode)
    except asyncio.CancelledError:
        log.info("Voice-agent worker cancelled")
        raise
    except Exception:  # noqa: BLE001 - worker must not die silently
        log.exception("Voice-agent worker stopped unexpectedly")
        raise


if __name__ == "__main__":
    try:
        asyncio.run(_main())
    except KeyboardInterrupt:
        log.info("Voice-agent worker interrupted")
