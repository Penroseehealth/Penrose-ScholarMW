import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_colors.dart';

class LanguagePronunciation extends StatelessWidget {
  const LanguagePronunciation({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          title: const Text('Pronunciation'),
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection('Vowel Sounds', [
              _buildPronunciationCard('Short Vowels', 'a, e, i, o, u as in cat, bed, sit, hot, cup'),
              _buildPronunciationCard('Long Vowels', 'a, e, i, o, u as in cake, he, bike, note, cute'),
              _buildPronunciationCard('Schwa', 'The unstressed /ə/ sound as in about, sofa'),
            ]),
            const SizedBox(height: 24),
            _buildSection('Consonant Sounds', [
              _buildPronunciationCard('Stops', 'p, b, t, d, k, g'),
              _buildPronunciationCard('Fricatives', 'f, v, s, z, sh, zh, h'),
              _buildPronunciationCard('Nasals', 'm, n, ng as in man, no, sing'),
              _buildPronunciationCard('Liquids & Glides', 'l, r, w, y as in let, run, wet, yes'),
            ]),
            const SizedBox(height: 24),
            _buildSection('Stress & Intonation', [
              _buildPronunciationCard(
                  'Word Stress', 'Content words (nouns, verbs) are stressed; function words are not'),
              _buildPronunciationCard('Sentence Stress', 'Key words in a sentence receive the most emphasis'),
              _buildPronunciationCard('Intonation Patterns', 'Rising for questions, falling for statements'),
            ]),
            const SizedBox(height: 24),
            _buildSection('Common Challenges', [
              _buildPronunciationCard('th sounds', 'Place tongue between teeth: think /θ/, this /ð/'),
              _buildPronunciationCard('Silent Letters', 'knight, psychology, honest — the letter is not pronounced'),
              _buildPronunciationCard('Linking Words', 'Join the end of one word to the start of the next: turn‿off'),
            ]),
          ],
        ),
      );

  static Widget _buildSection(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      );

  static Widget _buildPronunciationCard(String title, String desc) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.volume_up_rounded, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      );
}
