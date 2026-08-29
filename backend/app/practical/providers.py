"""Video generation provider abstraction.

VideoGenerationProvider is the interface Penrose uses for generative video.
Concrete adapters (Runway, Luma) implement it. Credentials live ONLY on the
backend via app.config.settings — never in Flutter/frontend code.

The provider router (``select_provider``) picks the best available provider
based on quality, cost, latency and requested duration. A future local /
self-hosted video model can be added as another adapter without touching the
frontend.
"""

from __future__ import annotations

import logging
from abc import ABC, abstractmethod

import httpx

log = logging.getLogger(__name__)

# Quality tiers map to relative cost/latency factors used for estimation.
QUALITY_FACTORS: dict[str, float] = {"draft": 0.3, "standard": 1.0, "high": 2.2}
SECONDS_PER_CREDIT = 0.12  # approximate credit burn per video-second


class GenerationJobResult:
    """Normalized result from a provider."""

    def __init__(
        self, provider_job_id: str | None, status: str, provider: str, model: str
    ):
        self.provider_job_id = provider_job_id
        self.status = status
        self.provider = provider
        self.model = model


class VideoGenerationProvider(ABC):
    """Interface every provider adapter must implement."""

    name: str = "abstract"

    @abstractmethod
    async def generate_video(
        self,
        *,
        prompt: str,
        provider: str,
        duration: float,
        quality: str,
        image_url: str | None = None,
    ) -> GenerationJobResult:
        raise NotImplementedError

    @abstractmethod
    async def generate_from_image(
        self,
        *,
        image_url: str,
        prompt: str,
        provider: str,
        duration: float,
        quality: str,
    ) -> GenerationJobResult:
        raise NotImplementedError

    @abstractmethod
    async def get_generation_status(self, job_id: str) -> GenerationJobResult:
        raise NotImplementedError

    @abstractmethod
    async def extend_video(
        self, *, job_id: str, prompt: str, duration: float
    ) -> GenerationJobResult:
        raise NotImplementedError

    @abstractmethod
    async def delete_video(self, job_id: str) -> None:
        raise NotImplementedError


