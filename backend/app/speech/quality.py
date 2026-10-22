"""Objective measurements on a voice-training sample.

Â§7 asks the app to assess signal-to-noise ratio, clipping, silence, background
speech, recording consistency and intelligibility before it will train a model
from someone's voice. A clone built on a noisy or clipped sample is worse than
no clone: it is confidently wrong about how the user sounds.

The measurements here are real signal analysis, not decoration, but they are
also honest about their limits:

* Only uncompressed PCM is analysed. The browser recorder can hand over WebM or
  M4A, and decoding those needs a codec this project does not ship, so those
  samples get `measured: false` with the reason attached. Nothing is guessed.
* Background speech is *inferred*, never measured â€” separating two talkers
  needs diarization. The only honest signal available is what the transcriber
  could make of the audio, so a long recording that transcribes to almost
  nothing is flagged as "possibly music or background talk" rather than
  reported as a verified multi-speaker verdict.
* Intelligibility uses the existing STT provider on the sample, which is the
  same pipeline the conversation itself uses.
* SNR compares the loudest half of the recording's own frames to the quietest
  half, so it is defined for every sample. That includes a sample that stays
  loud from end to end, and one where the background is as loud as the voice -
  the ratio comes out near 0 dB and the sample is correctly refused. The only
  unmeasured case is digital silence, where there is no floor to compare
  against. See `_analyze_levels` for why an early version that skipped the
  measurement was worse than useless here.

`quality_report()` never returns a pass/fail invented from missing data: when a
measurement is unavailable the report says so and [QualityReport.blockers] stays
empty rather than blocking on a number nobody took.
"""

from __future__ import annotations

import io
import math
import wave
from array import array
from dataclasses import asdict, dataclass, field

from app.speech.exceptions import ValidationError

# A sample shorter than this is refused before it reaches a provider, which
# needs at least this much audio to build a model from. Kept in step with
# `cloning.validate_sample`, so the two gates cannot disagree.
_MIN_SAMPLE_MS = 8_000
# Detected *speech* inside the sample. Deliberately well below the sample
# length: real recordings are full of pauses, and a 9s clip of natural speech is
# only ~6s of voice. Requiring 8s of non-silence would reject good recordings
# for breathing room the provider does not need.
_MIN_SPEECH_CONTENT_MS = 4_000
# A 16-bit sample reaching within this of full scale is treated as clipped.
_CLIP_THRESHOLD = 0.988
# Frames quieter than this fraction of the peak are treated as breath or room
# tone rather than voice.
_SILENCE_FLOOR_RATIO = 0.02
# A frame at or below this multiple of the measured room tone counts as silence.
_SILENCE_LEVEL_RATIO = 2.0
# Frame length for the level/silence analysis: 20 ms, short enough to catch a
# pause and long enough not to be dominated by pitch cycles.
_FRAME_MS = 20
# Words per minute below which a transcript is suspiciously sparse for the
# amount of audio, which is the signal that something other than speech
# dominated the recording.
_SPARSE_WPM_THRESHOLD = 60.0

# Thresholds for refusing a sample outright. These are the "record again"
# conditions from Â§7, kept as named constants so the test suite and the user-facing
# message can never drift apart.
_MIN_SNR_DB = 12.0
_MAX_CLIPPED_RATIO = 0.02
_MAX_SILENCE_RATIO = 0.6


@dataclass
class QualityReport:
    """What we measured, and what we deliberately did not."""

    measured: bool = False
    reason: str = ""

    duration_ms: int = 0
    speech_ms: int = 0
    sample_rate: int = 0
    channels: int = 0

    # None means "not measured", which is different from zero.
    snr_db: float | None = None
    clipped_ratio: float | None = None
    silence_ratio: float | None = None
    level_consistency_db: float | None = None
    peak_dbfs: float | None = None

    words: int = 0
    words_per_minute: float | None = None
    intelligibility: str = "unknown"  # good | low | unknown

    background_speech: str = "unknown"  # suspected | clear | unknown

    # The user-facing advice, in the order it matters most.
    warnings: list[str] = field(default_factory=list)
    blockers: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return asdict(self)

    @property
    def acceptable(self) -> bool:
        return not self.blockers


def _to_db(value: float) -> float:
    """Amplitude ratio to decibels, floored so silence is -99 dB not -inf."""
    if value <= 0:
        return -99.0
    return 20.0 * math.log10(value)


def _percent(ration: float) -> float:
    return round(ration * 100.0, 1)


def _decode_pcm(data: bytes) -> tuple[array, int, int] | None:
    """Read a PCM WAV into normalised float samples in -1..1.

    Returns None for anything that is not decodable PCM (compressed WebM/M4A,
    24-bit, or a truncated header) so the caller can report "not measured"
    instead of a fabricated number.
    """
    try:
        with wave.open(io.BytesIO(data), "rb") as handle:
            channels = handle.getnchannels()
            width = handle.getsampwidth()
            rate = handle.getframerate()
            frames = handle.readframes(handle.getnframes())
    except (wave.Error, EOFError, ValueError):
        return None
    if width != 2 or channels < 1 or not frames:
        # 8/24/32-bit and non-PCM encodings are out of scope; say so rather than
        # interpreting the bytes as if they were 16-bit samples.
        return None
    pcm = array("h")
    pcm.frombytes(frames[: len(frames) - (len(frames) % 2)])
    samples = array("f", (value / 32768.0 for value in pcm))
    return samples, rate, channels


