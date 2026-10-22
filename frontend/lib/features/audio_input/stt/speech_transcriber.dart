import '../../../core/errors/app_exception.dart';
import '../../../core/networking/api_client.dart';

/// What the backend heard in a recording.
class Transcription {
  const Transcription({required this.transcript, this.provider, this.model});

  /// The recognised text.
  ///
  /// Empty is a real outcome rather than a failure: Whisper returns nothing for
  /// silence and background noise, and callers have to be able to say so instead
  /// of sending an empty turn onwards.
  final String transcript;
  final String? provider;
  final String? model;
}

/// The backend has no speech-to-text provider configured.
///
/// Kept distinct from a failed transcription so the app can report what is
/// actually wrong instead of implying the audio was the problem.
class TranscriptionNotConfigured implements Exception {
  TranscriptionNotConfigured(this.detail);

  /// What the backend said, verbatim.
  final String detail;

  /// One wording for every surface. The training centre and the conversation
  /// used to phrase this differently, which made the same misconfiguration look
  /// like two different problems.
  String get message => 'Speech-to-text is not configured on the server ($detail).';
}

/// Sends recorded audio to `/speech/transcribe`.
///
/// This is the only place that knows how a recording is named on the wire and
/// how the reply is read back. It exists because those details were open-coded at
/// four call sites, which is how a request ended up declaring `recording.webm`
/// while carrying `audio/wav` bytes: the naming drifted where it was duplicated
/// and stayed correct only where someone remembered to derive it.
class SpeechTranscriber {
  const SpeechTranscriber(this._api);

  final ApiClient _api;

  /// Transcribes [bytes], which must be encoded as [mimeType].
  ///
  /// [filename] defaults to one derived from [mimeType]. Pass it only when the
  /// bytes came from a file that already has a real name.
  Future<Transcription> transcribe({required List<int> bytes, required String mimeType, String? filename}) async {
    try {
      final res = await _api.postMultipart(
        '/speech/transcribe',
        files: [
          MultipartFilePart(
            name: 'file',
            filename: filename ?? 'audio.${extensionFor(mimeType)}',
            bytes: bytes,
            contentType: mimeType,
          ),
        ],
      );
      return Transcription(
        transcript: ((res['transcript'] as String?) ?? '').trim(),
        provider: res['provider'] as String?,
        model: res['model'] as String?,
      );
    } on ApiException catch (e) {
      if (e.status == 503) {
        throw TranscriptionNotConfigured(e.message);
      }
      rethrow;
    }
  }

  /// The file extension that matches [mime].
  ///
  /// Derived rather than hardcoded so a request never misdescribes its own
  /// payload. The browser recorder asks for `audio/webm`, but this app re-wraps
  /// finished captures as `audio/wav`, so a literal `.webm` name would ship WAV
  /// bytes under a WebM filename.
  static String extensionFor(String mime) {
    // Parameters such as `; codecs=opus` are dropped first, the same way the
    // backend normalises the content type, so both ends agree on the extension.
    final bare = mime.split(';').first.trim().toLowerCase();
    switch (bare.split('/').last) {
      case 'wav':
      case 'x-wav':
      case 'wave':
        return 'wav';
      case 'mpeg':
        return 'mp3';
      case 'mp4':
        return 'm4a';
      case 'ogg':
        return 'ogg';
      case 'flac':
        return 'flac';
      default:
        return 'webm';
    }
  }

  /// The mime type implied by a file [name]'s extension.
  static String mimeForFilename(String name) {
    switch (name.split('.').last.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/webm';
    }
  }
}
