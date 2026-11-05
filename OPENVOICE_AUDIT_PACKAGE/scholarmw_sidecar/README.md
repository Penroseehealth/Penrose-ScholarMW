# OpenVoice sidecar (free voice cloning for Penrose)

This sidecar gives Penrose **free, local** voice cloning via
[OpenVoice v2](https://github.com/myshell-ai/OpenVoice) (MIT licensed). It is the
free alternative to the paid ElevenLabs path. The Penrose backend already speaks
to it through `backend/app/speech/cloning.py` (`OpenVoiceProvider`), pointed at
`OPENVOICE_SIDECAR_URL` (default `http://127.0.0.1:8011`).

## Why a separate process

OpenVoice needs **Linux + Python 3.9 + PyTorch + MeloTTS** and keeps ~700 MB of
weights resident in memory. Running it beside the API would drag torch into the
backend environment. Instead it runs as its own service and the backend talks to
it over HTTP.

## Endpoints (contract with the backend)

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/health` | — | `{"service":"openvoice-sidecar","engine_loaded":bool,"base_speakers_available":[...]}` |
| POST | `/clone` | multipart `sample` (wav/flac), `name`, `description` | `{"voice_id","model_version","labels"}` |
| POST | `/synthesize` | JSON `text`, optional `voice_id`, `base_speaker`, `speed` | `audio/wav` + `x-openvoice-source-embedding` header |
| GET | `/voice/{id}` | — | `200` or `404` |
| DELETE | `/voice/{id}` | — | `200` or `404` |

Accents that ship a reference embedding are **`EN-US`** and **`EN_INDIA`**. Any
other accent is spoken with `EN-US` and the substitution is reported in the
`x-openvoice-source-embedding` header (e.g. `EN-US (fallback)`), which the
backend surfaces to the UI rather than hiding.

## Distro / Python requirements

OpenVoice targets **Python 3.9** and runs on **3.10 / 3.11 / 3.12**. It does
**not** work on **3.13+**: there are no compatible PyTorch wheels and MeloTTS
fails to build.

Pick a distro accordingly:

| Distro | Python | Verdict |
|---|---|---|
| Ubuntu 22.04 (jammy) | 3.10 | Best |
| Ubuntu 24.04 (noble) | 3.12 | Works |
| Ubuntu 26.04 (resolute) | 3.14 | **Unsupported** - too new |

If your default WSL distro is 26.04, install 24.04 alongside it. The official
WSL image is a self-contained `.wsl` file you can install without the Store:

```bash
# Download (Canonical CDN) and install:
# https://cdimage.ubuntu.com/ubuntu-wsl/noble/daily-live/current/noble-wsl-amd64.wsl
wsl --install --from-file noble-wsl-amd64.wsl --name Ubuntu-24.04
```

`setup.sh` auto-selects the newest available Python 3.9-3.11 and warns (but
continues) on 3.12; it refuses on anything else.

## Disk footprint

The full stack needs roughly **3-4 GB** installed (PyTorch ~1.5 GB, OpenVoiceV2
checkpoints ~700 MB, unidic dictionary ~500 MB, plus wheels). If space is tight,
do **not** run this and use the premade TTS voices instead (see below).

## Premade voices (no cloning, no download)

If you only need a voice that speaks, the backend already provides free, fixed
voices via Groq Orpheus TTS (`backend/app/speech/service.py`), gated on
`GROQ_API_KEY`:

`austin, autumn, daniel, diana, hannah, troy`

Set `TTS_VOICE` (default `hannah`) and leave `CLONE_PROVIDER` empty. Voice
*cloning* (custom voices from a sample) is the only thing that needs OpenVoice
or ElevenLabs.

## Setup (WSL2 Ubuntu)

```bash
# Inside an Ubuntu WSL shell:
sudo apt update
sudo apt install -y python3.9 python3.9-venv python3.9-dev git git-lfs
git lfs install

cd sidecar/openvoice_sidecar
chmod +x setup.sh
./setup.sh
```

`setup.sh` creates `.venv`, installs PyTorch (CPU), OpenVoice v2, MeloTTS,
`unidic`, and downloads the OpenVoiceV2 checkpoints into `checkpoints_v2/`.

## Run

```bash
cd sidecar/openvoice_sidecar
source .venv/bin/activate
python -m uvicorn app:app --host 127.0.0.1 --port 8011
```

First synthesis is slow on CPU (the engine loads lazily on first use; `/health`
answers immediately and reports `engine_loaded`).

## Enable it in the backend

In `backend/.env`:

```
CLONE_PROVIDER=openvoice
OPENVOICE_SIDECAR_URL=http://127.0.0.1:8011
OPENVOICE_BASE_SPEAKER=EN-US
```

Restart the backend. The Voice Training Center should now report cloning as
available. Note: OpenVoice trains from **WAV/FLAC only** — the backend rejects
other containers up front with a clear message.

## Environment variables

| Var | Default | Meaning |
|---|---|---|
| `OPENVOICE_CHECKPOINTS` | `checkpoints_v2` | Checkpoint directory |
| `OPENVOICE_DATA_DIR` | `voice_store` | Where cloned embeddings are stored |
| `OPENVOICE_DEVICE` | auto (`cuda:0` else `cpu`) | Torch device |