def _frame_rms(samples: array, start: int, end: int) -> float:
    total = 0.0
    count = end - start
    if count <= 0:
        return 0.0
    for index in range(start, end):
        total += samples[index] * samples[index]
    return math.sqrt(total / count)


def analyze_pcm(data: bytes) -> QualityReport:
    """Full measurement pass over an uncompressed sample."""
    decoded = _decode_pcm(data)
    if decoded is None:
        return QualityReport(
            measured=False,
            reason=(
                "This recording is compressed, so its noise floor and clipping "
                "cannot be measured. Training is still allowed."
            ),
        )
    samples, rate, channels = decoded
    if not samples:
        return QualityReport(measured=False, reason="The sample decoded to no audio.")

    per_channel = len(samples) // channels if channels else len(samples)
    duration_ms = int(round(per_channel / rate * 1000)) if rate else 0
    report = QualityReport(measured=True, duration_ms=duration_ms)
    report.sample_rate = rate
    report.channels = channels

    peak = max(abs(value) for value in samples)
    report.peak_dbfs = round(_to_db(peak), 1)

    # Clipping: samples pinned at the top of the range carry no information and
    # are what makes a clone sound harsh.
    clipped = sum(1 for value in samples if abs(value) >= _CLIP_THRESHOLD)
    report.clipped_ratio = round(clipped / len(samples), 4)

    # Per-frame energy. The noise floor is then taken from the quietest frames
    # rather than from an absolute threshold, because room tone is whatever the
    # room is at and a quiet-but-clean recording must not be mistaken for noise.
    frames_per_window = max(1, int(rate * _FRAME_MS / 1000))
    energies: list[float] = []
    for start in range(0, len(samples) - frames_per_window + 1, frames_per_window):
        energies.append(_frame_rms(samples, start, start + frames_per_window))
    if not energies:
        return report

    _analyze_levels(report, energies)
    _apply_signal_rules(report)
    return report


