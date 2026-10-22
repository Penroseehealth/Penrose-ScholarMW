import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/vtc_audio.dart';
import '../vtc_theme.dart';

/// Result audio for the most recent synthesis, if any.
class GeneratedSpeech {
  const GeneratedSpeech({
    required this.base64,
    required this.mime,
    required this.voice,
    required this.provider,
    required this.model,
  });

  final String base64;
  final String mime;
  final String voice;
  final String provider;
  final String model;
}

/// Full transport for generated speech: play/pause, scrubber, elapsed/total,
/// volume, replay, download, share and "generate again".
///
/// Every value is read from the real audio element, so the bar only enables
/// once the browser actually reports a duration.
class VtcAudioPlayer extends StatefulWidget {
  const VtcAudioPlayer({super.key, required this.speech, required this.onRegenerate, required this.onNotice});

  final GeneratedSpeech speech;

  /// Re-runs synthesis with the same text/voice.
  final VoidCallback onRegenerate;

  /// Surfaces download/share outcomes.
  final ValueChanged<String> onNotice;

  @override
  State<VtcAudioPlayer> createState() => _VtcAudioPlayerState();
}

class _VtcAudioPlayerState extends State<VtcAudioPlayer> {
  late final VtcAudioEngine _engine = VtcAudio.create();
  Timer? _poll;

  double _position = 0;
  double _duration = 0;
  bool _playing = false;
  bool _scrubbing = false;
  double _scrubValue = 0;
  String? _loadError;

