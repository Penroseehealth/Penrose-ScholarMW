#!/usr/bin/env python3
"""Rebuild the mathsdrill React app and refresh the copies Penrose serves.

mathsdrill lives in a separate source project (Vite + React). Penrose only ever
serves a *copy* of its `dist/` output:

  frontend/web/mathsdrill       committed copy, Flutter copies it on build
  frontend/build/web/mathsdrill the copy the dev proxy and FastAPI actually serve

Forgetting either copy is what makes the embedded app look stale, so do it here
instead of by hand:

  python tools/sync_mathsdrill.py               # build, then sync both copies
  python tools/sync_mathsdrill.py --no-build    # sync the existing dist/ only
  python tools/sync_mathsdrill.py --source PATH # non-default mathsdrill checkout

The written `index.html` uses relative asset URLs (so it works under
`/mathsdrill/`) and appends a `?v=<content hash>` stamp, so a refresh can be
confirmed from the browser's network panel alone.
"""

import argparse
import hashlib
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SOURCE = REPO_ROOT.parent / "mathsdrill"
WEB_COPY = REPO_ROOT / "frontend" / "web" / "mathsdrill"
SERVED_COPY = REPO_ROOT / "frontend" / "build" / "web" / "mathsdrill"

LOCAL_ATTR = re.compile(r'((?:src|href)=")/(?!/)')
ASSET_ATTR = re.compile(r'((?:src|href)=")(assets/[^"?#]+)(\?[^"]*)?(")')


def build(source: Path) -> None:
    print(f"building mathsdrill in {source} ...")
    result = subprocess.run(
        "npm run build",
        cwd=source,
        shell=True,
        capture_output=True,
        text=True,
    )
    tail = (result.stdout or "") + (result.stderr or "")
    print("\n".join(tail.strip().splitlines()[-6:]))
    if not (source / "dist" / "index.html").is_file():
        sys.exit("build did not produce dist/index.html")


def stamp_for(dist: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted((dist / "assets").iterdir()):
        if path.suffix in {".js", ".css"}:
            digest.update(path.name.encode())
            digest.update(path.read_bytes())
    return digest.hexdigest()[:12]


def rewrite_index(dist: Path) -> str:
    """Point the built index at relative URLs and version every asset."""
    html = (dist / "index.html").read_text(encoding="utf-8")
    version = stamp_for(dist)
    html = LOCAL_ATTR.sub(r"\1", html)

    def versioned(match: re.Match[str]) -> str:
        prefix, url, query, quote = match.groups()
        joiner = "&" if query else "?"
        return f"{prefix}{url}{query or ''}{joiner}v={version}{quote}"

    html = ASSET_ATTR.sub(versioned, html)
    return html.replace("<body>", f'<body data-mathsdrill-build="{version}">', 1)


def write_copy(dist: Path, destination: Path, html: str) -> None:
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(dist, destination)
    (destination / "index.html").write_text(html, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--no-build", action="store_true")
    args = parser.parse_args()

    source = args.source.resolve()
    dist = source / "dist"
    if not (source / "package.json").is_file():
        sys.exit(f"no package.json in {source}")
    if not args.no_build:
        build(source)
    if not (dist / "index.html").is_file():
        sys.exit(f"no build output in {dist}")

    html = rewrite_index(dist)
    version = stamp_for(dist)

    targets = [WEB_COPY]
    # Only mirror into an existing build tree; a missing one means no web build
    # has run yet and the next `flutter build web` will copy web/ itself.
    if (REPO_ROOT / "frontend" / "build" / "web").is_dir():
        targets.append(SERVED_COPY)
    for target in targets:
        write_copy(dist, target, html)

    assets = sorted(
        p.name for p in (dist / "assets").iterdir() if p.suffix in {".js", ".css"}
    )
    print(f"\nbuild stamp: {version}")
    for name in assets:
        path = dist / "assets" / name
        print(f"  {name}  {path.stat().st_size:,} bytes")
    for target in targets:
        print(f"wrote {target}")
    print(f"\nserve check: /mathsdrill/index.html?v={version}")


if __name__ == "__main__":
    main()
