import importlib.util
import sys
import types
import unittest
from pathlib import Path


class _FakeAsyncOpenAI:
    def __init__(self, **kwargs):
        self.kwargs = kwargs


class _FakeCompletions:
    def __init__(self, behaviour):
        self.behaviour = behaviour

    async def create(self, **kwargs):
        if isinstance(self.behaviour, Exception):
            raise self.behaviour
        return self.behaviour


class _FakeChat:
    def __init__(self, behaviour):
        self.completions = _FakeCompletions(behaviour)


class _FakeClient:
    def __init__(self, behaviour):
        self.chat = _FakeChat(behaviour)


def _completion(content: str):
    return types.SimpleNamespace(
        choices=[types.SimpleNamespace(message=types.SimpleNamespace(content=content))]
    )


_MISSING = object()

_PROVIDER_MODULE = "app.config.ai_client"


def _load_ai_client():
    """Load ai_client.py against fakes without leaking them to other tests.

    ai_client imports both modules at import time, so the fakes only need to be
    installed for the duration of ``exec_module``. Leaving them in sys.modules
    makes later tests import the fakes instead of the real modules.
    """
    saved = {
        name: sys.modules.get(name, _MISSING)
        for name in ("openai", "app.config.settings", _PROVIDER_MODULE)
    }

    openai = types.ModuleType("openai")
    openai.APIStatusError = type("APIStatusError", (Exception,), {})
    openai.AsyncOpenAI = _FakeAsyncOpenAI
    sys.modules["openai"] = openai

    settings_module = types.ModuleType("app.config.settings")
    settings_module.get_settings = lambda: None
    sys.modules["app.config.settings"] = settings_module

    module_path = Path(__file__).parents[1] / "app" / "config" / "ai_client.py"
    spec = importlib.util.spec_from_file_location(_PROVIDER_MODULE, module_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[_PROVIDER_MODULE] = module
    try:
        spec.loader.exec_module(module)
    finally:
        for name, original in saved.items():
            if original is _MISSING:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = original
    return module


def _settings(**overrides):
    values = {
        "AI_PROVIDER_PRIORITY": ["cloudflare", "huggingface", "openai", "groq"],
        "HUGGINGFACE_API_TOKEN": "",
        "HUGGINGFACE_MODEL": "hf-model",
        "CLOUDFLARE_ACCOUNT_ID": "",
        "CLOUDFLARE_API_TOKEN": "",
        "CLOUDFLARE_AI_MODEL": "cf-model",
        "OPENAI_API_KEY": "",
        "OPENAI_MODEL": "gpt-model",
        "GROQ_API_KEY": "",
        "GROQ_MODEL": "groq-model",
    }
    values.update(overrides)
    return types.SimpleNamespace(**values)


class AiClientProviderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ai_client = _load_ai_client()

    def test_cloudflare_is_first_by_default(self):
        settings = _settings(
            HUGGINGFACE_API_TOKEN="hf-test",
            CLOUDFLARE_ACCOUNT_ID="account",
            CLOUDFLARE_API_TOKEN="cf-test",
            OPENAI_API_KEY="sk-test",
            GROQ_API_KEY="groq-test",
        )
        self.ai_client.get_settings = lambda: settings

        providers = self.ai_client._build_providers()

        self.assertEqual(
            [name for name, _, _ in providers],
            ["cloudflare", "huggingface", "openai", "groq"],
        )

    def test_priority_setting_can_restore_huggingface_first(self):
        settings = _settings(
            HUGGINGFACE_API_TOKEN="hf-test",
            CLOUDFLARE_ACCOUNT_ID="account",
            CLOUDFLARE_API_TOKEN="cf-test",
            GROQ_API_KEY="groq-test",
            AI_PROVIDER_PRIORITY=["huggingface", "cloudflare", "groq"],
        )
        self.ai_client.get_settings = lambda: settings

        providers = self.ai_client._build_providers()

        self.assertEqual(
            [name for name, _, _ in providers],
            ["huggingface", "cloudflare", "groq"],
        )

    def test_unlisted_providers_run_after_the_configured_priority(self):
        settings = _settings(
            HUGGINGFACE_API_TOKEN="hf-test",
            CLOUDFLARE_ACCOUNT_ID="account",
            CLOUDFLARE_API_TOKEN="cf-test",
            OPENAI_API_KEY="sk-test",
            GROQ_API_KEY="groq-test",
            AI_PROVIDER_PRIORITY=["cloudflare"],
        )
        self.ai_client.get_settings = lambda: settings

        providers = self.ai_client._build_providers()

        self.assertEqual(
            [name for name, _, _ in providers],
            ["cloudflare", "huggingface", "openai", "groq"],
        )

    def test_huggingface_stays_first_with_only_openai_as_fallback(self):
        settings = _settings(
            HUGGINGFACE_API_TOKEN="hf-test",
            OPENAI_API_KEY="sk-test",
        )
        self.ai_client.get_settings = lambda: settings

        providers = self.ai_client._build_providers()

        self.assertEqual(
            [name for name, _, _ in providers],
            ["huggingface", "openai"],
        )


class AiClientFallbackTests(unittest.IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls):
        cls.ai_client = _load_ai_client()

    async def test_primary_failure_falls_through_to_the_next_provider(self):
        primary = (
            "huggingface",
            _FakeClient(RuntimeError("no inference credits")),
            "hf-model",
        )
        fallback = ("cloudflare", _FakeClient(_completion("OK")), "cf-model")
        original = self.ai_client._build_providers
        self.ai_client._build_providers = lambda: [primary, fallback]
        try:
            completion, provider = await self.ai_client.call_ai_chat(
                [{"role": "user", "content": "hi"}],
                timeout=5,
            )
        finally:
            self.ai_client._build_providers = original

        self.assertEqual(provider, "cloudflare")
        self.assertEqual(completion.choices[0].message.content, "OK")


if __name__ == "__main__":
    unittest.main()