  String get _filename => 'penrose-voice-${widget.speech.voice}.${_extensionFor(widget.speech.mime)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VtcAudioPlayer old) {
    super.didUpdateWidget(old);
    if (old.speech.base64 != widget.speech.base64) _load();
  }

  void _load() {
    final result = _engine.load(widget.speech.base64, widget.speech.mime);
    if (!mounted) return;
    setState(() {
      _loadError = result.ok ? null : result.error;
      _position = 0;
      _duration = 0;
      _playing = false;
    });
    if (result.ok) {
      _startPolling();
      // Play as soon as the browser accepts it.
      _engine.play();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final d = _engine.duration;
      final p = _engine.position;
      final playing = _engine.playing;
      if (!mounted) return;
      setState(() {
        _duration = d;
        _position = p;
        _playing = playing;
        if (!_scrubbing) _scrubValue = p;
      });
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _engine.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_engine.playing) {
      _engine.pause();
    } else {
      // Replay from the start once finished.
      if (_duration > 0 && _position >= _duration - 0.15) {
        _engine.seek(0);
      }
      _engine.play();
    }
    setState(() => _playing = _engine.playing);
  }

  void _replay() {
    _engine.seek(0);
    _engine.play();
    setState(() => _scrubValue = 0);
  }

  Future<void> _download() async {
    final res = await _engine.download(_filename);
    if (mounted) widget.onNotice(res.message ?? 'Download unavailable.');
  }

  Future<void> _share() async {
    final res = await _engine.share(_filename);
    if (!mounted) return;
    if (res.fellBackToDownload) {
      widget.onNotice(res.message ?? 'Sharing is unavailable here.');
      return;
    }
    widget.onNotice(res.message ?? 'Share unavailable.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return _Panel(
        icon: Icons.error_outline_rounded,
        iconColor: VtcPalette.danger,
        title: 'Audio could not be loaded',
        body: _loadError!,
        trailing: TextButton(
          onPressed: widget.onRegenerate,
          child: Text('Generate Again', style: VtcType.bodyIvory(context).copyWith(color: VtcPalette.goldLight)),
        ),
      );
    }

    final ready = _duration > 0;
    return _Panel(
      icon: Icons.graphic_eq_rounded,
      iconColor: VtcPalette.success,
      title: 'Speech ready',
      body: '${widget.speech.provider} · ${widget.speech.model} · ${widget.speech.voice}',
      trailing: TextButton.icon(
        onPressed: widget.onRegenerate,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text('Generate Again', style: VtcType.bodyIvory(context).copyWith(color: VtcPalette.goldLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Row(
            children: [
              _RoundTransport(
                icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onPressed: _engine.supported ? _toggle : null,
                tooltip: _playing ? 'Pause' : 'Play',
              ),
              const SizedBox(width: 8),
              _RoundTransport(
                icon: Icons.replay_rounded,
                onPressed: ready ? _replay : null,
                tooltip: 'Replay',
                small: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _Scrubber(
                      max: ready ? _duration : 1,
                      value: _scrubbing ? _scrubValue : _position,
                      enabled: ready,
                      onStart: () {
                        _engine.setSeeking(true);
                        setState(() => _scrubbing = true);
                      },
                      onChanged: (v) => setState(() => _scrubValue = v),
                      onEnd: (v) {
                        _engine.seek(v);
                        _engine.setSeeking(false);
                        setState(() {
                          _scrubbing = false;
                          _scrubValue = v;
                        });
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _format(_scrubbing ? _scrubValue : _position),
                          style: VtcType.body(context).copyWith(fontSize: 12),
                        ),
                        Text(ready ? _format(_duration) : '--:--', style: VtcType.body(context).copyWith(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _VolumeControl(
                volume: _engine.volume,
                onChanged: (v) {
                  _engine.setVolume(v);
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              _RoundTransport(
                icon: Icons.download_rounded,
                onPressed: _engine.supported ? _download : null,
                tooltip: 'Download',
                small: true,
              ),
              const SizedBox(width: 6),
              _RoundTransport(
                icon: Icons.ios_share_rounded,
                onPressed: _engine.supported ? _share : null,
                tooltip: 'Share',
                small: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.child,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0x4D0B1330),
        border: Border.all(color: VtcPalette.electric.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: VtcType.bodyIvory(context).copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VtcType.body(context).copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RoundTransport extends StatelessWidget {
  const _RoundTransport({required this.icon, required this.onPressed, required this.tooltip, this.small = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 34.0 : 46.0;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: small ? null : VtcPalette.goldGradient,
                color: small ? const Color(0x33FFFFFF) : null,
                border: Border.all(color: VtcPalette.gold.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, size: small ? 17 : 24, color: small ? VtcPalette.ivory : VtcPalette.navyDeep),
            ),
          ),
        ),
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.max,
    required this.value,
    required this.enabled,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
  });

  final double max;
  final double value;
  final bool enabled;
  final VoidCallback onStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Semantics(
      slider: true,
      enabled: enabled,
      label: 'Playback position',
      value: '${(fraction * 100).round()} percent',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            void update(Offset local) {
              final w = constraints.maxWidth;
              if (w <= 0) return;
              onChanged(((local.dx / w).clamp(0.0, 1.0)) * max);
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: enabled
                  ? (d) {
                      onStart();
                      update(d.localPosition);
                    }
                  : null,
              onHorizontalDragUpdate: enabled ? (d) => update(d.localPosition) : null,
              onHorizontalDragEnd: enabled ? (d) => onEnd(value.clamp(0.0, max)) : null,
              onTapDown: enabled
                  ? (d) {
                      onStart();
                      update(d.localPosition);
                      onEnd(value.clamp(0.0, max));
                    }
                  : null,
              child: SizedBox(
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction == 0 ? 0.0001 : fraction,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: VtcPalette.goldGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Thumb
                    Align(
                      alignment: Alignment(fraction * 2 - 1, 0),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: VtcPalette.goldLight,
                          boxShadow: [BoxShadow(color: VtcPalette.gold.withValues(alpha: 0.7), blurRadius: 8)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VolumeControl extends StatelessWidget {
  const _VolumeControl({required this.volume, required this.onChanged});

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      slider: true,
      label: 'Volume',
      value: '${(volume * 100).round()} percent',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              volume <= 0.001 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 18,
              color: VtcPalette.ivoryDim,
            ),
            SizedBox(
              width: 74,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: VtcPalette.gold,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                  thumbColor: VtcPalette.goldLight,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(value: volume.clamp(0.0, 1.0), onChanged: onChanged),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _format(double seconds) {
  if (seconds <= 0 || !seconds.isFinite) return '0:00';
  final total = seconds.round();
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _extensionFor(String mime) {
  if (mime.contains('wav')) return 'wav';
  if (mime.contains('ogg')) return 'ogg';
  if (mime.contains('mp4')) return 'm4a';
  if (mime.contains('mpeg')) return 'mp3';
  return 'audio';
}
