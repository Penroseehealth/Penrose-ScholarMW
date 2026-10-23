import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/networking/api_client.dart';
import '../../services/api_service.dart';

/// One harvested MANEB MSCE past paper.
@immutable
class MscePaper {
  const MscePaper({
    required this.id,
    required this.title,
    required this.pages,
    required this.verified,
    this.year,
    this.subject,
    this.paper,
    this.subjectCode,
    this.sourceProvider,
    this.sourceUrl,
    this.attribution,
    this.licence,
    this.sha256,
    this.verification = const <String, dynamic>{},
  });

  final String id;
  final String title;
  final int pages;
  final bool verified;
  final int? year;
  final String? subject;
  final int? paper;
  final String? subjectCode;
  final String? sourceProvider;
  final String? sourceUrl;
  final String? attribution;
  final String? licence;
  final String? sha256;
  final Map<String, dynamic> verification;

  /// "Mathematics Paper I" style label.
  String get paperLabel {
    if (paper == 1) return 'Paper I';
    if (paper == 2) return 'Paper II';
    if (paper == 3) return 'Paper III';
    return 'Paper';
  }

  /// The subject number printed by MANEB, e.g. "M022/1".
  String get subjectNumber {
    final code = subjectCode;
    if (code == null || code.isEmpty) return '';
    final suffix = paper == 2 ? 'II' : 'I';
    return 'M$code/$suffix';
  }

  factory MscePaper.fromJson(Map<String, dynamic> json) {
    final rawVerification = json['verification'];
    return MscePaper(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'MSCE paper',
      pages: (json['pages'] as num?)?.toInt() ?? 0,
      verified: json['verified'] as bool? ?? false,
      year: (json['year'] as num?)?.toInt(),
      subject: json['subject'] as String?,
      paper: (json['paper'] as num?)?.toInt(),
      subjectCode: json['subject_code'] as String?,
      sourceProvider: json['source_provider'] as String?,
      sourceUrl: json['source_url'] as String?,
      attribution: json['attribution'] as String?,
      licence: json['licence'] as String?,
      sha256: json['sha256'] as String?,
      verification: rawVerification is Map<String, dynamic> ? rawVerification : const <String, dynamic>{},
    );
  }
}

/// Loads the paper catalogue and applies the on-screen filters.
class MscePapersController extends ChangeNotifier {
  MscePapersController({ApiClient? apiClient}) : _api = apiClient ?? _defaultClient();

  static ApiClient _defaultClient() => ApiClient(baseUrl: apiBaseUrl)..tokenProvider = () => ApiService().accessToken;

  final ApiClient _api;

  List<MscePaper> _all = const <MscePaper>[];
  List<int> _years = const <int>[];
  List<String> _subjects = const <String>[];
  bool _loading = false;
  bool _harvesting = false;
  String? _error;
  int? _year;
  String? _subject;
  int? _paper;

  List<MscePaper> get all => _all;
  List<int> get years => _years;
  List<String> get subjects => _subjects;
  bool get loading => _loading;
  bool get harvesting => _harvesting;
  String? get error => _error;
  int? get selectedYear => _year;
  String? get selectedSubject => _subject;
  int? get selectedPaper => _paper;

  /// The catalogue after the current filters.
  List<MscePaper> get filtered => _all.where((paper) {
        if (_year != null && paper.year != _year) return false;
        if (_subject != null && paper.subject != _subject) return false;
        if (_paper != null && paper.paper != _paper) return false;
        return true;
      }).toList(growable: false);

  /// How many papers each year holds, for the year chips.
  Map<int, int> get countsByYear {
    final counts = <int, int>{};
    for (final paper in _all) {
      final year = paper.year;
      if (year == null) continue;
      counts[year] = (counts[year] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> load({bool refresh = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.get('/msce-papers');
      final raw = response['papers'];
      final items = <MscePaper>[];
      if (raw is List) {
        for (final entry in raw) {
          if (entry is Map<String, dynamic>) {
            items.add(MscePaper.fromJson(entry));
          }
        }
      }
      _all = items;
      final years = response['years'];
      if (years is List) {
        _years = years.whereType<num>().map((value) => value.toInt()).toList();
      }
      final subjects = response['subjects'];
      if (subjects is List) {
        _subjects = subjects.whereType<String>().toList();
      }
      _harvesting = response['available'] != true;
    } on Object catch (error) {
      _error = _describe(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
    if (refresh && _harvesting) {
      await _pollForPapers();
    }
  }

  /// The library is built on the server the first time; wait for it.
  Future<void> _pollForPapers() async {
    for (var attempt = 0; attempt < 40; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 5));
      try {
        final response = await _api.get('/msce-papers/status');
        final count = (response['count'] as num?)?.toInt() ?? 0;
        if (count > 0) {
          await load();
          return;
        }
      } on Object {
        // Keep waiting; the status endpoint is best effort.
      }
    }
  }

  void setYear(int? year) {
    _year = year;
    notifyListeners();
  }

  void setSubject(String? subject) {
    _subject = subject;
    notifyListeners();
  }

  void setPaper(int? paper) {
    _paper = paper;
    notifyListeners();
  }

  void clearFilters() {
    _year = null;
    _subject = null;
    _paper = null;
    notifyListeners();
  }

  static String _describe(Object error) {
    final text = error.toString();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }
}

/// Absolute URL of one rendered page of a paper.
///
/// The API base is relative on the web build, so the page URL is resolved
/// against the current document before it is handed to the image loader.
String mscePageUrl(String paperId, int page, {int dpi = 150}) {
  final path = '$apiBaseUrl/msce-papers/$paperId/page/$page.png?dpi=$dpi';
  final base = Uri.base;
  if (base.scheme.isEmpty) return path;
  return base.resolve(path).toString();
}

/// Pretty-prints the JSON of a paper's verification record.
String msceVerificationJson(MscePaper paper) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(paper.verification);
}
