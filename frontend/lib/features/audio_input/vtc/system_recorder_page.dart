import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/networking/api_client.dart';
import 'audio/vtc_audio.dart';
import 'vtc_theme.dart';
import 'widgets/composer_widgets.dart';
import 'widgets/recording_wave_indicator.dart';
import 'widgets/vtc_status_widgets.dart';

/// Records the audio this computer is playing (WASAPI loopback on the machine
/// running the backend), then transcribes it with the configured STT engine and
/// builds an AI summary. Zoom/Meet/browser audio needs no virtual cable.
class SystemRecorderPage extends StatefulWidget {
  const SystemRecorderPage({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<SystemRecorderPage> createState() => _SystemRecorderPageState();
}

class _SystemRecorderPageState extends State<SystemRecorderPage> {
  final TextEditingController _label = TextEditingController();
  final VtcAudioEngine _player = VtcAudio.create();
  final GlobalKey _detailKey = GlobalKey();

  Timer? _poll;
  Timer? _playerPoll;
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _recordings = const [];
  Map<String, dynamic>? _selected;
  String? _busy;
  String? _error;
  String? _notice;
  String _style = 'minutes';
  String? _playingId;
  bool _loading = true;

  static const Map<String, String> _styles = {
    'minutes': 'Meeting minutes',
    'bullets': 'Key points',
    'study_notes': 'Study notes',
    'action_items': 'Action items',
  };

  bool get _recording => _status?['active'] == true;
  double get _elapsed => ((_status?['elapsed_seconds'] as num?) ?? 0).toDouble();
  double get _level => ((_status?['level'] as num?) ?? 0).toDouble();

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _pollStatus());
    _playerPoll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (_playingId != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _playerPoll?.cancel();
    _player.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await widget.apiClient.get('/system-audio/status');
      final list = await widget.apiClient.get('/system-audio/recordings');
      final items = (list['items'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _status = status;
        _recordings = items;
        _loading = false;
        if (_selected != null) {
          final current = _selected!['id'];
          for (final item in items) {
            if (item['id'] == current) _selected = item;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(e);
      });
    }
  }

  Future<void> _pollStatus() async {
    try {
      final status = await widget.apiClient.get('/system-audio/status');
      if (!mounted) return;
      final wasRecording = _recording;
      setState(() => _status = status);
      if (wasRecording && status['active'] != true) await _refresh();
    } catch (_) {
      // Keep the last known status; the explicit actions surface hard errors.
    }
  }

  String _message(Object error) => error is AppException ? error.message : error.toString();

  Future<void> _start() async {
    setState(() {
      _busy = 'start';
      _error = null;
      _notice = null;
    });
    try {
      final started = await widget.apiClient.post(
        '/system-audio/start',
        body: {'label': _label.text.trim(), 'sample_rate': 48000, 'channels': 2},
      );
      if (!mounted) return;
      setState(() {
        _busy = null;
        _status = {...started, 'active': true, 'elapsed_seconds': 0.0, 'level': 0.0};
        _notice = 'Recording ${started['device'] ?? 'system audio'}. Minimise this tab if you like; '
            'keep the app open so the backend stays running.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = _message(e);
      });
    }
  }

  Future<void> _stop() async {
    setState(() {
      _busy = 'stop';
      _error = null;
    });
    try {
      final stopped = await widget.apiClient.post('/system-audio/stop');
      if (!mounted) return;
      setState(() {
        _busy = null;
        _status = {'active': false};
        _selected = stopped;
        _notice = 'Saved ${_clock((stopped['duration_seconds'] as num?)?.toDouble() ?? 0)} of audio '
            'as WAV and MP3.';
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = _message(e);
      });
    }
  }

  Future<void> _transcribe(Map<String, dynamic> rec) async {
    setState(() {
      _busy = 'transcribe';
      _error = null;
      _notice = null;
    });
    try {
      final updated = await widget.apiClient.post('/system-audio/recordings/${rec['id']}/transcribe', body: {});
      if (!mounted) return;
      setState(() {
        _busy = null;
        _selected = updated;
        _notice = 'Transcript ready (${updated['provider'] ?? 'AI'}).';
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = _message(e);
      });
    }
  }

  Future<void> _summarize(Map<String, dynamic> rec) async {
    setState(() {
      _busy = 'summarize';
      _error = null;
      _notice = null;
    });
    try {
      final updated = await widget.apiClient.post(
        '/system-audio/recordings/${rec['id']}/summarize',
        body: {'style': _style},
      );
      if (!mounted) return;
      setState(() {
        _busy = null;
        _selected = updated;
        _notice = 'AI summary ready.';
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = _message(e);
      });
    }
  }

  Future<void> _process(Map<String, dynamic> rec) async {
    setState(() {
      _busy = 'process';
      _error = null;
      _notice = null;
    });
    try {
      final updated = await widget.apiClient.post(
        '/system-audio/recordings/${rec['id']}/process',
        body: {'style': _style},
      );
      if (!mounted) return;
      setState(() {
        _busy = null;
        _selected = updated;
        _notice = 'Transcript and AI summary ready.';
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = _message(e);
      });
    }
  }

  void _select(Map<String, dynamic> rec) {
    setState(() => _selected = rec);
    // The action panel is below the recording list, so on a short window a tap
    // can otherwise look like it did nothing. Bring the panel into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _detailKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    });
  }

  Future<void> _play(Map<String, dynamic> rec) async {
    try {
      if (_playingId == rec['id']) {
        _player.stop();
        setState(() => _playingId = null);
        return;
      }
      final bytes = await widget.apiClient.getBytes('/system-audio/recordings/${rec['id']}/audio?format=mp3');
      final result = _player.load(base64Encode(bytes), 'audio/mpeg');
      if (!result.ok) throw AppException(result.error ?? 'This browser cannot play the MP3.');
      _player.play();
      if (mounted) setState(() => _playingId = rec['id'] as String?);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    }
  }

  Future<bool> _save(Map<String, dynamic> rec, String format) async {
    setState(() {
      _busy = 'save-$format';
      _error = null;
    });
    try {
      final bytes = await widget.apiClient.getBytes(
        '/system-audio/recordings/${rec['id']}/audio?format=$format',
      );
      if (bytes.isEmpty) {
        throw const AppException('The server returned an empty audio file.');
      }
      final label = (rec['label'] as String?)?.trim();
      final stem =
          (label == null || label.isEmpty ? 'penrose-recording' : label).replaceAll(RegExp(r'[^A-Za-z0-9 ._-]'), '-');
      final name = '$stem.${rec['id']}.$format';
      final result = await _player.downloadBytes(
        Uint8List.fromList(bytes),
        name,
        format == 'mp3' ? 'audio/mpeg' : 'audio/wav',
      );
      if (!result.ok) {
        throw AppException(result.message ?? 'The browser refused the download.');
      }
      if (!mounted) return false;
      setState(() {
        _busy = null;
        _notice = 'Saved $name to your downloads.';
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _busy = null;
        _error = _message(e);
      });
      return false;
    }
  }

  String _shareBody(Map<String, dynamic> rec, String? note, bool includeSummary) {
    final label = (rec['label'] as String?)?.trim();
    final buffer = StringBuffer();
    if (note != null && note.trim().isNotEmpty) {
      buffer.writeln(note.trim());
      buffer.writeln();
    }
    buffer.writeln(label == null || label.isEmpty ? 'Penrose ScholarMW recording' : label);
    buffer.writeln(
      'Length ${_clock(((rec['duration_seconds'] as num?) ?? 0).toDouble())} · '
      'recorded ${_date(rec['started_at'])}',
    );
    final summary = (rec['summary'] as String?)?.trim();
    if (includeSummary && summary != null && summary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(summary.length > 1800 ? '${summary.substring(0, 1800)}…' : summary);
    }
    buffer.writeln();
    buffer.writeln('The MP3 was downloaded to this device — attach it to this message.');
    return buffer.toString();
  }

  Future<void> _share(
    Map<String, dynamic> rec, {
    required _ShareTarget target,
  }) async {
    final result = await showDialog<_ShareDetails>(
      context: context,
      builder: (context) => _SharePromptDialog(
        target: target,
        recordingLabel:
            (rec['label'] as String?)?.trim().isNotEmpty == true ? rec['label'] as String : 'this recording',
        hasSummary: (rec['summary'] as String?)?.trim().isNotEmpty == true,
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _busy = 'share-${target.name}';
      _error = null;
      _notice = null;
    });

    try {
      // Browsers cannot attach a local file to wa.me or mailto links, so the
      // MP3 is saved first and the message tells the recipient to attach it.
      final saved = await _save(rec, 'mp3');
      if (!saved || !mounted) return;
      final body = _shareBody(rec, result.note, result.includeSummary);
      final Uri uri;
      if (target == _ShareTarget.whatsapp) {
        final digits = result.address.replaceAll(RegExp(r'[^0-9]'), '');
        uri = Uri.https('wa.me', digits.isEmpty ? '/' : '/$digits', {'text': body});
      } else {
        final subject = (rec['label'] as String?)?.trim();
        uri = Uri(
          scheme: 'mailto',
          path: result.address.trim(),
          queryParameters: {
            'subject': 'Penrose ScholarMW recording — ${subject == null || subject.isEmpty ? 'meeting' : subject}',
            'body': body,
          },
        );
      }
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _busy = null;
        _notice = launched
            ? (target == _ShareTarget.whatsapp
                ? 'WhatsApp opened with the message. Attach the MP3 that was just downloaded.'
                : 'Your email app opened with the message. Attach the MP3 that was just downloaded.')
            : 'The MP3 was downloaded, but the browser blocked opening ${target == _ShareTarget.whatsapp ? 'WhatsApp' : 'your email app'}. '
                'Open it manually and attach the file.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = _message(e);
      });
    }
  }