def _analyze_levels(report: QualityReport, energies: list[float]) -> None:
    """Split the frames into room tone, speech and silence.

    SNR is the loudest decile over the quietest decile. That ratio is defined for
    every recording, including one whose noise is as loud as the voice â€” where it
    comes out near 0 dB and the sample is correctly refused. An earlier version
    refused to report a ratio at all when the recording had little dynamic range,
    on the theory that there was nothing to measure; that silently passed exactly
    the worst samples through, which is the opposite of what the check is for.
    """
    ordered = sorted(energies)
    loudest = ordered[-1]

    # The lowest decile is the room; the loudest half is the voice.
    floor_count = max(1, len(ordered) // 10)
    noise_rms = _rms(ordered[:floor_count])
    speech_values = ordered[len(ordered) // 2 :]
    speech_rms = _rms(speech_values)
    if noise_rms > 0:
        report.snr_db = round(_to_db(speech_rms / noise_rms), 1)
    # Speech is whatever stands above the room's own level; a sample where
    # nothing does is reported as having no detectable speech rather than
    # inventing a duration for it.
    report.speech_ms = int(
        sum(
            1
            for value in energies
            if value
            > max(noise_rms * _SILENCE_LEVEL_RATIO, loudest * _SILENCE_FLOOR_RATIO)
        )
        * _FRAME_MS
    )
    # Silence is "at the room's own level", which survives a loud room and a
    # quiet one alike.
    report.silence_ratio = round(
        sum(1 for value in energies if value <= noise_rms * _SILENCE_LEVEL_RATIO)
        / len(energies),
        4,
    )
    report.level_consistency_db = _spread_db(speech_values)


def _rms(values: list[float]) -> float:
    if not values:
        return 0.0
    return math.sqrt(sum(value * value for value in values) / len(values))


def _spread_db(values: list[float]) -> float | None:
    """Loudness variation across frames, in dB relative to the mean.

    A steady reading means a consistent microphone distance; a wild one means
    the user moved, or the input level was riding an auto-gain.
    """
    if len(values) < 2:
        return None
    mean = sum(values) / len(values)
    if mean <= 0:
        return None
    variance = sum((value - mean) ** 2 for value in values) / len(values)
    return round(20.0 * math.log10(math.sqrt(variance) / mean + 1e-12), 1)


def _apply_signal_rules(report: QualityReport) -> None:
    """Turn measurements into the "record again" advice from Â§7."""
    if report.snr_db is not None and report.snr_db < _MIN_SNR_DB:
        report.warnings.append(
            "The recording contains substantial background noise. Please record "
            "again in a quiet room for a more accurate voice model."
        )
        report.blockers.append("background_noise")
    if report.clipped_ratio is not None and report.clipped_ratio > _MAX_CLIPPED_RATIO:
        report.warnings.append(
            "The recording is clipping â€” the microphone was probably too close "
            "or the level too high. Move back a little and record again."
        )
        report.blockers.append("clipping")
    if (
        report.silence_ratio is not None
        and report.silence_ratio > _MAX_SILENCE_RATIO
        and "background_noise" not in report.blockers
    ):
        # Only reported on its own. When the room is that loud every frame sits
        # at the room's level, and telling the user their recording is "mostly
        # silence" would point them at the wrong problem.
        report.warnings.append(
            "Most of the recording is silence. Please record again with more continuous speech."
        )
        report.blockers.append("silence")
    if report.speech_ms and report.speech_ms < _MIN_SPEECH_CONTENT_MS:
        report.warnings.append(
            f"Only {report.speech_ms / 1000:.1f}s of speech was detected. Record "
            f"at least {_MIN_SPEECH_CONTENT_MS / 1000:.0f}s of continuous speech."
        )
        report.blockers.append("insufficient_speech")
    if report.level_consistency_db is not None and report.level_consistency_db > 6.0:
        report.warnings.append(
            "The recording level changes a lot, which usually means the "
            "microphone distance was not kept steady. Try to stay the same "
            "distance throughout."
        )
    if report.peak_dbfs is not None and report.peak_dbfs < -30.0:
        report.warnings.append(
            "The recording is very quiet. Speak closer to the microphone or raise your input level."
        )


def apply_transcript(
    report: QualityReport, transcript: str, duration_ms: int
) -> QualityReport:
    """Fold the STT result into the report (intelligibility, Â§7).

    The transcript is the one intelligibility measurement available: if the
    engine that will have to understand the user cannot make sense of the
    training sample, a model built from it will not help.
    """
    words = [word for word in (transcript or "").split() if word.strip()]
    report.words = len(words)
    total_ms = duration_ms or report.duration_ms
    if not words or not total_ms:
        report.intelligibility = "unknown"
        if total_ms and not words:
            # Audio long enough to matter but nothing transcribable in it.
            report.background_speech = "suspected"
            report.warnings.append(
                "Nothing could be transcribed from this recording. Please make "
                "sure it is your own speech, with no music or background talk."
            )
        return report
    minutes = total_ms / 60000.0
    wpm = len(words) / minutes if minutes > 0 else 0.0
    report.words_per_minute = round(wpm, 1)
    report.background_speech = "clear" if wpm >= _SPARSE_WPM_THRESHOLD else "suspected"
    if wpm < _SPARSE_WPM_THRESHOLD:
        report.intelligibility = "low"
        report.warnings.append(
            "Very little speech was recognised in this recording. Please record "
            "again, speaking naturally and without background music."
        )
    else:
        report.intelligibility = "good"
    return report


def quality_report(
    data: bytes,
    mime_type: str,
    *,
    transcript: str = "",
    duration_ms: int = 0,
) -> QualityReport:
    """Measure a sample end to end.

    Compressed audio is accepted with `measured: false` â€” refusing to train
    because the browser chose WebM would block the common case, and the checks
    that matter for compressed audio (duration, intelligibility) still run.
    """
    report = analyze_pcm(data)
    if not report.measured and duration_ms:
        # Keep whatever we can: the caller often knows the duration from the
        # recorder even when the container is not decodable here.
        report.duration_ms = duration_ms
    if report.duration_ms and report.duration_ms < _MIN_SAMPLE_MS:
        report.blockers.append("too_short")
        # Names the clip length, not "speech": this check is on the total
        # recording, and the separate speech-content check above is the one
        # that counts voiced audio. Saying "8 seconds of speech" here told a
        # user with a 20s recording that it was too short.
        report.warnings.append(
            f"This recording is {_report_seconds(report.duration_ms)} long, which is "
            f"under the {_report_seconds(_MIN_SAMPLE_MS)} minimum. Record a longer clip."
        )
    elif not report.duration_ms:
        # We genuinely do not know the length (a compressed container we cannot
        # decode and no declared duration). That is not evidence of a short
        # recording, so it must never be reported as one.
        report.warnings.append(
            "The length of this recording could not be verified, so the minimum "
            "sample length was not checked."
        )
    apply_transcript(report, transcript, report.duration_ms)
    return report


def _report_seconds(milliseconds: int) -> str:
    """A duration in the units a person would say out loud."""
    seconds = milliseconds / 1000
    return f"{seconds:.1f}s" if seconds < 10 else f"{seconds:.0f}s"


def enforce_quality(report: QualityReport) -> None:
    """Refuse a sample that would produce a misleading model.

    Only measured problems block. An unmeasured sample (compressed container,
    silent transcriber) produces advice, never a rejection dressed up as a
    measurement.
    """
    if report.acceptable:
        return
    headline = report.warnings[0] if report.warnings else "The recording is not usable."
    raise ValidationError(headline, details={"quality": report.to_dict()})
