import importlib.util
import sys
import types
import unittest
from pathlib import Path


class _FakeAsyncOpenAI:
    def __init__(self, **kwargs):
        self.kwargs = kwargs


class AiClientProviderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
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
        cls.ai_client = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = cls.ai_client
        spec.loader.exec_module(cls.ai_client)

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


if __name__ == "__main__":
    unittest.main()
