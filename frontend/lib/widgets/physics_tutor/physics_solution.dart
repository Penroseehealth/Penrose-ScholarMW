/// Structured physics solution shared by the solver canvas, the narration
/// player and the conversational panel.
///
/// Mirrors the JSON contract of the backend visual physics tutor: a problem, a
/// topic, the physical principle, the given and required quantities, an ordered
/// list of renderable and speakable steps, a verified final answer and the
/// optional diagram, simulation and graph payloads.
///
/// Steps reuse [TutorStep] so the physics workspace can share the step-board,
/// typewriter and narration player with the mathematics tutor unchanged.
library;

import '../math_tutor/math_solution.dart';

/// One row of the Given table.
class PhysicsQuantity {
  final String symbol;
  final String latex;
  final Object? quantity;

  const PhysicsQuantity({required this.symbol, required this.latex, this.quantity});

  /// The quantity rendered as plain text for the table and for speech.
  String get display => quantity?.toString() ?? '';

  factory PhysicsQuantity.fromJson(Map<String, dynamic> json) => PhysicsQuantity(
        symbol: (json['symbol'] as String?) ?? '',
        latex: (json['latex'] as String?) ?? '',
        quantity: json['quantity'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'symbol': symbol, 'latex': latex, 'quantity': quantity};
}

/// A complete, verified physics worked solution.
class PhysicsSolution {
  final String problem;
  final String topic;
  final String principle;
  final List<PhysicsQuantity> given;
  final List<String> find;
  final List<TutorStep> steps;
  final String finalAnswerLatex;
  final String finalAnswerText;
  final String verificationStatus;
  final String verificationDetail;
  final List<String> warnings;
  final Map<String, dynamic>? visual;
  final Map<String, dynamic>? simulation;
  final List<Map<String, dynamic>> graphs;

  const PhysicsSolution({
    required this.problem,
    required this.topic,
    required this.steps,
    required this.finalAnswerLatex,
    required this.finalAnswerText,
    this.principle = '',
    this.given = const <PhysicsQuantity>[],
    this.find = const <String>[],
    this.verificationStatus = 'unverified',
    this.verificationDetail = '',
    this.warnings = const <String>[],
    this.visual,
    this.simulation,
    this.graphs = const <Map<String, dynamic>>[],
  });

  int get stepCount => steps.length;

  bool get isVerified => verificationStatus == 'verified';

  bool get isClarification => topic == 'needs_more_information';

  /// LaTeX for the final answer, falling back to the plain answer.
  String get answerLatex => finalAnswerLatex.isNotEmpty ? finalAnswerLatex : finalAnswerText;

  TutorStep stepAt(int index) => steps[index.clamp(0, steps.length - 1)];

  /// Parse the server `/physics/tutor/solve` response.
  factory PhysicsSolution.fromJson(Map<String, dynamic> json) {
    final rawSteps = (json['steps'] as List?) ?? const <dynamic>[];
    final rawGiven = (json['given'] as List?) ?? const <dynamic>[];
    final rawFind = (json['find'] as List?) ?? const <dynamic>[];
    final rawGraphs = (json['graphs'] as List?) ?? const <dynamic>[];
    return PhysicsSolution(
      problem: (json['problem'] as String?) ?? '',
      topic: (json['topic'] as String?) ?? 'physics',
      principle: (json['principle'] as String?) ?? '',
      given: rawGiven.whereType<Map<String, dynamic>>().map(PhysicsQuantity.fromJson).toList(growable: false),
      find: rawFind.map((item) => item.toString()).where((item) => item.isNotEmpty).toList(growable: false),
      steps: rawSteps.whereType<Map<String, dynamic>>().map(TutorStep.fromJson).toList(growable: false),
      finalAnswerText: (json['final_answer_text'] as String?) ?? '',
      finalAnswerLatex: (json['final_answer_latex'] as String?) ?? '',
      verificationStatus: (json['verification_status'] as String?) ?? 'unverified',
      verificationDetail: (json['verification_detail'] as String?) ?? '',
      warnings: ((json['warnings'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      visual: json['visual'] is Map<String, dynamic> ? json['visual'] as Map<String, dynamic> : null,
      simulation: json['simulation'] is Map<String, dynamic> ? json['simulation'] as Map<String, dynamic> : null,
      graphs: rawGraphs.whereType<Map<String, dynamic>>().toList(growable: false),
    );
  }

  /// Adapt to the shared model so the narration player, typewriter and step
  /// board can be reused verbatim from the mathematics tutor.
  TutorSolution toTutorSolution() => TutorSolution(
        problem: problem,
        subject: TutorSubject.physics,
        topic: topic,
        steps: steps,
        finalAnswer: finalAnswerText,
        finalAnswerLatex: finalAnswerLatex,
        verificationStatus: verificationStatus,
        verificationDetail: verificationDetail,
        visualKind: TutorVisualKind.none,
        visualData: visual,
      );

  /// Serialise back into the API contract for the explain endpoint.
  Map<String, dynamic> toExplainJson() => <String, dynamic>{
        'problem': problem,
        'subject': 'physics',
        'topic': topic,
        'principle': principle,
        'final_answer_latex': finalAnswerLatex,
        'final_answer_text': finalAnswerText,
        'verification_status': verificationStatus,
        'verification_detail': verificationDetail,
        'visual': visual,
        'steps': steps
            .map(
              (step) => <String, dynamic>{
                'id': step.id,
                'title': step.title,
                'narration': step.narration,
                'explanation': step.explanation,
                'latex_lines': step.latexLines,
              },
            )
            .toList(),
      };
}
