import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class VoiceCloneManager extends StatefulWidget {
  const VoiceCloneManager({super.key});

  @override
  State<VoiceCloneManager> createState() => _VoiceCloneManagerState();
}

class _VoiceCloneManagerState extends State<VoiceCloneManager> {
  bool _consentConfirmed = false;
  bool _isRecording = false;
  bool _hasSample = false;
  final _nameCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Voice Cloning',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            _buildConsentBanner(),
            const SizedBox(height: 16),
            if (_consentConfirmed) ...[
              _buildNameField(),
              const SizedBox(height: 12),
              _buildRecordingSection(),
              const SizedBox(height: 16),
              _buildCreateButton(),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _consentConfirmed ? AppColors.successMuted : AppColors.warningMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _consentConfirmed
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _consentConfirmed ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                size: 16,
                color: _consentConfirmed ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                _consentConfirmed ? 'Consent Confirmed' : 'Authorization Required',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _consentConfirmed ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Voice cloning creates a synthetic version of your voice. By proceeding, you confirm that:\n'
            '• You own or have authorization to use this voice\n'
            '• You understand this creates a synthetic voice model\n'
            '• The cloned voice is private and belongs to your account\n'
            '• You can delete it at any time',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _consentConfirmed = !_consentConfirmed),
            child: Row(
              children: [
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _consentConfirmed ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _consentConfirmed ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                  child: _consentConfirmed
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'I confirm I own or have authorization to use this voice',
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameCtrl,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Voice Name',
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintText: 'e.g., My Custom Voice',
        hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildRecordingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (!_hasSample) ...[
            const Icon(Icons.mic_rounded, size: 32, color: AppColors.textSecondary),
            const SizedBox(height: 8),
            const Text(
              'Record or upload a voice sample',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Speak naturally for 10-30 seconds',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _sampleBtn(Icons.mic_rounded, 'Record', () {
                  setState(() {
                    _isRecording = !_isRecording;
                  });
                  if (_isRecording) {
                    Future.delayed(const Duration(seconds: 15), () {
                      if (mounted) setState(() {
                        _isRecording = false;
                        _hasSample = true;
                      });
                    });
                  }
                }),
                const SizedBox(width: 16),
                _sampleBtn(Icons.upload_file_rounded, 'Upload', () {
                  setState(() => _hasSample = true);
                }),
              ],
            ),
          ] else ...[
            const Icon(Icons.check_circle_rounded, size: 32, color: AppColors.success),
            const SizedBox(height: 8),
            const Text(
              'Voice sample recorded',
              style: TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _hasSample = false),
              child: const Text(
                'Re-record',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ),
          ],
          if (_isRecording) ...[
            const SizedBox(height: 12),
            const Text(
              'Recording... Speak naturally',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(AppColors.error.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sampleBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final canCreate = _consentConfirmed && _hasSample && _nameCtrl.text.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canCreate ? () => Navigator.pop(context) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canCreate ? AppColors.primary : AppColors.surfaceHighest,
          foregroundColor: canCreate ? Colors.white : AppColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          canCreate ? 'Create Custom Voice' : 'Complete all steps above',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
