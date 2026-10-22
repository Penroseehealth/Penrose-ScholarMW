"""Text preparation for spoken output.

Assistant replies carry markdown, citation markers, and URLs that sound
wrong when read aloud. ``clean_for_tts`` turns them into plain prose while
preserving the complete written response (the caller keeps the original
text separately). Deterministic, dependency-free, regex-based.
"""

from __future__ import annotations

import re

_MD_LINK = re.compile(r"\[([^\]]*)\]\((?:[^()\s]+|\([^)]*\))*\)")
_MD_IMAGE = re.compile(r"!\[([^\]]*)\]\([^)]*\)")
_URL = re.compile(r"https?://[^\s<>)\"']+", re.IGNORECASE)
_EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
_CITE = re.compile(r"\[\d+(?:\s*[,;&\u2013\u2014-]?\s*\d+)*\]")
_CITE_PAREN = re.compile(r"\([^()]*?(?:19|20)\d{2}[^()]*?\)")
_MD_FENCES = re.compile(r"(`{3,}|~{3,})[^\n]*\n")
_INLINE_CODE = re.compile(r"`([^`]*)`")
_MD_EMPH = re.compile(r"(\*\*|__|\*|_)(?=\S)(.*?)(?<=\S)\1")
_HEADING = re.compile(r"^\s{0,3}#{1,6}\s+", re.MULTILINE)
_BULLET = re.compile(r"^\s*[-*+]\s+", re.MULTILINE)
_NUM_BULLET = re.compile(r"^\s*\d+[.)]\s+", re.MULTILINE)
_BLOCKQUOTE = re.compile(r"^\s{0,3}>\s?", re.MULTILINE)
_WS = re.compile(r"[ \t]+")
_NL = re.compile(r"\n{3,}")


def clean_for_tts(text: str) -> str:
    """Return a spoken-friendly version of ``text``.

    - Markdown links/images/fences/inline code/emphasis/headings are reduced
      to their visible prose.
    - Inline numeric citations (``[12]``) and parenthetical author-year
      citations (``(Smith, 2020)``) are dropped, as are URLs and emails.
    - Bullet prefixes are removed while the item prose is kept.
    - Excess whitespace collapses; the result is stripped.
    """
    if not text:
        return ""
    out = text
    out = _MD_IMAGE.sub(lambda m: m.group(1) or "", out)
    out = _MD_LINK.sub(lambda m: m.group(1).strip() or "", out)
    out = _MD_FENCES.sub("", out)
    out = _INLINE_CODE.sub(lambda m: m.group(1), out)
    out = _MD_EMPH.sub(lambda m: m.group(2), out)
    out = _URL.sub("", out)
    out = _EMAIL.sub("", out)
    out = _CITE.sub(" ", out)
    out = _CITE_PAREN.sub(" ", out)
    out = _HEADING.sub("", out)
    out = _BULLET.sub("", out)
    out = _NUM_BULLET.sub("", out)
    out = _BLOCKQUOTE.sub("", out)
    out = _WS.sub(" ", out)
    out = _NL.sub("\n\n", out)
    return out.strip()