  Future<void> _delete(Map<String, dynamic> rec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recording?'),
        content: const Text('The WAV, MP3, transcript and summary will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.apiClient.delete('/system-audio/recordings/${rec['id']}');
      if (!mounted) return;
      setState(() {
        if (_selected?['id'] == rec['id']) _selected = null;
        _notice = 'Recording deleted.';
      });
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    }
  }

  String _clock(double seconds) {
    final total = seconds.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  String _size(Object? bytes) {
    final value = (bytes as num?)?.toDouble() ?? 0;
    if (value <= 0) return '—';
    if (value >= 1024 * 1024) return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(value / 1024).toStringAsFixed(0)} KB';
  }

  String _date(Object? iso) {
    final parsed = DateTime.tryParse(iso as String? ?? '');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${local.day} ${months[local.month - 1]} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 40, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Record system audio', style: VtcType.hero(context).copyWith(fontSize: 30)),
                const SizedBox(height: 6),
                Text(
                  'Capture what this computer is playing — a Zoom or Google Meet call, a video, a lecture — '
                  'then transcribe it and let the AI write the notes. Audio is saved as WAV and MP3 on the '
                  'device running the backend.',
                  style: VtcType.body(context),
                ),
                const SizedBox(height: 18),
                _recorderCard(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  VtcErrorStrip(message: _error!),
                ],
                if (_notice != null) ...[
                  const SizedBox(height: 14),
                  VtcNoticeStrip(message: _notice!, onDismiss: () => setState(() => _notice = null)),
                ],
                const SizedBox(height: 22),
                if (_selected != null) ...[
                  KeyedSubtree(key: _detailKey, child: _detailCard(_selected!)),
                  const SizedBox(height: 22),
                ],
                _libraryCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _recorderCard() {
    final busy = _busy != null;
    return GlassPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: VtcSectionHeader(
                  number: '1',
                  icon: Icons.podcasts_rounded,
                  heading: _recording ? 'Recording' : 'Ready to record',
                  description: _recording
                      ? 'Leave this page open; recording continues while you switch tabs.'
                      : 'Start, play the meeting or video, then stop. Both WAV and MP3 are written.',
                ),
              ),
              VtcStatusPill(
                text: _recording ? 'RECORDING' : 'IDLE',
                color: _recording ? VtcPalette.danger : VtcPalette.ivoryDim,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_recording)
            TextField(
              controller: _label,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Label (optional)',
                hintText: 'e.g. Biology staff meeting',
                border: OutlineInputBorder(),
              ),
            ),
          if (_recording) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_clock(_elapsed), style: VtcType.hero(context).copyWith(fontSize: 40)),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_status?['device'] as String? ?? 'System audio', style: VtcType.body(context)),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: RecordingWaveIndicator(size: 20, color: VtcPalette.gold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _level.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: VtcPalette.ivory.withValues(alpha: 0.12),
                color: _level > 0.02 ? VtcPalette.success : VtcPalette.gold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _level > 0.02
                  ? 'Audio detected — the call is being captured.'
                  : 'Silence so far. Check that the meeting is actually playing through the speakers/headphones.',
              style: VtcType.body(context).copyWith(fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (!_recording)
                FilledButton.icon(
                  onPressed: busy ? null : _start,
                  icon: _busy == 'start'
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.fiber_manual_record_rounded),
                  label: const Text('Start recording'),
                )
              else
                FilledButton.icon(
                  style:
                      FilledButton.styleFrom(backgroundColor: VtcPalette.danger, foregroundColor: VtcPalette.midnight),
                  onPressed: busy ? null : _stop,
                  icon: _busy == 'stop'
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.stop_rounded),
                  label: const Text('Stop and save'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _libraryCard() {
    return GlassPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: VtcSectionHeader(
                  number: '2',
                  icon: Icons.library_music_rounded,
                  heading: 'Recordings on this device',
                  description: 'Choose one to transcribe, summarise or download.',
                ),
              ),
              if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          if (!_loading && _recordings.isEmpty)
            Text('No recordings yet.', style: VtcType.body(context))
          else
            for (final rec in _recordings)
              _RecordingRow(
                rec: rec,
                selected: _selected?['id'] == rec['id'],
                playing: _playingId == rec['id'] && _player.playing,
                date: _date(rec['started_at']),
                duration: _clock(((rec['duration_seconds'] as num?) ?? 0).toDouble()),
                subtitle: '${_size(rec['wav_bytes'])} WAV · ${_size(rec['mp3_bytes'])} MP3 · '
                    '${rec['status'] ?? 'ready'}',
                onTap: () => _select(rec),
                onPlay: ((rec['wav_bytes'] as num?) ?? 0) > 0 ? () => _play(rec) : null,
                onDownload: ((rec['wav_bytes'] as num?) ?? 0) > 0 ? () => _save(rec, 'mp3') : null,
                onDelete: _busy == null ? () => _delete(rec) : null,
              ),
        ],
      ),
    );
  }

  Widget _detailCard(Map<String, dynamic> rec) {
    final transcript = (rec['transcript'] as String?)?.trim();
    final summary = (rec['summary'] as String?)?.trim();
    final busy = _busy != null;
    final hasAudio = ((rec['wav_bytes'] as num?) ?? 0) > 0;
    return GlassPanel(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: VtcSectionHeader(
                  number: '3',
                  icon: Icons.auto_awesome_rounded,
                  heading: rec['label'] as String? ?? 'Recording',
                  description: '${_date(rec['started_at'])} · '
                      '${_clock(((rec['duration_seconds'] as num?) ?? 0).toDouble())} · '
                      '${_size(rec['wav_bytes'])} WAV · ${_size(rec['mp3_bytes'])} MP3',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: hasAudio ? () => _play(rec) : null,
                icon: Icon(_playingId == rec['id'] && _player.playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(_playingId == rec['id'] && _player.playing ? 'Stop' : 'Play'),
              ),
              OutlinedButton.icon(
                onPressed: hasAudio ? () => _save(rec, 'wav') : null,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download WAV'),
              ),
              FilledButton.tonalIcon(
                onPressed: hasAudio ? () => _save(rec, 'mp3') : null,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download MP3'),
              ),
              OutlinedButton.icon(
                onPressed: busy || !hasAudio ? null : () => _share(rec, target: _ShareTarget.whatsapp),
                icon: const Icon(Icons.chat_rounded),
                label: const Text('WhatsApp'),
              ),
              OutlinedButton.icon(
                onPressed: busy || !hasAudio ? null : () => _share(rec, target: _ShareTarget.email),
                icon: const Icon(Icons.mail_outline_rounded),
                label: const Text('Email'),
              ),
              FilledButton.icon(
                onPressed: busy || !hasAudio ? null : () => _transcribe(rec),
                icon: _busy == 'transcribe'
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.notes_rounded),
                label: Text(transcript == null ? 'Transcribe' : 'Transcribe again'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: VtcPalette.gold, foregroundColor: VtcPalette.midnight),
                onPressed: busy || !hasAudio ? null : () => _process(rec),
                icon: _busy == 'process'
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(transcript == null ? 'Transcribe + AI notes' : 'AI notes'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _delete(rec),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Summary style', style: VtcType.body(context).copyWith(fontSize: 12.5)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _style,
                dropdownColor: VtcPalette.navyDeep,
                onChanged: busy ? null : (value) => setState(() => _style = value ?? 'minutes'),
                items: [
                  for (final entry in _styles.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
              ),
              if (transcript != null) ...[
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: busy ? null : () => _summarize(rec),
                  icon: _busy == 'summarize'
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Rebuild summary only'),
                ),
              ],
            ],
          ),
          if (transcript != null) ...[
            const SizedBox(height: 16),
            const GoldRule(width: double.infinity),
            const SizedBox(height: 12),
            Text('Transcript', style: VtcType.sectionHeading(context).copyWith(fontSize: 16)),
            const SizedBox(height: 6),
            SelectableText(transcript, style: VtcType.bodyIvory(context)),
          ],
          if (summary != null) ...[
            const SizedBox(height: 18),
            const GoldRule(width: double.infinity),
            const SizedBox(height: 12),
            Text('AI summary', style: VtcType.sectionHeading(context).copyWith(fontSize: 16)),
            const SizedBox(height: 6),
            SelectableText(summary, style: VtcType.bodyIvory(context)),
          ],
          if (transcript == null) ...[
            const SizedBox(height: 14),
            Text(
              'Transcribe to get the words; AI notes then summarise those words. '
              'Transcription uses the configured Whisper model and needs an internet connection.',
              style: VtcType.body(context).copyWith(fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({
    required this.rec,
    required this.selected,
    required this.playing,
    required this.date,
    required this.duration,
    required this.subtitle,
    required this.onTap,
    this.onPlay,
    this.onDownload,
    this.onDelete,
  });

  final Map<String, dynamic> rec;
  final bool selected;
  final bool playing;
  final String date;
  final String duration;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? VtcPalette.royalBlue.withValues(alpha: 0.55) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? VtcPalette.gold : VtcPalette.ivory.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onPlay,
                  tooltip: playing ? 'Stop' : 'Play',
                  icon: Icon(playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  color: playing ? VtcPalette.goldLight : VtcPalette.ivory,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rec['label'] as String? ?? 'Recording', style: VtcType.bodyIvory(context)),
                      const SizedBox(height: 2),
                      Text('$date · $duration · $subtitle', style: VtcType.body(context).copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
                if (rec['transcript'] != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.notes_rounded, size: 16, color: VtcPalette.ivoryDim),
                  ),
                if (rec['summary'] != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.auto_awesome_rounded, size: 16, color: VtcPalette.gold),
                  ),
                IconButton(
                  onPressed: onDownload,
                  tooltip: 'Download MP3',
                  icon: const Icon(Icons.download_rounded, size: 20),
                  color: VtcPalette.ivoryDim,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete recording',
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: VtcPalette.danger,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ShareTarget { whatsapp, email }

class _ShareDetails {
  const _ShareDetails(this.address, this.note, this.includeSummary);

  final String address;
  final String note;
  final bool includeSummary;
}

/// Asks for the recipient's number/address before opening WhatsApp or the
/// device's email app. Browsers cannot attach files to those links, so the
/// dialog explains that the MP3 is downloaded and attached by the sender.
class _SharePromptDialog extends StatefulWidget {
  const _SharePromptDialog({
    required this.target,
    required this.recordingLabel,
    required this.hasSummary,
  });

  final _ShareTarget target;
  final String recordingLabel;
  final bool hasSummary;

  @override
  State<_SharePromptDialog> createState() => _SharePromptDialogState();
}

class _SharePromptDialogState extends State<_SharePromptDialog> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _includeSummary = true;
  String? _error;

  bool get _isWhatsApp => widget.target == _ShareTarget.whatsapp;

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _address.text.trim();
    if (value.isEmpty) {
      setState(
          () => _error = _isWhatsApp ? 'Enter the WhatsApp number with country code.' : 'Enter the email address.');
      return;
    }
    if (_isWhatsApp) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 8) {
        setState(() => _error = 'That number is too short — include the country code, e.g. 265991234567.');
        return;
      }
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      setState(() => _error = 'That does not look like a valid email address.');
      return;
    }
    Navigator.pop(context, _ShareDetails(value, _note.text, _includeSummary && widget.hasSummary));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VtcPalette.navyDeep,
      title: Text(_isWhatsApp ? 'Share to WhatsApp' : 'Share by email'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isWhatsApp
                  ? 'Add the recipient number and an optional note. The MP3 is downloaded first so you can attach it in WhatsApp.'
                  : 'Add the recipient address and an optional note. The MP3 is downloaded first so you can attach it to the email.',
              style: VtcType.body(context).copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _address,
              autofocus: true,
              keyboardType: _isWhatsApp ? TextInputType.phone : TextInputType.emailAddress,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: _isWhatsApp ? 'WhatsApp number' : 'Email address',
                hintText: _isWhatsApp ? '265991234567' : 'name@example.com',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'e.g. Minutes from today\'s biology meeting',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _includeSummary,
              onChanged: widget.hasSummary ? (value) => setState(() => _includeSummary = value ?? true) : null,
              title: Text(
                widget.hasSummary
                    ? 'Include the AI summary in the message'
                    : 'No AI summary yet — transcribe first to include one',
                style: VtcType.body(context).copyWith(fontSize: 12.5),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            Text(
              'Sharing "${widget.recordingLabel}" · the MP3 is saved to your downloads.',
              style: VtcType.body(context).copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: VtcPalette.gold, foregroundColor: VtcPalette.midnight),
          onPressed: _submit,
          child: Text(_isWhatsApp ? 'Open WhatsApp' : 'Open email'),
        ),
      ],
    );
  }
}
