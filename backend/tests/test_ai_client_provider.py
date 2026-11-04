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


def _load_ai_client():
    openai = types.ModuleType("openai")
    openai.APIStatusError = type("APIStatusError", (Exception,), {})
    openai.AsyncOpenAI = _FakeAsyncOpenAI
    sys.modules["openai"] = openai

    settings_module = types.ModuleType("app.config.settings")
    settings_module.get_settings = lambda: None
    sys.modules["app.config.settings"] = settings_module

    module_name = "app.config.ai_client"
    module_path = Path(__file__).parents[1] / "app" / "config" / "ai_client.py"
    spec = importlib.util.spec_from_file_location(module_name, module_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def _settings(**overrides):
    values = {
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

    def test_huggingface_is_first_when_multiple_providers_are_configured(self):
        settings = types.SimpleNamespace(
            HUGGINGFACE_API_TOKEN="hf-test",
            HUGGINGFACE_MODEL="hf-model",
            CLOUDFLARE_ACCOUNT_ID="account",
            CLOUDFLARE_API_TOKEN="cf-test",
            CLOUDFLARE_AI_MODEL="cf-model",
            OPENAI_API_KEY="sk-test",
            OPENAI_MODEL="gpt-test",
            GROQ_API_KEY="groq-test",
            GROQ_MODEL="groq-model",
        )
        self.ai_client.get_settings = lambda: settings

        providers = self.ai_client._build_providers()

        self.assertEqual(
            [name for name, _, _ in providers],
            ["huggingface", "cloudflare", "openai", "groq"],
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