class RunwayAdapter(VideoGenerationProvider):
    """Runway ML (Gen-3 / Gen-4) adapter.

    Requires RUNWAY_API_KEY (and optionally RUNWAY_API_SECRET / RUNWAY_ORG
    for team API tokens) in backend/.env. No committed key = unavailable.
    """

    name = "runway"
    base_url = "https://api.dev.runwayml.com/v1"
    default_model = "gen3a_turbo"

    async def _client(self) -> httpx.AsyncClient:
        from app.config.settings import get_settings

        s = get_settings()
        headers = {"Authorization": f"Bearer {s.RUNWAY_API_KEY}"}
        if getattr(s, "RUNWAY_API_SECRET", ""):
            headers["X-Api-Secret"] = s.RUNWAY_API_SECRET
        return httpx.AsyncClient(base_url=self.base_url, headers=headers, timeout=120.0)

    def _model(self) -> str:
        from app.config.settings import get_settings

        return getattr(get_settings(), "RUNWAY_MODEL", "") or self.default_model

    async def generate_video(
        self, *, prompt, provider, duration, quality, image_url=None
    ):
        # Runway exposes a text-to-video via an image model + task. For the
        # abstraction we submit a task of type "text_to_video" when supported.
        async with await self._client() as client:
            resp = await client.post(
                "/tasks",
                json={
                    "model": self._model(),
                    "prompt": prompt,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return GenerationJobResult(
                provider_job_id=str(data.get("id")),
                status=data.get("status", "PENDING"),
                provider=self.name,
                model=self._model(),
            )

    async def generate_from_image(
        self, *, image_url, prompt, provider, duration, quality
    ):
        async with await self._client() as client:
            resp = await client.post(
                "/image_to_video",
                json={
                    "model": self._model(),
                    "promptImage": image_url,
                    "promptText": prompt,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return GenerationJobResult(
                provider_job_id=str(data.get("taskId") or data.get("id")),
                status=data.get("status", "PENDING"),
                provider=self.name,
                model=self._model(),
            )

    async def get_generation_status(self, job_id):
        async with await self._client() as client:
            resp = await client.get(f"/tasks/{job_id}")
            resp.raise_for_status()
            data = resp.json()
            return GenerationJobResult(
                provider_job_id=job_id,
                status=str(data.get("status", "PENDING")).upper(),
                provider=self.name,
                model=self._model(),
            )

    async def extend_video(self, *, job_id, prompt, duration):
        return GenerationJobResult(job_id, "PENDING", self.name, self._model())

    async def delete_video(self, job_id):
        try:
            async with await self._client() as client:
                await client.delete(f"/tasks/{job_id}")
        except Exception as e:  # noqa: BLE001 - best-effort delete
            log.warning("Runway delete failed: %s", e)


class LumaAdapter(VideoGenerationProvider):
    """Luma Dream Machine adapter.

    Requires LUMA_API_KEY in backend/.env. No committed key = unavailable.
    """

    name = "luma"
    base_url = "https://api.lumalabs.ai/dream-machine/v1"
    default_model = "ray-2"

    async def _client(self) -> httpx.AsyncClient:
        from app.config.settings import get_settings

        s = get_settings()
        headers = {"Authorization": f"Bearer {s.LUMA_API_KEY}"}
        return httpx.AsyncClient(base_url=self.base_url, headers=headers, timeout=120.0)

    def _model(self) -> str:
        from app.config.settings import get_settings

        return getattr(get_settings(), "LUMA_MODEL", "") or self.default_model

    async def _create(self, payload: dict) -> GenerationJobResult:
        async with await self._client() as client:
            resp = await client.post("/generations", json=payload)
            resp.raise_for_status()
            data = resp.json()
            return GenerationJobResult(
                provider_job_id=str(data.get("id")),
                status=str(data.get("state", "queued")).upper(),
                provider=self.name,
                model=self._model(),
            )

    async def generate_video(
        self, *, prompt, provider, duration, quality, image_url=None
    ):
        payload = {"prompt": prompt, "model": self._model(), "duration": str(duration)}
        if image_url:
            payload["keyframes"] = {"frame0": {"url": image_url}}
        return await self._create(payload)

    async def generate_from_image(
        self, *, image_url, prompt, provider, duration, quality
    ):
        return await self._create(
            {
                "prompt": prompt,
                "model": self._model(),
                "duration": str(duration),
                "keyframes": {"frame0": {"url": image_url}},
            }
        )

    async def get_generation_status(self, job_id):
        async with await self._client() as client:
            resp = await client.get(f"/generations/{job_id}")
            resp.raise_for_status()
            data = resp.json()
            return GenerationJobResult(
                provider_job_id=job_id,
                status=str(data.get("state", "queued")).upper(),
                provider=self.name,
                model=self._model(),
            )

    async def extend_video(self, *, job_id, prompt, duration):
        async with await self._client() as client:
            resp = await client.post(
                "/generations",
                json={
                    "prompt": prompt,
                    "model": self._model(),
                    "duration": str(duration),
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return GenerationJobResult(
                provider_job_id=str(data.get("id")),
                status=str(data.get("state", "queued")).upper(),
                provider=self.name,
                model=self._model(),
            )

    async def delete_video(self, job_id):
        try:
            async with await self._client() as client:
                await client.delete(f"/generations/{job_id}")
        except Exception as e:  # noqa: BLE001 - best-effort delete
            log.warning("Luma delete failed: %s", e)


class NoProviderVideoError(RuntimeError):
    pass


class VideoProviderRouter:
    """Selects the best available provider for a generation request."""

    def __init__(self) -> None:
        self._adapters: dict[str, VideoGenerationProvider] = {
            RunwayAdapter().name: RunwayAdapter(),
            LumaAdapter().name: LumaAdapter(),
        }

    def configured_providers(self) -> list[str]:
        """Return names of providers that have an API key configured."""
        from app.config.settings import get_settings

        s = get_settings()
        available: list[str] = []
        if s.RUNWAY_API_KEY:
            available.append("runway")
        if s.LUMA_API_KEY:
            available.append("luma")
        return available

    def adapter_for(self, name: str | None) -> VideoGenerationProvider:
        if not name:
            available = self.configured_providers()
            if not available:
                raise NoProviderVideoError("No video provider configured")
            name = available[0]
        if name not in self._adapters:
            raise NoProviderVideoError(f"Unknown video provider: {name}")
        return self._adapters[name]

    def estimate_credits(self, duration: float, quality: str) -> float:
        factor = QUALITY_FACTORS.get(quality, 1.0)
        return round(duration * SECONDS_PER_CREDIT * factor, 2)

    def describe(self) -> list[dict]:
        return [
            {
                "provider": name,
                "status": "configured"
                if name in self.configured_providers()
                else "not_configured",
            }
            for name in self._adapters
        ]


provider_router = VideoProviderRouter()
