import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

class VoiceCloneManager extends StatefulWidget {
  VoiceCloneManager({super.key});

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
      decoration: BoxDecoration(
        color: context.colors.surface,
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
                decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Voice Cloning',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
            SizedBox(height: 8),
            _buildConsentBanner(),
            SizedBox(height: 16),
            if (_consentConfirmed) ...[
              _buildNameField(),
              SizedBox(height: 12),
              _buildRecordingSection(),
              SizedBox(height: 16),
              _buildCreateButton(),
            ],
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _consentConfirmed ? context.colors.successMuted : context.colors.warningMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _consentConfirmed
              ? context.colors.success.withValues(alpha: 0.3)
              : context.colors.warning.withValues(alpha: 0.3),
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
                color: _consentConfirmed ? context.colors.success : context.colors.warning,
              ),
              SizedBox(width: 8),
              Text(
                _consentConfirmed ? 'Consent Confirmed' : 'Authorization Required',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _consentConfirmed ? context.colors.success : context.colors.warning,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Voice cloning creates a synthetic version of your voice. By proceeding, you confirm that:\n'
            '• You own or have authorization to use this voice\n'
            '• You understand this creates a synthetic voice model\n'
            '• The cloned voice is private and belongs to your account\n'
            '• You can delete it at any time',
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary, height: 1.4),
          ),
          SizedBox(height: 8),
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
                      color: _consentConfirmed ? AppColors.primary : context.colors.textMuted,
                    ),
                  ),
                  child: _consentConfirmed
                      ? Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'I confirm I own or have authorization to use this voice',
                    style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
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
      style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Voice Name',
        labelStyle: TextStyle(color: context.colors.textMuted),
        hintText: 'e.g., My Custom Voice',
        hintStyle: TextStyle(color: context.colors.textMuted.withValues(alpha: 0.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildRecordingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          if (!_hasSample) ...[
            Icon(Icons.mic_rounded, size: 32, color: context.colors.textSecondary),
            SizedBox(height: 8),
            Text(
              'Record or upload a voice sample',
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              'Speak naturally for 10-30 seconds',
              style: TextStyle(fontSize: 11, color: context.colors.textMuted),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _sampleBtn(Icons.mic_rounded, 'Record', () {
                  setState(() {
                    _isRecording = !_isRecording;
                  });
                  if (_isRecording) {
                    Future.delayed(Duration(seconds: 15), () {
                      if (mounted) setState(() {
                        _isRecording = false;
                        _hasSample = true;
                      });
                    });
                  }
                }),
                SizedBox(width: 16),
                _sampleBtn(Icons.upload_file_rounded, 'Upload', () {
                  setState(() => _hasSample = true);
                }),
              ],
            ),
          ] else ...[
            Icon(Icons.check_circle_rounded, size: 32, color: context.colors.success),
            SizedBox(height: 8),
            Text(
              'Voice sample recorded',
              style: TextStyle(fontSize: 13, color: context.colors.success, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _hasSample = false),
              child: Text(
                'Re-record',
                style: TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ),
          ],
          if (_isRecording) ...[
            SizedBox(height: 12),
            Text(
              'Recording... Speak naturally',
              style: TextStyle(fontSize: 12, color: context.colors.error),
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              backgroundColor: context.colors.border,
              valueColor: AlwaysStoppedAnimation(context.colors.error.withValues(alpha: 0.7)),
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
          color: context.colors.surfaceHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: context.colors.textSecondary),
            SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
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
          backgroundColor: canCreate ? AppColors.primary : context.colors.surfaceHighest,
          foregroundColor: canCreate ? Colors.white : context.colors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          canCreate ? 'Create Custom Voice' : 'Complete all steps above',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
