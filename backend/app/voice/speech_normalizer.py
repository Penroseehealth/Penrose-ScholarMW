from __future__ import annotations

import re


class AcademicSpeechNormalizer:
    """Converts mathematical, chemical, and scientific notation into
    TTS-friendly spoken text.

    Markdown/URL/citation cleanup reuses ``app.speech.tts_text.clean_for_tts``
    so there is a single implementation of "make assistant prose speakable";
    this class adds the academic notation layer (formulae, symbols, units) on
    top. The written answer is never mutated - callers pass a copy.
    """

    # Hard cap for a single spoken utterance when the answer is long. Above
    # this, summarize_for_speech() truncates on a sentence boundary and adds a
    # spoken cue, so a 3-page answer does not become a 10-minute monologue.
    MAX_SPEECH_CHARS = 1200

    _CHEMICAL_SUBSCRIPTS = {
        "0": "\u2080",
        "1": "\u2081",
        "2": "\u2082",
        "3": "\u2083",
        "4": "\u2084",
        "5": "\u2085",
        "6": "\u2086",
        "7": "\u2087",
        "8": "\u2088",
        "9": "\u2089",
    }

    _CHEMICAL_READINGS = {
        "H2O": "H two O",
        "CO2": "C O two",
        "NaCl": "N A C L",
        "H2SO4": "H two S O four",
        "NaOH": "N A O H",
        "CaCO3": "C A C O three",
        "O2": "O two",
        "N2": "N two",
        "CH4": "C H four",
        "NH3": "N H three",
    }

    _GREEK_LETTERS = {
        "\u03b1": "alpha",
        "\u03b2": "beta",
        "\u03b3": "gamma",
        "\u03b4": "delta",
        "\u03b5": "epsilon",
        "\u03b8": "theta",
        "\u03bb": "lambda",
        "\u03bc": "mu",
        "\u03c0": "pi",
        "\u03c3": "sigma",
        "\u03c4": "tau",
        "\u03c6": "phi",
        "\u03c9": "omega",
        "\u0394": "delta",
        "\u03a3": "sigma",
        "\u03a9": "omega",
    }

    @classmethod
    def normalize(cls, text: str) -> str:
        text = cls._strip_markdown(text)
        text = cls._strip_internal_metadata(text)
        text = cls._normalize_chemical(text)
        text = cls._normalize_superscripts(text)
        text = cls._normalize_subscripts(text)
        text = cls._normalize_greek(text)
        text = cls._normalize_math_operators(text)
        text = cls._normalize_common_patterns(text)
        return text

    @classmethod
    def _strip_markdown(cls, text: str) -> str:
        """Reduce markdown/URLs/citations to speakable prose.

        Reuses ``clean_for_tts`` (the single markdown-to-speech implementation
        in the codebase) rather than duplicating its regexes here.
        """
        try:
            from app.speech.tts_text import clean_for_tts

            return clean_for_tts(text)
        except Exception:  # noqa: BLE001 - never break synthesis on cleanup
            return text

    @classmethod
    def _strip_internal_metadata(cls, text: str) -> str:
        """Remove blocks that must never be read aloud (C8).

        The SOURCES section and any leaked routing/instruction lines are
        writer-facing metadata, not answer content.
        """
        marker = "--- SOURCES ---"
        idx = text.rfind(marker)
        if idx != -1:
            text = text[:idx]
        # Drop any residual "--- ... ---" fence lines.
        text = re.sub(r"(?m)^\s*---.*?---\s*$", "", text)
        return text

    @classmethod
    def summarize_for_speech(cls, text: str, max_chars: int | None = None) -> str:
        """Return a speech-length version of a long answer (C7).

        Truncates on a sentence boundary near the cap and appends a cue so the
        listener knows the full written answer is longer. Short text is
        returned unchanged, so this is a no-op for typical replies.
        """
        cap = max_chars or cls.MAX_SPEECH_CHARS
        if len(text) <= cap:
            return text
        window = text[:cap]
        # Prefer the last sentence end within the window.
        cut = max(window.rfind(". "), window.rfind("! "), window.rfind("? "))
        if cut < cap // 2:
            cut = window.rfind(" ")
        if cut <= 0:
            cut = cap
        spoken = window[:cut].rstrip()
        return spoken + " … The full explanation is in the written answer."

    @classmethod
    def normalize_for_speech(cls, text: str, *, max_chars: int | None = None) -> str:
        """Full speech-prep pipeline: clean, normalize, and cap length.

        This is the entry point callers should use for a spoken reply. It keeps
        the written answer untouched (it operates on a copy) and yields text
        that is safe to send to Edge TTS.
        """
        cleaned = cls.normalize(text)
        cleaned = cls.summarize_for_speech(cleaned, max_chars=max_chars)
        return cleaned

    @classmethod
    def _normalize_chemical(cls, text: str) -> str:
        for formula, reading in cls._CHEMICAL_READINGS.items():
            text = text.replace(formula, reading)
        pattern = re.compile(r"([A-Z][a-z]?)([\u2080-\u2089]+)")

        def replace_chem(m: re.Match[str]) -> str:
            elem = m.group(1)
            nums = m.group(2)
            spoken_nums = "".join(str(cls._CHEMICAL_SUBSCRIPTS.get(c, c)) for c in nums)
            return f"{elem} {spoken_nums}"

        text = pattern.sub(replace_chem, text)
        return text

    @classmethod
    def _normalize_superscripts(cls, text: str) -> str:
        superscript_map = {
            "\u2070": "0",
            "\u00b9": "1",
            "\u00b2": "2",
            "\u00b3": "3",
            "\u2074": "4",
            "\u2075": "5",
            "\u2076": "6",
            "\u2077": "7",
            "\u2078": "8",
            "\u2079": "9",
            "\u207a": "+",
            "\u207b": "-",
        }

        def replace_sup(m: re.Match[str]) -> str:
            base = m.group(1)
            exp = m.group(2)
            spoken_exp = "".join(superscript_map.get(c, c) for c in exp)
            return f"{base} to the power of {spoken_exp}"

        text = re.sub(
            r"([a-zA-Z0-9]+)([\u00b2\u00b3\u2074-\u2079\u2070\u00b9\u207a\u207b]+)",
            replace_sup,
            text,
        )
        text = re.sub(
            r"\^{\d+}", lambda m: f" to the power of {m.group(0)[2:-1]}", text
        )
        text = text.replace("^2", " squared").replace("^3", " cubed")
        return text

    @classmethod
    def _normalize_subscripts(cls, text: str) -> str:
        subscript_map = {
            "\u2080": "0",
            "\u2081": "1",
            "\u2082": "2",
            "\u2083": "3",
            "\u2084": "4",
            "\u2085": "5",
            "\u2086": "6",
            "\u2087": "7",
            "\u2088": "8",
            "\u2089": "9",
        }

        def replace_sub(m: re.Match[str]) -> str:
            return "".join(subscript_map.get(c, c) for c in m.group(0))

        text = re.sub(r"[\u2080-\u2089]+", replace_sub, text)
        return text

    @classmethod
    def _normalize_greek(cls, text: str) -> str:
        for symbol, name in cls._GREEK_LETTERS.items():
            text = text.replace(symbol, name)
        return text

    @classmethod
    def _normalize_math_operators(cls, text: str) -> str:
        replacements = {
            "\u00d7": " times ",
            "\u00f7": " divided by ",
            "\u00b1": " plus or minus ",
            "\u221e": " infinity ",
            "\u2260": " not equal to ",
            "\u2264": " less than or equal to ",
            "\u2265": " greater than or equal to ",
            "\u221a": " square root of ",
            "\u222b": " integral ",
            "\u2211": " summation ",
            "\u2208": " is in ",
            "\u2282": " is a subset of ",
            "\u2192": " yields ",
            "\u21cc": " is in equilibrium with ",
        }
        for symbol, reading in replacements.items():
            text = text.replace(symbol, reading)
        return text

    @classmethod
    def _normalize_common_patterns(cls, text: str) -> str:
        text = re.sub(r"(\d+)/(\d+)", lambda m: f"{m.group(1)} over {m.group(2)}", text)
        text = re.sub(r"(\d+)%", lambda m: f"{m.group(1)} percent", text)
        text = text.replace("e.g.", "for example")
        text = text.replace("i.e.", "that is")
        text = text.replace("etc.", "et cetera")
        return text.strip()
