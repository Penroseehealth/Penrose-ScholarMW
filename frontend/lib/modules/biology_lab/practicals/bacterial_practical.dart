/// Interactive practical: *Exploring a bacterial cell*.
///
/// A guided identification walkthrough followed by a short multiple-choice
/// assessment. Scoring logic is pure Dart so it is unit-testable; progress
/// is currently session-local — see the documented integration point at the
/// bottom of this file.
/// Feedback for one answered practical question.
class PracticalFeedback {
  final bool correct;
  final String explanation;

  const PracticalFeedback({required this.correct, required this.explanation});
}

/// One step of the practical: an identification prompt or an MCQ.
class PracticalStep {
  final String prompt;
  final String hint;

  /// For identification steps: the component id the learner must select in
  /// the 3D scene.
  final String? targetComponentId;

  /// For MCQ steps: the answer options (index 0..n-1) and correct index.
  final List<String>? options;
  final int? correctIndex;
  final String explanation;

  const PracticalStep({
    required this.prompt,
    required this.explanation,
    required this.hint,
    this.targetComponentId,
    this.options,
    this.correctIndex,
  });

  bool get isQuestion => correctIndex != null;
}

/// The state machine for the bacterial-cell practical.
///
/// Lifecycle: identification steps (learner clicks structures in the 3D
/// scene) → assessment questions (MCQ with feedback) → completion with
/// score.
class BacterialPracticalState {
  static const List<PracticalStep> steps = [
    PracticalStep(
      prompt: 'Select the cell wall in the 3D model.',
      hint: 'The rigid outermost layer.',
      targetComponentId: 'cell-wall',
      explanation: 'The cell wall is a rigid peptidoglycan layer that maintains the '
          'bacterium’s shape and protects it from osmotic lysis.',
    ),
    PracticalStep(
      prompt: 'Select the nucleoid.',
      hint: 'The coiled yellow region in the middle — it has no membrane.',
      targetComponentId: 'nucleoid',
      explanation: 'The nucleoid holds the circular DNA chromosome. Unlike a eukaryotic '
          'nucleus, it is NOT enclosed by a membrane — bacteria are prokaryotes.',
    ),
    PracticalStep(
      prompt: 'Select the plasmid.',
      hint: 'The small orange ring floating in the cytoplasm.',
      targetComponentId: 'plasmid',
      explanation: 'Plasmids are small rings of extra DNA, often carrying genes such as '
          'antibiotic resistance. They can be shared between bacteria.',
    ),
    PracticalStep(
      prompt: 'Which structure rotates like a motor to make the cell swim?',
      hint: '',
      options: [
        'Pili',
        'Flagellum',
        'Plasmid',
        'Ribosome',
      ],
      correctIndex: 1,
      explanation: 'The flagellum is spun by a basal protein motor, driving the '
          'bacterium forward. Pili are for attachment and DNA transfer.',
    ),
    PracticalStep(
      prompt: 'Why are ribosomes a common target for antibiotics?',
      hint: '',
      options: [
        'They store water',
        'They replicate DNA',
        'They build proteins, and blocking them stops bacterial growth',
        'They make the cell wall',
      ],
      correctIndex: 2,
      explanation: 'Ribosomes (70S in bacteria) synthesise every bacterial protein. '
          'Antibiotics such as tetracycline bind the bacterial ribosome and '
          'stop growth.',
    ),
    PracticalStep(
      prompt: 'Which feature most clearly distinguishes this bacterium from '
          'a human cell?',
      hint: '',
      options: [
        'It has a nucleus',
        'It has no nuclear membrane around its DNA',
        'It has no cell membrane',
        'It has mitochondria',
      ],
      correctIndex: 1,
      explanation: 'Bacteria are prokaryotes: their DNA sits in the nucleoid without a '
          'nuclear membrane. They also lack membrane-bound organelles such as '
          'mitochondria.',
    ),
  ];

  final List<PracticalStep> stepList;
  int index = 0;
  int score = 0;
  int answered = 0;
  final Set<int> answeredCorrectly = {};

  BacterialPracticalState({this.stepList = steps});

  PracticalStep get current => stepList[index];
  bool get isIdentification => current.targetComponentId != null;
  bool get isComplete => index >= stepList.length;
  int get questionCount => stepList.where((s) => s.isQuestion).length;
  double get percentScore => questionCount == 0 ? 0 : (answeredCorrectly.length / questionCount) * 100;

  /// Validates an identification step against the selected component id.
  PracticalFeedback answerIdentification(String? selectedId) {
    final step = current;
    final ok = selectedId == step.targetComponentId;
    return PracticalFeedback(
      correct: ok,
      explanation: ok ? step.explanation : 'Not quite — try again. Hint: ${step.hint}',
    );
  }

  /// Answers the current MCQ step and records the score.
  PracticalFeedback answer(int choiceIndex) {
    final step = current;
    if (step.correctIndex == null) {
      return const PracticalFeedback(correct: false, explanation: '');
    }
    final ok = choiceIndex == step.correctIndex;
    answered++;
    if (ok) {
      score++;
      answeredCorrectly.add(index);
    }
    return PracticalFeedback(
      correct: ok,
      explanation: ok
          ? step.explanation
          : '${step.explanation}\n\nCorrect answer: '
              '${step.options![step.correctIndex!]}',
    );
  }

  void advance() {
    if (index < stepList.length) index++;
  }
}

// ── Documented integration point ────────────────────────────────────────────
//
// Practical progress is session-local here. The backend already exposes
// assessment domains under `backend/app/assessments` and the frontend
// routes `/examinations`; a future iteration can POST the finished
// `BacterialPracticalState` (score, questionCount, assetId) to
// `/api/v1/assessments/...` and display it in the existing analytics.
// No such endpoint is called today — nothing was invented on the wire.
