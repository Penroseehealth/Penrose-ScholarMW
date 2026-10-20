#!/usr/bin/env bash
# One-shot setup for the OpenVoice v2 sidecar (run inside WSL2 Ubuntu).
#
# It creates a Python 3.9 virtualenv, installs OpenVoice v2 + MeloTTS, downloads
# the OpenVoiceV2 checkpoints, and pulls the `unidic` dictionary MeloTTS needs.
# Idempotent: safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

PYTHON_BIN="${PYTHON_BIN:-python3.9}"
VENV_DIR="${VENV_DIR:-.venv}"
CHECKPOINTS="${OPENVOICE_CHECKPOINTS:-$HERE/checkpoints_v2}"

echo "==> Using interpreter: $($PYTHON_BIN --version)"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python 3.9 not found. Install it first:" >&2
  echo "  sudo apt update && sudo apt install -y python3.9 python3.9-venv python3.9-dev" >&2
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
