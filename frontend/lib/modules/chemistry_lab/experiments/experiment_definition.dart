/// Structured definition of a practical experiment.
///
/// Every field is required-or-defaulted so the catalogue can validate
/// completeness in unit tests (`experiment_catalogue_test.dart`):
/// an experiment missing objectives, safety notes or procedure must not be
/// publishable.
///
/// Scientific content ([balancedEquation], [equations], expected
/// observations, assessment answers) is **authored data**, vetted against
/// established chemistry — never generated at runtime. See
/// `docs/INTEGRATION.md` § Accuracy tiers.
class ExperimentDefinition {
  /// Stable machine id (also the JS scene key), e.g. `acid_base_titration`.
  final String id;

  final String title;

  final String summary;

  /// Learning objectives — shown before the learner starts.
  final List<String> objectives;

  /// Equipment list; mirrors the 3D apparatus ids in the scene spec.
  final List<String> apparatus;

  /// Chemicals used, with hazard-relevant descriptions.
  final List<String> substances;

  /// Safety requirements (PPE, handling, disposal). Mandatory.
  final List<String> safetyNotes;

  /// Procedure steps, in order. Each step is one instruction.
  final List<String> procedure;

  /// Expected observation per procedure step index (aligned with [procedure]).
  final List<String> expectedObservations;

  /// The balanced chemical equation, if the experiment is a reaction.
  /// Must parse via `stoichiometry.dart` and be atom-balanced.
  final String? balancedEquation;

  /// Relevant formulas (e.g. `c = n / V`), shown in the equations panel.
  final List<String> equations;

  /// Assessment questions with correct answers for self-checking.
  final List<ExperimentQuestion> questions;

  /// Which accuracy tier each displayed quantity belongs to:
  /// `validated`, `calculated`, `illustrative`.
  final Map<String, String> accuracyNotes;

  const ExperimentDefinition({
    required this.id,
    required this.title,
    required this.summary,
    required this.objectives,
    required this.apparatus,
    required this.substances,
    required this.safetyNotes,
    required this.procedure,
    required this.expectedObservations,
    this.balancedEquation,
    required this.equations,
    required this.questions,
    required this.accuracyNotes,
  });

  /// True when required educational fields are present and step/observation
  /// counts align. Used by tests to gate publication.
  bool get isComplete =>
      id.isNotEmpty &&
      title.isNotEmpty &&
      objectives.isNotEmpty &&
      apparatus.isNotEmpty &&
      substances.isNotEmpty &&
      safetyNotes.isNotEmpty &&
      procedure.isNotEmpty &&
      expectedObservations.length == procedure.length &&
      equations.isNotEmpty &&
      questions.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'summary': summary,
        'objectives': objectives,
        'apparatus': apparatus,
        'substances': substances,
        'safety_notes': safetyNotes,
        'procedure': procedure,
        'expected_observations': expectedObservations,
        'balanced_equation': balancedEquation,
        'equations': equations,
        'questions': questions.map((q) => q.toJson()).toList(),
        'accuracy_notes': accuracyNotes,
      };
}

/// A checkpoint question with its expected answer.
class ExperimentQuestion {
  final String question;

  /// Expected answer (free text, matched case-insensitively by the UI).
  final String answer;

  /// Explanation shown after answering — the chemistry behind it.
  final String explanation;

  const ExperimentQuestion({
    required this.question,
    required this.answer,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'question': question,
        'answer': answer,
        'explanation': explanation,
      };
}
