import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/theme_colors.dart';

/// Full-screen player for a generated practical simulation video.
class PracticalVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const PracticalVideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.title = 'Practical Simulation',
  });

  @override
  State<PracticalVideoPlayerScreen> createState() => _PracticalVideoPlayerScreenState();
}

class _PracticalVideoPlayerScreenState extends State<PracticalVideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _initializing = true;
  bool _failed = false;
  String? _error;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
      _controller.setLooping(false);
      _controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _failed = true;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$m:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final playing = _controller.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)))
          : _failed
              ? _buildError(colors)
              : Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _controlsVisible = !_controlsVisible),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                        if (_controlsVisible) _buildControls(colors, playing, position, duration),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildControls(
    ThemeColors colors,
    bool playing,
    Duration position,
    Duration duration,
  ) =>
      Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 64,
              color: Colors.white,
              icon: Icon(
                playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              ),
              onPressed: () {
                setState(() {
                  playing ? _controller.pause() : _controller.play();
                });
              },
            ),
            if (duration > Duration.zero)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(_format(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                        max: duration.inMilliseconds.toDouble(),
                        activeColor: const Color(0xFF22D3EE),
                        inactiveColor: Colors.white24,
                        onChanged: (v) => _controller.seekTo(Duration(milliseconds: v.round())),
                      ),
                    ),
                    Text(_format(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _buildError(ThemeColors colors) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 44),
              const SizedBox(height: 12),
              const Text(
                'Could not play this video',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'The video could not be loaded.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
}
