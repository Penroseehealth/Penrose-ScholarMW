import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../services/language_service.dart';
import '../../core/theme/theme_colors.dart';

class LanguageListening extends StatefulWidget {
  LanguageListening({super.key});

  @override
  State<LanguageListening> createState() => _LanguageListeningState();
}

class _LanguageListeningState extends State<LanguageListening> {
  final LanguageService _service = LanguageService();
  List<dynamic> _vocabulary = [];
  bool _loading = true;
  bool _didLoad = false;
  double _playbackSpeed = 1.0;
  int? _playingIndex;
  String _selectedTheme = 'All';

  String get _slug =>
      GoRouterState.of(context).pathParameters['slug'] ?? 'english';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoad) {
      _didLoad = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.getVocabulary(_slug);
      if (!mounted) return;
      setState(() {
        _vocabulary = data;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[LANGUAGE LISTENING] Load error for $_slug: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<String> get _themes {
    final set = _vocabulary
        .map((v) => (v['theme'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toSet();
    return ['All', ...set];
  }

  List<dynamic> get _filtered {
    if (_selectedTheme == 'All') return _vocabulary;
    return _vocabulary
        .where((v) => v['theme']?.toString() == _selectedTheme)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSpeedControl(),
            _buildThemeTabs(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios, color: context.colors.textPrimary, size: 20),
          ),
          Icon(Icons.headphones, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Listening', style: TextStyle(
                  color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
                )),
                Text('${_filtered.length} words to practice', style: TextStyle(
                  color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 11,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.colors.surface,
      child: Row(
        children: [
          Text('Speed:', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
          SizedBox(width: 8),
          ...speeds.map((s) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _playbackSpeed = s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _playbackSpeed == s ? AppColors.primary : context.colors.surfaceHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${s}x', style: TextStyle(
                  color: _playbackSpeed == s ? Colors.white : context.colors.textSecondary,
                  fontSize: 11, fontWeight: FontWeight.w600,
                )),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildThemeTabs() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _themes.length,
        itemBuilder: (ctx, i) {
          final selected = _selectedTheme == _themes[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTheme = _themes[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : context.colors.surfaceHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selected ? AppColors.primary : context.colors.divider),
                ),
                child: Text(_themes[i], style: TextStyle(
                  color: selected ? Colors.white : context.colors.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w500,
                )),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_vocabulary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headset_off, size: 48, color: context.colors.textSecondary.withValues(alpha: 0.4)),
            SizedBox(height: 12),
            Text('No vocabulary available for listening practice', style: TextStyle(
              color: context.colors.textSecondary.withValues(alpha: 0.6), fontSize: 14,
            )),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) => _exerciseCard(_filtered[i], i),
    );
  }

  Widget _exerciseCard(dynamic exercise, int index) {
    final playing = _playingIndex == index;
    final word = (exercise['word'] ?? '').toString();
    final translation = (exercise['translation'] ?? '').toString();
    final example = (exercise['example_sentence'] ?? '').toString();
    final pos = (exercise['part_of_speech'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: playing ? AppColors.primary.withValues(alpha: 0.4) : context.colors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _playingIndex = playing ? null : index),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: playing ? AppColors.primary : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    color: playing ? Colors.white : AppColors.primary, size: 24,
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(word, style: TextStyle(
                          color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
                        )),
                        if (pos.isNotEmpty) ...[
                          SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(pos, style: TextStyle(
                              color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600,
                            )),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(translation, style: TextStyle(
                      color: context.colors.textSecondary.withValues(alpha: 0.7), fontSize: 13,
                    )),
                  ],
                ),
              ),
              if (playing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.colors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${_playbackSpeed}x', style: TextStyle(
                    color: context.colors.success, fontSize: 11, fontWeight: FontWeight.w600,
                  )),
                )
              else
                Icon(Icons.volume_up, color: context.colors.textSecondary.withValues(alpha: 0.5), size: 18),
            ],
          ),
          if (example.isNotEmpty && playing) ...[
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(example, style: TextStyle(
                color: context.colors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic, height: 1.5,
              )),
            ),
          ],
        ],
      ),
    );
  }
}
