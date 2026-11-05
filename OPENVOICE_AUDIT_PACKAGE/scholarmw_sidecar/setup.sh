#!/usr/bin/env bash
# One-shot setup for the OpenVoice v2 sidecar (run inside WSL2 Ubuntu).
#
# It creates a Python virtualenv, installs OpenVoice v2 + MeloTTS, downloads
# the OpenVoiceV2 checkpoints, and pulls the `unidic` dictionary MeloTTS needs.
# Idempotent: safe to re-run.
#
# OpenVoice officially targets Python 3.9 and runs on 3.10-3.12. It does not
# work on 3.13+ (no compatible torch wheels, MeloTTS build fails). We
# auto-select the newest available 3.9-3.11, warn on 3.12, and refuse beyond.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

VENV_DIR="${VENV_DIR:-.venv}"
CHECKPOINTS="${OPENVOICE_CHECKPOINTS:-$HERE/checkpoints_v2}"

# Pick an interpreter: explicit PYTHON_BIN wins, else prefer 3.11, 3.10, 3.9,
# then fall back to plain `python3` (validated below).
if [ -n "${PYTHON_BIN:-}" ]; then
  :
else
  for candidate in python3.11 python3.10 python3.9 python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
fi

if [ -z "${PYTHON_BIN:-}" ] || ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "No suitable Python found. Install one first:" >&2
  echo "  sudo apt update && sudo apt install -y python3 python3-venv python3-dev" >&2
  exit 1
fi

PY_VER="$($PYTHON_BIN -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
echo "==> Using interpreter: $($PYTHON_BIN --version)"
case "$PY_VER" in
  3.9|3.10|3.11) ;;
  3.12)
    echo "WARNING: OpenVoice targets 3.9-3.11; 3.12 usually works but is untested." >&2
    ;;
  *)
    echo "ERROR: Python $PY_VER is not supported by OpenVoice (needs 3.9-3.12)." >&2
    echo "       Ubuntu 24.04 (Python 3.12) or 22.04 (3.10) are recommended." >&2
    exit 1
    ;;
esac

# venv is a separate package on Debian/Ubuntu.
if ! "$PYTHON_BIN" -m venv --help >/dev/null 2>&1; then
  echo "The venv module is missing for $PYTHON_BIN. Install it:" >&2
  echo "  sudo apt install -y python3-venv python3-dev" >&2
  exit 1
fi

echo "==> Creating virtualenv at $VENV_DIR"
"$PYTHON_BIN" -m venv "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "==> Upgrading pip tooling"
pip install --upgrade pip setuptools wheel

echo "==> Installing PyTorch (CPU build; edit for CUDA)"
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu

echo "==> Installing OpenVoice v2 and MeloTTS from source"
pip install "git+https://github.com/myshell-ai/MeloTTS.git"
pip install "git+https://github.com/myshell-ai/OpenVoice.git"

echo "==> Installing sidecar requirements"
pip install -r requirements.txt

echo "==> Downloading the unidic dictionary (MeloTTS dependency)"
python -m unidic download

if [ ! -d "$CHECKPOINTS" ]; then
  echo "==> Fetching OpenVoiceV2 checkpoints"
  mkdir -p "$CHECKPOINTS"
  # Checkpoints are hosted on Hugging Face; requires `git-lfs`.
  if command -v git-lfs >/dev/null 2>&1 || git lfs version >/dev/null 2>&1; then
    git clone https://huggingface.co/myshell-ai/OpenVoiceV2 /tmp/openvoicev2_dl
    cp -r /tmp/openvoicev2_dl/* "$CHECKPOINTS"/
    rm -rf /tmp/openvoicev2_dl
  else
    echo "git-lfs is required to fetch the checkpoints." >&2
    echo "  sudo apt install -y git-lfs && git lfs install" >&2
    echo "Then re-run this script." >&2
    exit 1
  fi
fi

echo
echo "==> Setup complete."
echo "Start the sidecar with:"
echo "    source $VENV_DIR/bin/activate"
echo "    python -m uvicorn app:app --host 127.0.0.1 --port 8011"
