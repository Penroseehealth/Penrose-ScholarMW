import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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

  /// What the recording captures: system audio, the microphone, or both.
  String _source = 'both';

  /// 0 keeps one file for the whole session; otherwise each part is this many
  /// minutes long (10/15/20/25/30 as offered in the picker).
  int _segmentMinutes = 0;
  bool _micBusy = false;
  String? _playingId;
  String? _playingKey;
  String? _defaultFolder;
  bool _loading = true;

  // Save & share state.
  final TextEditingController _folder = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _emailTo = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _rename = TextEditingController();
  bool _toFolder = false;
  bool _toWhatsapp = false;
  bool _toEmail = false;
  bool _createFolder = true;
  bool _includeSummary = true;
  String _format = 'mp3';
  Map<String, dynamic>? _delivery;

  /// Virtual (browser-captured) video plays in a real `<video>` element; audio
  /// keeps using the existing audio player. Only one video dialog is open at a
  /// time and its controller is disposed as soon as the dialog closes.
  VideoPlayerController? _video;
  String? _videoId;

  /// Target language for the transcript translation, using the AI service that
  /// is already configured for this app.
  String _translateTo = 'en';

  static const Map<String, String> _languages = {
    'en': 'English',
    'sw': 'Swahili',
    'fr': 'French',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'de': 'German',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'zh': 'Chinese',
  };

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
    _loadDeliveryDefaults();
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
    _video?.dispose();
    _label.dispose();
    _folder.dispose();
    _phone.dispose();
    _emailTo.dispose();
    _note.dispose();
    _rename.dispose();
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
        body: {
          'label': _label.text.trim(),
          'sample_rate': 48000,
          'channels': 2,
          'source': _source,
          'segment_seconds': _segmentMinutes * 60,
        },
      );
      if (!mounted) return;
      setState(() {
        _busy = null;
        _status = {...started, 'active': true, 'elapsed_seconds': 0.0, 'level': 0.0};
        _delivery = null;
        _notice = 'Recording ${started['device'] ?? 'system audio'}'
            '${_segmentMinutes == 0 ? '' : ' in $_segmentMinutes-minute parts'}. '
            'Minimise this tab if you like; keep the app open so the backend stays running.';
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
      final duration = _clock((stopped['duration_seconds'] as num?)?.toDouble() ?? 0);
      final silent = stopped['silent'] == true;
      final parts = (stopped['segments'] as List? ?? const []).length;
      final mp3 = _size(stopped['mp3_bytes']);
      setState(() {
        _busy = null;
        _status = {'active': false};
        _selected = stopped;
        _delivery = null;
        _notice = silent
            ? 'Saved $duration as WAV and MP3, but it is completely silent. Nothing was playing and the '
                'microphone heard nothing — pick "System + mic" above, check the volume, and try again.'
            : 'Saved $duration in ${parts > 1 ? '$parts parts' : 'one file'} — compressed to $mp3 of MP3. '
                'Choose where it should go below.';
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

  Future<void> _loadDeliveryDefaults() async {
    try {
      final defaults = await widget.apiClient.get('/system-audio/default-folder');
      final folder = defaults['folder'] as String?;
      if (!mounted || folder == null) return;
      setState(() {
        _defaultFolder = folder;
        if (_folder.text.trim().isEmpty) _folder.text = folder;
      });
    } catch (_) {
      // A missing suggestion is harmless; the user can type a path.
    }
  }

  List<Map<String, dynamic>> _segments(Map<String, dynamic> rec) =>
      (rec['segments'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();

  /// Turn the microphone on or off while system audio keeps recording.
  Future<void> _toggleMic(bool enable) async {
    setState(() {
      _micBusy = true;
      _error = null;
    });
    try {
      final status = await widget.apiClient.post(
        '/system-audio/microphone',
        body: {'enabled': enable},
      );
      if (!mounted) return;
      setState(() {
        _micBusy = false;
        _status = status;
        final micError = status['mic_error'] as String?;
        if (micError != null && micError.isNotEmpty) {
          _error = micError;
        } else {
          _notice =
              enable ? 'Microphone added — system audio never stopped.' : 'Microphone muted; system audio continues.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _micBusy = false;
        _error = _message(e);
      });
    }
  }

  String _fileUrl(Map<String, dynamic> rec, int index, String format) => index > 0
      ? '/system-audio/recordings/${rec['id']}/segments/$index/audio?format=$format'
      : '/system-audio/recordings/${rec['id']}/audio?format=$format';

  Future<void> _playPart(Map<String, dynamic> rec, int index) async {
    final key = '${rec['id']}#$index';
    try {
      if (_playingKey == key && _player.playing) {
        _player.stop();
        setState(() => _playingKey = null);
        return;
      }
      final bytes = await widget.apiClient.getBytes(_fileUrl(rec, index, 'mp3'));
      final result = _player.load(base64Encode(bytes), 'audio/mpeg');
      if (!result.ok) throw AppException(result.error ?? 'This browser cannot play the MP3.');
      _player.play();
      if (mounted) setState(() => _playingKey = key);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    }
  }

  Future<bool> _downloadPart(Map<String, dynamic> rec, int index, String format) async {
    try {
      final bytes = await widget.apiClient.getBytes(_fileUrl(rec, index, format));
      if (bytes.isEmpty) throw const AppException('The server returned an empty audio file.');
      final label = (rec['label'] as String?)?.trim();
      final stem =
          (label == null || label.isEmpty ? 'penrose-recording' : label).replaceAll(RegExp(r'[^A-Za-z0-9 ._-]'), '-');
      final suffix = index > 0 ? '-part${index.toString().padLeft(2, '0')}' : '';
      final name = '$stem$suffix.${rec['id']}.$format';
      final result = await _player.downloadBytes(
        Uint8List.fromList(bytes),
        name,
        format == 'mp3' ? 'audio/mpeg' : 'audio/wav',
      );
      if (!result.ok) throw AppException(result.message ?? 'The browser refused the download.');
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _error = _message(e));
      return false;
    }
  }

  /// WhatsApp and email cannot receive an attachment from a web page, so the
  /// files are downloaded here and the chat/mail window opens ready to attach.
  Future<int> _downloadAll(Map<String, dynamic> rec) async {
    if (_isVirtual(rec)) {
      return await _downloadMedia(rec) ? 1 : 0;
    }
    final parts = _segments(rec);
    final count = parts.isEmpty ? 1 : parts.length;
    var saved = 0;
    for (var i = 1; i <= count; i++) {
      if (await _downloadPart(rec, parts.isEmpty ? 0 : i, _format)) saved++;
    }
    return saved;
  }

  /// Downloads the stored capture exactly as it was recorded (no re-encoding),
  /// so a video keeps its picture and its audio.
  Future<bool> _downloadMedia(Map<String, dynamic> rec) async {
    setState(() {
      _busy = 'download';
      _error = null;
    });
    try {
      final List<int> bytes = await widget.apiClient.getBytes(
        '/system-audio/recordings/${rec['id']}/media?download=true',
      );
      if (bytes.isEmpty) throw const AppException('The server returned an empty file.');
      final label = (rec['label'] as String?)?.trim();
      final stem =
          (label == null || label.isEmpty ? 'virtual-recording' : label).replaceAll(RegExp(r'[^A-Za-z0-9 ._-]'), '-');
      final format = (rec['format'] as String?)?.trim();
      final extension = (format == null || format.isEmpty) ? 'webm' : format;
      final name = '$stem.$extension';
      final result = await _player.downloadBytes(Uint8List.fromList(bytes), name, _mediaMime(rec));
      if (!result.ok) throw AppException(result.message ?? 'The browser refused the download.');
      if (!mounted) return false;
      setState(() => _notice = 'Saved $name to your downloads.');
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _error = _message(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _deliver(Map<String, dynamic> rec) async {
    if (!_toFolder && !_toWhatsapp && !_toEmail) {
      setState(() => _error = 'Tick at least one destination: a folder, WhatsApp or email.');
      return;
    }
    if (_toFolder && _folder.text.trim().isEmpty) {
      setState(() => _error = 'Enter the folder where the files should be saved.');
      return;
    }
    if (_toWhatsapp && _phone.text.trim().isEmpty) {
      setState(() => _error = 'Enter the WhatsApp number, including the country code.');
      return;
    }
    if (_toEmail && _emailTo.text.trim().isEmpty) {
      setState(() => _error = 'Enter the email address.');
      return;
    }
    setState(() {
      _busy = 'deliver';
      _error = null;
      _notice = null;
      _delivery = null;
    });
    try {
      final result = await widget.apiClient.post(
        '/system-audio/recordings/${rec['id']}/deliver',
        body: {
          'folder': _toFolder ? _folder.text.trim() : null,
          'create_folder': _createFolder,
          'whatsapp': _toWhatsapp ? _phone.text.trim() : null,
          'email': _toEmail ? _emailTo.text.trim() : null,
          'formats': [_format],
          'include_summary': _includeSummary,
          'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _busy = null;
        _delivery = result;
      });
      final results = (result['results'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
      final links = results.where((r) => r['status'] == 'action_required' && (r['link'] as String?) != null).toList();
      if (links.isNotEmpty) {
        final saved = await _downloadAll(rec);
        if (!mounted) return;
        for (final entry in links) {
          final launched = await launchUrl(
            Uri.parse(entry['link'] as String),
            mode: LaunchMode.externalApplication,
          );
          if (!launched && mounted) {
            setState(() => _error =
                'The browser blocked opening ${entry['destination'] == 'whatsapp' ? 'WhatsApp' : 'your email app'}. '
                    'Use the link in the result below, then attach the $saved downloaded file(s).');
          }
        }
        if (mounted) {
          setState(() => _notice =
              'The file(s) were prepared ($saved downloaded) for ${links.map((l) => l['destination']).join(' and ')}. '
                  'Attach them in the window that opened.');
        }
      } else {
        final savedFolders = results.where((r) => r['status'] == 'saved').length;
        if (mounted) {
          setState(() => _notice = savedFolders > 0
              ? 'Files saved. Compression is finished, so the sizes shown are final.'
              : 'Delivery finished — check the result below.');
        }
      }
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
    if (_isVirtual(rec) && _hasVideo(rec)) {
      await _openVideo(rec);
      return;
    }
    try {
      if (_playingId == rec['id']) {
        _player.stop();
        setState(() => _playingId = null);
        return;
      }
      final String mime = _isVirtual(rec) ? _mediaMime(rec) : 'audio/mpeg';
      final List<int> bytes = await widget.apiClient.getBytes(
        _isVirtual(rec)
            ? '/system-audio/recordings/${rec['id']}/media'
            : '/system-audio/recordings/${rec['id']}/audio?format=mp3',
      );
      if (bytes.isEmpty) throw const AppException('The server returned an empty file.');
      final result = _player.load(base64Encode(bytes), mime);
      if (!result.ok) throw AppException(result.error ?? 'This browser cannot play ${_formatLabel(rec)}.');
      _player.play();
      if (mounted) setState(() => _playingId = rec['id'] as String?);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    }
  }

  /// Opens the real video that was captured in the browser and streams it from
  /// the backend with HTTP Range support, so seeking works and the file is never
  /// claimed as playable unless the browser can decode it.
  Future<void> _openVideo(Map<String, dynamic> rec) async {
    final id = rec['id'] as String? ?? '';
    if (_video != null) {
      if (_videoId == id && _video!.value.isInitialized) {
        await showDialog<void>(context: context, builder: (context) => _videoDialog(rec));
        return;
      }
      await _disposeVideo();
    }
    final controller = VideoPlayerController.networkUrl(
      widget.apiClient.mediaUri('/system-audio/recordings/$id/media'),
    );
    setState(() {
      _video = controller;
      _videoId = id;
      _error = null;
    });
    try {
      await controller.initialize();
      await controller.play();
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => _videoDialog(rec));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'The video could not be played: ${_message(e)}');
    } finally {
      await _disposeVideo();
    }
  }

  Future<void> _disposeVideo() async {
    final controller = _video;
    if (controller == null) return;
    try {
      await controller.pause();
    } catch (_) {
      // The controller may already be disposed.
    }
    await controller.dispose();
    if (!mounted) return;
    setState(() {
      _video = null;
      _videoId = null;
    });
  }

  Widget _videoDialog(Map<String, dynamic> rec) {
    final controller = _video;
    return AlertDialog(
      backgroundColor: VtcPalette.navyDeep,
      title: Text(rec['label'] as String? ?? 'Recorded video', style: VtcType.bodyIvory(context)),
      content: SizedBox(
        width: 720,
        child: controller == null || !controller.value.isInitialized
            ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            : AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        colors: const VideoProgressColors(
                          playedColor: VtcPalette.gold,
                          bufferedColor: VtcPalette.royalBlue,
                          backgroundColor: Color(0x33000000),
                        ),
                      ),
                    ),
                    Center(
                      child: IconButton(
                        onPressed: () {
                          if (controller.value.isPlaying) {
                            controller.pause();
                          } else {
                            controller.play();
                          }
                          setState(() {});
                        },
                        tooltip: controller.value.isPlaying ? 'Pause' : 'Play',
                        iconSize: 44,
                        color: VtcPalette.ivory,
                        icon: Icon(
                          controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Future<void> _renameRecording(Map<String, dynamic> rec) async {
    _rename.text = (rec['label'] as String?) ?? '';
    final String? label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VtcPalette.navyDeep,
        title: Text('Rename recording', style: VtcType.bodyIvory(context)),
        content: TextField(
          controller: _rename,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, _rename.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;
    setState(() {
      _busy = 'rename';
      _error = null;
    });
    try {
      await widget.apiClient.patch('/system-audio/recordings/${rec['id']}', body: {'label': label});
      if (!mounted) return;
      setState(() => _notice = 'Renamed to "$label".');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Translates the stored transcript with the AI service already configured for
  /// this app. There is no separate translation provider, so nothing new is
  /// invented here; if the backend has no key it reports that instead.
  Future<void> _translate(Map<String, dynamic> rec, String language) async {
    setState(() {
      _busy = 'translate';
      _error = null;
      _notice = null;
    });
    try {
      await widget.apiClient.post(
        '/system-audio/recordings/${rec['id']}/translate',
        body: {'target_language': language},
      );
      if (!mounted) return;
      setState(() => _notice = 'Transcript translated into ${_languages[language] ?? language}.');
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = null);
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

  Future<void> _delete(Map<String, dynamic> rec) async {
    final virtual = _isVirtual(rec);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(virtual ? 'Delete virtual recording?' : 'Delete recording?'),
        content: Text(
          virtual
              ? 'The captured ${_hasVideo(rec) ? 'video and its audio' : 'audio'}, transcript, translation and summary '
                  'will be removed from this device.'
              : 'The WAV, MP3, transcript and summary will be removed from this device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (_playingId == rec['id']) {
        _player.stop();
        _playingId = null;
      }
      if (_videoId == rec['id']) await _disposeVideo();
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

  // -- virtual recordings ----------------------------------------------------

  /// Virtual recordings come from the browser capture page; system recordings
  /// come from this machine's loopback recorder. They share one library but have
  /// different files and players.
  bool _isVirtual(Map<String, dynamic> rec) => (rec['kind'] ?? 'system') == 'virtual';

  bool _hasVideo(Map<String, dynamic> rec) => _isVirtual(rec) && (rec['media_type'] ?? 'audio') == 'video';

  bool _isPlayable(Map<String, dynamic> rec) {
    if (rec['playable'] == false) return false;
    return _storedBytes(rec) > 0;
  }

  int _storedBytes(Map<String, dynamic> rec) =>
      _isVirtual(rec) ? ((rec['size_bytes'] as num?) ?? 0).toInt() : ((rec['wav_bytes'] as num?) ?? 0).toInt();

  String _mediaMime(Map<String, dynamic> rec) {
    final mime = (rec['mime_type'] as String?)?.trim();
    if (mime != null && mime.isNotEmpty) return mime;
    return _hasVideo(rec) ? 'video/webm' : 'audio/webm';
  }

  String _formatLabel(Map<String, dynamic> rec) {
    final format = (rec['format'] as String?)?.trim();
    if (format == null || format.isEmpty) return _isVirtual(rec) ? 'unknown format' : 'WAV / MP3';
    return format.toUpperCase();
  }

  String _kindLabel(Map<String, dynamic> rec) {
    if (!_isVirtual(rec)) return 'System audio';
    return _hasVideo(rec) ? 'Virtual · video' : 'Virtual · audio';
  }

  String _sourcesLabel(Map<String, dynamic> rec) {
    final sources = (rec['sources'] as List? ?? const []).whereType<String>().toList();
    return sources.isEmpty ? '—' : sources.join(', ');
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
          if (!_recording) ...[
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
            const SizedBox(height: 14),
            Text('What to record', style: VtcType.body(context).copyWith(fontSize: 12.5)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'both',
                  icon: Icon(Icons.merge_type_rounded, size: 16),
                  label: Text('System + mic'),
                ),
                ButtonSegment(
                  value: 'system',
                  icon: Icon(Icons.volume_up_rounded, size: 16),
                  label: Text('System audio'),
                ),
                ButtonSegment(value: 'mic', icon: Icon(Icons.mic_rounded, size: 16), label: Text('Microphone')),
              ],
              selected: {_source},
              showSelectedIcon: false,
              onSelectionChanged: busy ? null : (value) => setState(() => _source = value.first),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Split into parts', style: VtcType.body(context).copyWith(fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Text(
                        _segmentMinutes == 0
                            ? 'One file for the whole recording.'
                            : 'A new file starts every $_segmentMinutes minutes and is compressed in the '
                                'background, without interrupting the recording.',
                        style: VtcType.body(context).copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                DropdownButton<int>(
                  value: _segmentMinutes,
                  dropdownColor: VtcPalette.navyDeep,
                  onChanged: busy ? null : (value) => setState(() => _segmentMinutes = value ?? 0),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('One file')),
                    DropdownMenuItem(value: 10, child: Text('10 minutes')),
                    DropdownMenuItem(value: 15, child: Text('15 minutes')),
                    DropdownMenuItem(value: 20, child: Text('20 minutes')),
                    DropdownMenuItem(value: 25, child: Text('25 minutes')),
                    DropdownMenuItem(value: 30, child: Text('30 minutes')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _source == 'system'
                  ? 'Captures only what this computer plays (a Zoom/Meet call, a video). Your own voice is not recorded.'
                  : _source == 'mic'
                      ? 'Captures only the default microphone — your voice and the room.'
                      : 'Captures the call through the speakers and your own voice through the microphone, mixed together.',
              style: VtcType.body(context).copyWith(fontSize: 12),
            ),
          ],
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
                  ? 'Audio detected — capturing now.'
                  : _source == 'mic'
                      ? 'Silence so far. Check that the microphone is not muted and that you are speaking.'
                      : 'Silence so far. Check that the call or video is actually playing through the speakers/headphones.',
              style: VtcType.body(context).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_source != 'mic')
                  FilterChip(
                    selected: _status?['mic_enabled'] == true,
                    onSelected: _micBusy ? null : (value) => _toggleMic(value),
                    avatar: Icon(
                      _status?['mic_enabled'] == true ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _status?['mic_enabled'] == true ? 'Microphone on' : 'Microphone off',
                    ),
                  ),
                _infoPill(
                  Icons.timer_outlined,
                  _segmentMinutes == 0 ? 'One file' : '$_segmentMinutes min parts',
                ),
                _infoPill(
                  Icons.library_music_rounded,
                  '${(_status?['segments_completed'] as num?)?.toInt() ?? 0} part(s) finished',
                ),
                if (((_status?['compressing'] as num?)?.toInt() ?? 0) > 0)
                  _infoPill(Icons.compress_rounded, 'Compressing…'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _source == 'mic'
                  ? 'Recording the microphone.'
                  : 'Tap the microphone chip at any moment: system audio keeps recording and both sources are mixed into the file.',
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

  Widget _infoPill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VtcPalette.ivory.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: VtcPalette.goldLight),
            const SizedBox(width: 6),
            Text(text, style: VtcType.body(context).copyWith(fontSize: 12)),
          ],
        ),
      );

  /// The parts that were written, with their durations and compressed sizes.
  Widget _filesSection(Map<String, dynamic> rec) {
    final parts = _segments(rec);
    final compressing = ((rec['compressing'] as num?)?.toInt() ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Files', style: VtcType.sectionHeading(context).copyWith(fontSize: 15)),
            const SizedBox(width: 10),
            Text(
              parts.isEmpty
                  ? '${_size(rec['wav_bytes'])} WAV · ${_size(rec['mp3_bytes'])} MP3'
                  : '${parts.length} part(s) · ${_size(rec['wav_bytes'])} WAV · ${_size(rec['mp3_bytes'])} MP3',
              style: VtcType.body(context).copyWith(fontSize: 11.5),
            ),
            const SizedBox(width: 10),
            if (compressing)
              Text('Compressing…', style: VtcType.body(context).copyWith(fontSize: 11.5))
            else if (parts.isNotEmpty)
              Text(
                parts.every((part) => part['status'] == 'compressed') ? 'Compressed' : 'Compression issue',
                style: VtcType.body(context).copyWith(
                  fontSize: 11.5,
                  color: parts.every((part) => part['status'] == 'compressed') ? VtcPalette.success : VtcPalette.danger,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (parts.isEmpty)
          Text('One file for the whole recording.', style: VtcType.body(context).copyWith(fontSize: 12))
        else
          for (final part in parts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    'Part ${part['index']}',
                    style: VtcType.bodyIvory(context).copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_clock(((part['duration_seconds'] as num?) ?? 0).toDouble())} · '
                      '${_size(part['wav_bytes'])} WAV · '
                      '${part['status'] == 'compressed' ? _size(part['mp3_bytes']) : (part['status'] ?? 'pending').toString()} MP3',
                      style: VtcType.body(context).copyWith(fontSize: 11.5),
                    ),
                  ),
                  IconButton(
                    tooltip:
                        _playingKey == '${rec['id']}#${part['index']}' && _player.playing ? 'Stop' : 'Play this part',
                    onPressed: () => _playPart(rec, (part['index'] as num).toInt()),
                    icon: Icon(
                      _playingKey == '${rec['id']}#${part['index']}' && _player.playing
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    color: VtcPalette.ivoryDim,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    tooltip: 'Download this part',
                    onPressed: () => _downloadPart(rec, (part['index'] as num).toInt(), _format),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    color: VtcPalette.ivoryDim,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
      ],
    );
  }

  /// Choose one or more destinations, then deliver: a folder on this machine,
  /// WhatsApp and email. Each destination reports its own result.
  Widget _deliverySection(Map<String, dynamic> rec) {
    final busy = _busy != null;
    final results = (_delivery?['results'] as List? ?? const []).whereType<Map<String, dynamic>>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Save & share', style: VtcType.sectionHeading(context).copyWith(fontSize: 15)),
        const SizedBox(height: 4),
        Text(
          'Pick any combination. Files are copied to a folder on this machine; WhatsApp and email open '
          'with the message ready and the files downloaded for attaching.',
          style: VtcType.body(context).copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _toFolder,
          onChanged: busy ? null : (value) => setState(() => _toFolder = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Save to folder', style: VtcType.bodyIvory(context).copyWith(fontSize: 13)),
        ),
        if (_toFolder) ...[
          TextField(
            controller: _folder,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: 'Folder path',
              hintText: _defaultFolder ?? r'C:\Users\You\Music\Penrose recordings',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _createFolder,
            onChanged: busy ? null : (value) => setState(() => _createFolder = value ?? true),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text('Create the folder if it does not exist', style: VtcType.body(context).copyWith(fontSize: 12)),
          ),
        ],
        const SizedBox(height: 4),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _toWhatsapp,
          onChanged: busy ? null : (value) => setState(() => _toWhatsapp = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Share via WhatsApp', style: VtcType.bodyIvory(context).copyWith(fontSize: 13)),
        ),
        if (_toWhatsapp)
          TextField(
            controller: _phone,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp number with country code',
              hintText: '+265 991 123 456',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        const SizedBox(height: 4),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _toEmail,
          onChanged: busy ? null : (value) => setState(() => _toEmail = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Send via email', style: VtcType.bodyIvory(context).copyWith(fontSize: 13)),
        ),
        if (_toEmail)
          TextField(
            controller: _emailTo,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Recipient email',
              hintText: 'name@example.com',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('File format', style: VtcType.body(context).copyWith(fontSize: 12)),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _format,
              dropdownColor: VtcPalette.navyDeep,
              onChanged: busy ? null : (value) => setState(() => _format = value ?? 'mp3'),
              items: const [
                DropdownMenuItem(value: 'mp3', child: Text('MP3 (compressed)')),
                DropdownMenuItem(value: 'wav', child: Text('WAV (original)')),
              ],
            ),
            if ((rec['summary'] as String?)?.trim().isNotEmpty == true) ...[
              const SizedBox(width: 8),
              Flexible(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _includeSummary,
                  onChanged: busy ? null : (value) => setState(() => _includeSummary = value ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('Include AI summary', style: VtcType.body(context).copyWith(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _note,
          enabled: !busy,
          maxLines: 2,
          minLines: 1,
          decoration: const InputDecoration(
            labelText: 'Message (optional)',
            hintText: 'e.g. Minutes from today\'s meeting',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: VtcPalette.gold,
              foregroundColor: VtcPalette.midnight,
            ),
            onPressed: busy ? null : () => _deliver(rec),
            icon: _busy == 'deliver'
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
            label: const Text('Deliver files'),
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final result in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    result['status'] == 'saved'
                        ? Icons.check_circle_rounded
                        : result['status'] == 'action_required'
                            ? Icons.open_in_new_rounded
                            : Icons.error_outline_rounded,
                    size: 18,
                    color: result['status'] == 'saved'
                        ? VtcPalette.success
                        : result['status'] == 'action_required'
                            ? VtcPalette.gold
                            : VtcPalette.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${result['destination']} — ${result['detail']}',
                          style: VtcType.body(context).copyWith(fontSize: 12),
                        ),
                        if ((result['link'] as String?) != null)
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(result['link'] as String),
                              mode: LaunchMode.externalApplication,
                            ),
                            child: Text(
                              result['destination'] == 'whatsapp' ? 'Open WhatsApp again' : 'Open email again',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
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
                  description:
                      'System audio and virtual recordings. Choose one to play, transcribe, translate or download.',
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
                subtitle: _isVirtual(rec)
                    ? '${_kindLabel(rec)} · ${_formatLabel(rec)} · ${_size(rec['size_bytes'])} · '
                        '${_sourcesLabel(rec)}${rec['playable'] == false ? ' · NOT PLAYABLE' : ''}'
                    : '${_size(rec['wav_bytes'])} WAV · ${_size(rec['mp3_bytes'])} MP3 · '
                        '${rec['status'] ?? 'ready'}${rec['silent'] == true ? ' · SILENT' : ''}',
                onTap: () => _select(rec),
                onPlay: _isPlayable(rec) ? () => _play(rec) : null,
                onDownload: _isPlayable(rec) ? () => _downloadAll(rec) : null,
                onDelete: _busy == null ? () => _delete(rec) : null,
              ),
        ],
      ),
    );
  }

  Widget _detailCard(Map<String, dynamic> rec) {
    final transcript = (rec['transcript'] as String?)?.trim();
    final summary = (rec['summary'] as String?)?.trim();
    final translation = (rec['translation'] as String?)?.trim();
    final translationLanguage = (rec['translation_language'] as String?)?.trim();
    final busy = _busy != null;
    final virtual = _isVirtual(rec);
    final hasAudio = _isPlayable(rec);
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
                  description: virtual
                      ? '${_kindLabel(rec)} · ${_formatLabel(rec)} · ${_size(rec['size_bytes'])} · '
                          '${_date(rec['started_at'])} · '
                          '${_clock(((rec['duration_seconds'] as num?) ?? 0).toDouble())}'
                      : '${_date(rec['started_at'])} · '
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
                label: Text(
                  _playingId == rec['id'] && _player.playing
                      ? 'Stop'
                      : (virtual && _hasVideo(rec) ? 'Play video' : 'Play'),
                ),
              ),
              if (virtual)
                OutlinedButton.icon(
                  onPressed: hasAudio && _busy != 'download' ? () => _downloadMedia(rec) : null,
                  icon: _busy == 'download'
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded),
                  label: Text('Download ${_formatLabel(rec)}'),
                )
              else ...[
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
              ],
              OutlinedButton.icon(
                onPressed: busy ? null : () => _renameRecording(rec),
                icon: _busy == 'rename'
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.drive_file_rename_outline_rounded),
                label: const Text('Rename'),
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
          const SizedBox(height: 16),
          if (!virtual) _filesSection(rec),
          if (!virtual) const SizedBox(height: 18),
          if (!virtual) _deliverySection(rec),
          if (virtual)
            Text(
              'This capture is stored as recorded. Use Download to keep the original '
              '${_hasVideo(rec) ? 'video' : 'audio'} file.',
              style: VtcType.body(context).copyWith(fontSize: 11.5),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Summary style', style: VtcType.body(context).copyWith(fontSize: 12.5)),
              DropdownButton<String>(
                value: _style,
                dropdownColor: VtcPalette.navyDeep,
                onChanged: busy ? null : (value) => setState(() => _style = value ?? 'minutes'),
                items: [
                  for (final entry in _styles.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
              ),
              if (transcript != null)
                TextButton.icon(
                  onPressed: busy ? null : () => _summarize(rec),
                  icon: _busy == 'summarize'
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Rebuild summary only'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Translate transcript to', style: VtcType.body(context).copyWith(fontSize: 12.5)),
              DropdownButton<String>(
                value: _translateTo,
                dropdownColor: VtcPalette.navyDeep,
                onChanged: busy ? null : (value) => setState(() => _translateTo = value ?? 'en'),
                items: [
                  for (final entry in _languages.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: busy || transcript == null ? null : () => _translate(rec, _translateTo),
                icon: _busy == 'translate'
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.translate_rounded, size: 18),
                label: Text(transcript == null ? 'Transcribe first' : 'Translate'),
              ),
            ],
          ),
          if (transcript == null) ...[
            const SizedBox(height: 6),
            Text(
              'Translation needs a transcript; it uses the AI service configured for this app.',
              style: VtcType.body(context).copyWith(fontSize: 11.5),
            ),
          ],
          if (transcript != null) ...[
            const SizedBox(height: 16),
            const GoldRule(width: double.infinity),
            const SizedBox(height: 12),
            Text('Transcript', style: VtcType.sectionHeading(context).copyWith(fontSize: 16)),
            const SizedBox(height: 6),
            SelectableText(transcript, style: VtcType.bodyIvory(context)),
          ],
          if (translation != null) ...[
            const SizedBox(height: 18),
            const GoldRule(width: double.infinity),
            const SizedBox(height: 12),
            Text(
              translationLanguage == null
                  ? 'Translation'
                  : 'Translation (${_languages[translationLanguage] ?? translationLanguage})',
              style: VtcType.sectionHeading(context).copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            SelectableText(translation, style: VtcType.bodyIvory(context)),
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
