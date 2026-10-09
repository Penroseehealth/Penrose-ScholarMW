/// Structured solution model shared by the solver, the player and the canvas.
///
/// Mirrors the JSON contract from the tutor specification: a problem, a
/// domain/topic classification, an ordered list of independently renderable
/// and speakable steps, and a final answer.
///
/// The model carries both the deterministic on-device solution and the richer
/// server solution (LaTeX lines, plain-language reasoning, verification and
/// contextual visual data). The server fields are optional so the offline
/// solver can keep producing solutions with no network at all.
library;

enum TutorVisualKind { rightTriangle, parabola, percentageBar, expression, balance, figure, none }

enum TutorSubject { geometry, algebra, arithmetic, percentage, physics, clarification }

/// One narration step: renderable on the canvas, speakable on its own.
class TutorStep {
  final int id;
  final String title;
  final String? equation;

  /// Properly typeset lines for this step. Rendered with flutter_math_fork.
  final List<String> latexLines;

  /// Plain-language "why" behind the step.
  final String explanation;

  final String narration;

  const TutorStep({
    required this.id,
    required this.title,
    required this.narration,
    this.equation,
    this.latexLines = const <String>[],
    this.explanation = '',
  });

  /// The best lines to typeset for this step: LaTeX when available, otherwise
  /// the plain equation so nothing disappears for offline solutions.
  List<String> get displayLines =>
      latexLines.isNotEmpty ? latexLines : <String>[if (equation != null && equation!.isNotEmpty) equation!];

  factory TutorStep.fromJson(Map<String, dynamic> json) => TutorStep(
        id: (json['id'] as num?)?.toInt() ?? 1,
        title: (json['title'] as String?) ?? 'Step',
        narration: (json['narration'] as String?) ?? (json['explanation'] as String?) ?? '',
        explanation: (json['explanation'] as String?) ?? '',
        latexLines: ((json['latex_lines'] as List?) ?? const [])
            .map((line) => line.toString())
            .where((line) => line.isNotEmpty)
            .toList(growable: false),
      );
}

/// Deterministic result for a supported problem.
class TutorSolution {
  final String problem;
  final TutorSubject subject;
  final String topic;
  final List<TutorStep> steps;
  final String finalAnswer;
  final TutorVisualKind visualKind;

  /// Rich, typed final answer for typesetting (LaTeX) and for speech (text).
  final String finalAnswerLatex;

  final String verificationStatus;
  final String verificationDetail;

  /// Contextual visual payload from the server. The `kind` key selects which
  /// deterministic painter to use; null means no picture is warranted.
  final Map<String, dynamic>? visualData;

  // Right-triangle geometry (null for other subjects).
  final double? sideA;
  final double? sideB;
  final double? sideC;
  final String unit;

  const TutorSolution({
    required this.problem,
    required this.subject,
    required this.topic,
    required this.steps,
    required this.finalAnswer,
    required this.visualKind,
    this.finalAnswerLatex = '',
    this.verificationStatus = 'unverified',
    this.verificationDetail = '',
    this.visualData,
    this.sideA,
    this.sideB,
    this.sideC,
    this.unit = 'units',
  });

  int get stepCount => steps.length;

  bool get isVerified => verificationStatus == 'verified';

  bool get isClarification => subject == TutorSubject.clarification;

  TutorStep stepAt(int index) => steps[index.clamp(0, steps.length - 1)];

  /// LaTeX for the final answer, falling back to the plain answer.
  String get answerLatex => finalAnswerLatex.isNotEmpty ? finalAnswerLatex : finalAnswer;

  /// Steps 3..7 of the worked example are the algebra itself, which the
  /// canvas uses to decide what to highlight.
  int get algebraStartStep => switch (subject) {
        TutorSubject.geometry => 2,
        TutorSubject.algebra => 0,
        _ => 1,
      };

  static TutorSubject subjectFromName(String name) => switch (name) {
        'geometry' => TutorSubject.geometry,
        'algebra' => TutorSubject.algebra,
        'arithmetic' => TutorSubject.arithmetic,
        'percentage' => TutorSubject.percentage,
        'physics' => TutorSubject.physics,
        'clarification' => TutorSubject.clarification,
        _ => TutorSubject.clarification,
      };

  static TutorVisualKind visualKindFromData(Map<String, dynamic>? data) {
    final kind = data?['kind']?.toString();
    return switch (kind) {
      'right_triangle' => TutorVisualKind.rightTriangle,
      'parabola' => TutorVisualKind.parabola,
      'percentage_bar' => TutorVisualKind.percentageBar,
      'expression' => TutorVisualKind.expression,
      'figure' => TutorVisualKind.figure,
      _ => TutorVisualKind.none,
    };
  }

  /// Parse the server `/solve` response into the shared model.
  factory TutorSolution.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List?) ?? const [];
    final visual = json['visual'] is Map<String, dynamic> ? json['visual'] as Map<String, dynamic> : null;
    final params = visual?['params'] is Map<String, dynamic> ? visual!['params'] as Map<String, dynamic> : null;
    double? param(String key) => (params?[key] as num?)?.toDouble();
    return TutorSolution(
      problem: (json['problem'] as String?) ?? '',
      subject: subjectFromName((json['subject'] as String?) ?? ''),
      topic: (json['topic'] as String?) ?? 'mathematics',
      steps: rawSteps.whereType<Map<String, dynamic>>().map(TutorStep.fromJson).toList(growable: false),
      finalAnswer: (json['final_answer_text'] as String?) ?? '',
      finalAnswerLatex: (json['final_answer_latex'] as String?) ?? '',
      verificationStatus: (json['verification_status'] as String?) ?? 'unverified',
      verificationDetail: (json['verification_detail'] as String?) ?? '',
      visualData: visual,
      visualKind: visualKindFromData(visual),
      sideA: param('a'),
      sideB: param('b'),
      sideC: param('c'),
      unit: (params?['unit'] as String?) ?? 'units',
    );
  }
}
