import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../services/stem_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../core/theme/theme_colors.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  final StemService _stemService = StemService();

  List<dynamic> _certificates = [];
  bool _loading = true;
  String? _error;

  bool _generating = false;
  String? _generateError;
  String? _generateSuccess;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _stemService.getCertificates();
      if (mounted) setState(() { _certificates = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load certificates'; _loading = false; });
    }
  }

  Future<void> _generateCertificate(String type, {String? subjectSlug}) async {
    setState(() { _generating = true; _generateError = null; _generateSuccess = null; });
    try {
      final result = await _stemService.generateCertificate(type, subjectSlug: subjectSlug);
      if (mounted) {
        if (result.isNotEmpty && result.containsKey('id')) {
          setState(() { _generateSuccess = 'Certificate generated!'; _generating = false; });
          _loadCertificates();
        } else if (result.containsKey('message')) {
          setState(() { _generateError = result['message']; _generating = false; });
        } else {
          setState(() { _generateSuccess = 'Certificate generated!'; _generating = false; });
          _loadCertificates();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _generateError = 'Generation failed. Check eligibility requirements.'; _generating = false; });
    }
  }

  Future<void> _shareCertificate(int id) async {
    try {
      final data = await _stemService.getCertificateShareData(id);
      if (data.isEmpty) return;
      final shareText = StringBuffer();
      shareText.writeln('Certificate: ${data['title'] ?? 'Achievement'}');
      if (data['subject'] != null) shareText.writeln('Subject: ${data['subject']}');
      if (data['score_percentage'] != null) shareText.writeln('Score: ${data['score_percentage']}%');
      shareText.writeln('Issued: ${_formatDate(data['issued_at'])}');
      shareText.writeln('Verify: ${data['verification_url'] ?? ''}');
      await Clipboard.setData(ClipboardData(text: shareText.toString()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Certificate data copied to clipboard'),
            backgroundColor: context.colors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to get share data'),
            backgroundColor: context.colors.error,
          ),
        );
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'exam_achievement':
        return Icons.emoji_events_outlined;
      case 'challenge_champion':
        return Icons.local_fire_department_outlined;
      case 'subject_mastery':
        return Icons.stars_outlined;
      default:
        return Icons.workspace_premium_outlined;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'exam_achievement':
        return AppColors.primary;
      case 'challenge_champion':
        return const Color(0xFFFF6B35);
      case 'subject_mastery':
        return context.colors.teal;
      default:
        return AppColors.primaryLight;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'exam_achievement':
        return 'Exam Achievement';
      case 'challenge_champion':
        return 'Challenge Champion';
      case 'subject_mastery':
        return 'Subject Mastery';
      default:
        return 'Certificate';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: RefreshIndicator(
        onRefresh: _loadCertificates,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.textPrimary, size: 18),
                onPressed: () => Navigator.maybePop(context),
              ),
              backgroundColor: const Color(0xFF1A1040),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  'My Certificates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A1040), AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Icon(Icons.workspace_premium_outlined, color: context.colors.textMuted, size: 48),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: _loading
                  ? SliverToBoxAdapter(child: ShimmerLoading.list(count: 4))
                  : _error != null
                      ? SliverToBoxAdapter(child: _buildErrorState())
                      : _certificates.isEmpty
                          ? SliverToBoxAdapter(child: _buildEmptyState())
                          : SliverList.list(
                              children: [
                                ..._certificates.map((c) => _buildCertificateCard(c)),
                                const SizedBox(height: 24),
                                _buildGenerateSection(),
                                const SizedBox(height: 40),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateCard(dynamic cert) {
    final title = cert['title'] ?? 'Certificate';
    final description = cert['description'] ?? '';
    final subject = cert['subject'] ?? cert['subject_name'];
    final score = cert['score_percentage'];
    final issuedAt = cert['issued_at'] ?? cert['created_at'];
    final certType = cert['certificate_type'] ?? cert['type'] ?? 'exam_achievement';
    final id = cert['id'] ?? 0;
    final color = _typeColor(certType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_typeIcon(certType), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _typeLabel(certType),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: context.colors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    if (subject != null) ...[
                      _buildMetaChip(Icons.school_outlined, subject.toString(), context.colors.info),
                      const SizedBox(width: 8),
                    ],
                    if (score != null) ...[
                      _buildMetaChip(Icons.bar_chart_outlined, '${score.round()}%', context.colors.success),
                      const SizedBox(width: 8),
                    ],
                    _buildMetaChip(Icons.calendar_today_outlined, _formatDate(issuedAt), context.colors.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _shareCertificate(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_outlined, size: 14, color: AppColors.primaryLight),
                        SizedBox(width: 6),
                        Text(
                          'Share',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.workspace_premium_outlined, size: 56, color: context.colors.textMuted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No certificates yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete challenges and ace exams to earn certificates!',
            style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: context.colors.error),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadCertificates,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Check Eligibility & Generate',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Generate certificates you\'ve earned through your achievements',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
          const SizedBox(height: 14),
          if (_generating) ...[
            const LinearProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 10),
          ],
          if (_generateSuccess != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.successMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: context.colors.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_generateSuccess!, style: TextStyle(fontSize: 12, color: context.colors.success, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          if (_generateError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.errorMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: context.colors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_generateError!, style: TextStyle(fontSize: 12, color: context.colors.error, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          _buildGenerateButton(
            'Check Subject Mastery Certificate',
            Icons.stars_outlined,
            context.colors.teal,
            () => _generateCertificate('subject_mastery'),
          ),
          const SizedBox(height: 8),
          _buildGenerateButton(
            'Check Exam Achievement Certificate',
            Icons.emoji_events_outlined,
            AppColors.primary,
            () => _generateCertificate('exam_achievement'),
          ),
          const SizedBox(height: 8),
          _buildGenerateButton(
            'Check Challenge Champion Certificate',
            Icons.local_fire_department_outlined,
            const Color(0xFFFF6B35),
            () => _generateCertificate('challenge_champion'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: _generating ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _generating ? context.colors.textMuted : color,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: _generating ? context.colors.textMuted : color),
          ],
        ),
      ),
    );
  }
}
