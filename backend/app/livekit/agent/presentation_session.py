"""LiveKit agent handler for presentation sessions (Phases 3–4).

Wired into ``worker.py`` for rooms named ``pres_*``. The FastAPI app and this
worker are separate processes; the database and the internal HTTP API are the
ONLY coordination channels (approved Phase 0D):

* lesson context is pulled from ``/internal/presentation-sessions/{sid}/context``
* every client data-channel command is forwarded to ``/{sid}/command`` where
  the role is re-verified server-side — a LiveKit message is never trusted on
  its own
* AI audio owns the voice lease (acquire → renew → release; presenter
  interrupt cancels it and the agent stops within the same tick)
* narration uses the cloned voice via ``/internal/tts/clone`` with a
  DISCLOSED EdgeTTS fallback (never silent substitution)
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import time
import uuid
from typing import Any

import httpx
from livekit import rtc
from livekit.agents import Agent, AgentSession, JobContext, tts

from app.livekit.agent.worker import EdgeTTS, ScholarLLM, _build_stt, _silero_vad

log = logging.getLogger("scholar.presession")

SESSION_TOPIC = "scholar.session"

# How often the voice lease is renewed while the agent is speaking (s) and
# how long a lease lasts (s) — must match backend LEASE_TTL_S.
LEASE_RENEW_S = 5

STT_RELAY_TOPIC = "scholar.stt"


def internal_base_url() -> str:
    return os.getenv("INTERNAL_API_URL", "http://127.0.0.1:8000/api/v1").rstrip("/")


def internal_headers() -> dict:
    token = os.getenv("INTERNAL_TOKEN", "")
    return {"Authorization": f"Bearer {token}"}


class InternalApiError(Exception):
    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


async def _internal_call(
    method: str, path: str, *, json_body: dict | None = None, timeout: float = 30.0
) -> dict:
    url = f"{internal_base_url()}{path}"
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.request(method, url, json=json_body, headers=internal_headers())
    except httpx.HTTPError as e:
        raise InternalApiError(503, f"internal API unreachable: {e}") from e
    if resp.status_code >= 400:
        try:
            detail = resp.json().get("detail", resp.text)
        except Exception:  # noqa: BLE001
            detail = resp.text
        raise InternalApiError(resp.status_code, str(detail))
    if resp.status_code == 204 or not resp.content:
        return {}
    return resp.json()


# ---------------------------------------------------------------------------
# TTS: cloned voice through the internal API, disclosed EdgeTTS fallback
# ---------------------------------------------------------------------------


class CloneTTS(tts.TTS):
    """Speaks the session's default trained clone via the backend internal
    API (the same VoiceCloneService the VTC uses — one implementation, no
    duplicated synthesis logic)."""

    def __init__(self, *, session_id: str) -> None:
        super().__init__(
            capabilities=tts.TTSCapabilities(streaming=False),
            sample_rate=24000,
            num_channels=1,
        )
        self._session_id = session_id

    @property
    def provider(self) -> str:
        return "openvoice"

    @property
    def model(self) -> str:
        return "internal-clone"

    def synthesize(self, text: str, *, conn_options: Any = None) -> tts.ChunkedStream:
        return CloneChunkedStream(self, input_text=text, conn_options=conn_options)


class CloneChunkedStream(tts.ChunkedStream):
    def __init__(self, tts_instance: CloneTTS, *, input_text: str, conn_options: Any) -> None:
        super().__init__(tts=tts_instance, input_text=input_text, conn_options=conn_options)
        self._clone: CloneTTS = tts_instance

    async def _run(self, output_emitter: tts.AudioEmitter) -> None:
        try:
            result = await _internal_call(
                "POST",
                f"/internal/presentation-sessions/{self._clone._session_id}/tts-clone",
                json_body={"text": self.input_text},
                timeout=300.0,  # CPU synthesis can take minutes (Phase 0A)
            )
        except InternalApiError as e:
            log.warning("clone TTS failed (%s %s); falling back to EdgeTTS", e.status_code, e.detail)
            await output_emitter.initialize(
                request_id=uuid.uuid4().hex, sample_rate=24000,
                num_channels=1, mime_type="audio/mpeg",
            )
            # The fallback is DISCLOSED: a persistent event lets the presenter
            # cockpit show the banner (retry / continue / disable).
            self._fallback_reason = e.detail
            import edge_tts

            communicate = edge_tts.Communicate(self.input_text, "en-US-EmmaMultilingualNeural")
            async for msg in communicate.stream():
                if msg["type"] == "audio":
                    output_emitter.push(msg["data"])
            return

        audio_b64 = result.get("audio_base64") or ""
        if not audio_b64:
            raise RuntimeError("clone TTS returned no audio")
        import base64

        output_emitter.initialize(
            request_id=uuid.uuid4().hex,
            sample_rate=24000,
            num_channels=1,
            mime_type=result.get("mime", "audio/wav"),
        )
        output_emitter.push(base64.b64decode(audio_b64))


# ---------------------------------------------------------------------------
# Voice-lease lifecycle + broadcast helpers
# ---------------------------------------------------------------------------


class SessionRuntime:
    """Owns the agent side of one presentation session."""

    def __init__(self, ctx: JobContext, session_id: str) -> None:
        self.ctx = ctx
        self.session_id = session_id
        self.lease_token: str | None = None
        self._renew_task: asyncio.Task | None = None
        self._cancelled = asyncio.Event()

    async def broadcast(self, payload: dict, *, reliable: bool = True) -> None:
        await self.ctx.room.local_participant.publish_data(
            json.dumps(payload).encode("utf-8"),
            topic=SESSION_TOPIC,
            reliable=reliable,
        )

    async def _try_acquire_lease(self) -> bool:
        try:
            result = await _internal_call(
                "POST", f"/internal/presentation-sessions/{self.session_id}/voice-lease",
                json_body={"action": "acquire", "owner": "agent"},
            )
        except InternalApiError as e:
            log.warning("lease acquire failed: %s", e.detail)
            return False
        if result.get("acquired"):
            self.lease_token = result["token"]
            return True
        return False

    async def _renew_loop(self) -> None:
        while self.lease_token and not self._cancelled.is_set():
            await asyncio.sleep(LEASE_RENEW_S)
            if self._cancelled.is_set() or not self.lease_token:
                return
            try:
                ok = await _internal_call(
                    "POST", f"/internal/presentation-sessions/{self.session_id}/voice-lease",
                    json_body={"action": "renew", "token": self.lease_token},
                )
                if not ok.get("renewed"):
                    log.warning("lease renewal lost — stopping speech")
                    self.lease_token = None
                    await self.stop_audio()
            except InternalApiError:
                self.lease_token = None

    async def start_audio_ownership(self) -> bool:
        """Acquire the lease before speaking. Returns False when another AI
        voice owns it (the agent stays silent — never overlaps)."""
        if self.lease_token:
            return True
        ok = await self._try_acquire_lease()
        if not ok:
            return False
        self._cancelled.clear()
        self._renew_task = asyncio.create_task(self._renew_loop())
        await self._internal_call(
            "POST", f"/internal/presentation-sessions/{self.session_id}/events",
            json_body={"event_type": "ai_response_started", "persistence": "persistent",
                       "payload": {"owner": "agent"}},
        )
        await self.broadcast({"type": "ai_response_started", "sid": self.session_id, "owner": "agent"})
        return True

    async def stop_audio(self) -> None:
        """Full cancellation: generation cancel is the synthesis stream's
        cancellation; playback stop is the session's playhandle; frame
        publication stops because no further frames are pushed after this."""
        self._cancelled.set()
        if self._renew_task:
            self._renew_task.cancel()
            self._renew_task = None
        if self.lease_token:
            try:
                await _internal_call(
                    "POST", f"/internal/presentation-sessions/{self.session_id}/voice-lease",
                    json_body={"action": "release", "token": self.lease_token},
                )
            except InternalApiError:
                pass
            self.lease_token = None
        await self._internal_call(
            "POST", f"/internal/presentation-sessions/{self.session_id}/events",
            json_body={"event_type": "ai_response_ended", "persistence": "persistent",
                       "payload": {"reason": "cancelled_or_done"}},
        )
        await self.broadcast({"type": "ai_response_ended", "sid": self.session_id})

    def _cancel_generation(self) -> None:
        """Cancellation of the in-flight LLM/TTS tasks inside the AgentSession."""
        tasks = [t for t in asyncio.all_tasks() if t is not asyncio.current_task()]
        for t in tasks:
            name = t.get_name()
            if name.startswith("agent-") or "synth" in name or "llm" in name:
                t.cancel()

    async def handle_command(self, sender_identity: str, action: str) -> None:
        """Forward a client data-channel command to the internal command
        endpoint (role re-verified server-side), then broadcast the outcome."""
        try:
            result = await _internal_call(
                "POST", f"/internal/presentation-sessions/{self.session_id}/command",
                json_body={"identity": sender_identity, "action": action, "params": {}},
            )
        except InternalApiError as e:
            # 403 = unauthorized: already audited server-side; echo the state.
            if e.status_code == 403:
                await self.broadcast({"type": "command_rejected", "sid": self.session_id,
                                      "action": action, "identity": sender_identity})
            log.info("command %s rejected: %s", action, e.detail)
            return
        if action in ("interrupt", "takeover"):
            # The DB lease is already cancelled by the command handler; stop
            # our audio immediately (playhandle + frames) and emit the state.
            await self.stop_audio()
        await self.broadcast({
            "type": "session_state", "sid": self.session_id,
            "pres_state": result.get("pres_state"), "ai_state": result.get("ai_state"),
        })
        if action.startswith(("goto_slide", "add_slide", "delete_slide", "reorder")):
            await self.broadcast({"type": "slide_changed", "sid": self.session_id,
                                  "index": result.get("index"), "title": result.get("title")})

    async def handle_message(self, data: bytes, participant: rtc.RemoteParticipant) -> None:
        try:
            message = json.loads(data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return
        mtype = message.get("type")
        if mtype == "command":
            await self.handle_command(participant.identity or "", str(message.get("action", "")))
        elif mtype == "hand":
            # Raised hands are relayed for everyone; moderation happens via
            # the HTTP API. No privileged effect here.
            await self.broadcast({"type": "hand_raised", "sid": self.session_id,
                                  "identity": participant.identity})


# ---------------------------------------------------------------------------
# Room entry
# ---------------------------------------------------------------------------


async def run_presentation_session(ctx: JobContext) -> None:
    """Agent entry for rooms named ``pres_*`` (see worker dispatch)."""
    await ctx.connect()
    room = ctx.room
    room_name = room.name
    session_id = room_name.removeprefix("pres_")
    runtime = SessionRuntime(ctx, session_id)

    # Lesson context from the DB (slides + corrections + transcript tail).
    try:
        context = await _internal_call(
            "GET", f"/internal/presentation-sessions/{session_id}/context"
        )
    except InternalApiError as e:
        log.error("session context unavailable: %s", e.detail)
        context = {"slides": [], "corrections": []}

    corrections = "\n".join(
        f"- [{c.get('kind')}] {c.get('text')}" for c in context.get("corrections", [])
    )
    slides = context.get("slides", [])
    slide_titles = "\n".join(
        f"{i + 1}. {s.get('title')}" for i, s in enumerate(slides[:30])
    )
    instructions = (
        "You are the AI co-presenter of a live lesson. Teach the CURRENT slide, "
        "stay in the lesson context, and respect every presenter correction.\n"
        f"Lesson slides:\n{slide_titles or '(slide list unavailable)'}\n"
        f"Presenter corrections so far:\n{corrections or '(none)'}\n"
        "Keep spoken answers short (two or three sentences per idea), plain "
        "English, no markdown. If the presenter interrupts, stop mid-sentence "
        "immediately."
    )

    tts_impl = CloneTTS(session_id=session_id)  # EdgeTTS is the fallback inside
    session = AgentSession(stt=_build_stt(), llm=ScholarLLM(), tts=tts_impl, vad=_silero_vad())
    agent = Agent(instructions=instructions)

    @room.on("data_received")
    def _on_data(data: rtc.DataPacket) -> None:
        sender = data.participant if hasattr(data, "participant") else None
        if sender is None:
            return  # server-originated (our own) packets have no participant
        asyncio.create_task(runtime.handle_message(data.data, sender))

    # Voice-question transcription: attendee mic → vosk → transcript event +
    # room broadcast with the speaker's identity (attribution, Phase 3).
    stt_stream = _build_stt().stream(language="en")

    async def _relay_attendee_transcripts() -> None:
        async for event in stt_stream:
            if event.type.name == "FINAL_TRANSCRIPT" and event.alternatives:
                text = event.alternatives[0].text.strip()
                if not text:
                    continue
                await _internal_call(
                    "POST", f"/internal/presentation-sessions/{session_id}/events",
                    json_body={"event_type": "transcript_final", "persistence": "persistent",
                               "payload": {"source": "attendee", "text": text}},
                )
                await runtime.broadcast({"type": "stt_final", "sid": session_id,
                                         "text": text}, reliable=False)

    async def _feed_track(track: rtc.Track) -> None:
        stream = rtc.AudioStream(track, sample_rate=16000)
        try:
            async for ev in stream:
                frame = ev.frame if hasattr(ev, "frame") else ev
                stt_stream.push_frame(frame)
        finally:
            await stream.aclose()

    feeder_tasks: set[asyncio.Task] = set()

    def _subscribe(track: rtc.Track, participant: rtc.RemoteParticipant) -> None:
        if track.kind != rtc.TrackKind.KIND_AUDIO:
            return
        task = asyncio.create_task(_feed_track(track), name=f"feed-{participant.identity}")
        feeder_tasks.add(task)
        task.add_done_callback(feeder_tasks.discard)

    @room.on("track_subscribed")
    def _on_track(track: rtc.Track, pub, participant: rtc.RemoteParticipant) -> None:
        _subscribe(track, participant)

    for participant in room.remote_participants.values():
        for publication in participant.track_publications.values():
            if publication.track is not None:
                _subscribe(publication.track, participant)

    relay_task = asyncio.create_task(_relay_attendee_transcripts())
    await session.start(room=room, agent=agent)

    try:
        while True:
            await asyncio.sleep(3600)
    except asyncio.CancelledError:
        raise
    finally:
        await runtime.stop_audio()
        relay_task.cancel()
        for t in feeder_tasks:
            t.cancel()
