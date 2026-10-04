import 'geometry_scene.dart';

/// The physical instruments a teacher reaches for while demonstrating.
enum MathInstrument { none, ruler, protractor, pencil, compass, eraser, setSquare, divider }

/// One beat of the construction: what the teacher is doing, why, and which tool
/// they are holding. Beats are ordered and each may complete a scene object.
class GeometryBeat {
  const GeometryBeat({
    required this.title,
    required this.why,
    required this.instrument,
    required this.focus,
    this.draws,
  });

  final String title;
  final String why;
  final MathInstrument instrument;

  /// Scene object the teacher is working on during this beat.
  final String focus;

  /// Scene object finished by this beat, if any.
  final String? draws;
}

/// A chronological teaching sequence derived from a scene.
///
/// The lesson is a pure function of the verified geometry, so the animation can
/// never disagree with the maths, and it can be replayed offline.
class GeometryLesson {
  const GeometryLesson({required this.scene, required this.beats});

  final GeometryScene scene;
  final List<GeometryBeat> beats;

  int get length => beats.length;

  GeometryBeat beatAt(int index) => beats[index.clamp(0, beats.length - 1)];

  /// Maps the solution's step counter onto a construction beat, so the board
  /// advances in lock-step with the spoken steps.
  int beatIndexFor(int stepIndex, int stepCount) {
    if (beats.length <= 1 || stepCount <= 1) return 0;
    final double t = (stepIndex / (stepCount - 1)).clamp(0.0, 1.0);
    return (t * (beats.length - 1)).round();
  }

  /// Beat that finishes [objectId], or null when it is drawn implicitly.
  int? drawBeatOf(String objectId) {
    for (int i = 0; i < beats.length; i++) {
      if (beats[i].draws == objectId) return i;
    }
    return null;
  }

  /// Beat during which the temporary guide is rubbed out.
  int? get eraseGuideBeat {
    for (int i = 0; i < beats.length; i++) {
      if (beats[i].instrument == MathInstrument.eraser) return i;
    }
    return null;
  }

  static const List<GeometryBeat> _rightTriangleBeats = <GeometryBeat>[
    GeometryBeat(
      title: 'Reach for the ruler',
      why: 'Every construction starts with a straight edge.',
      instrument: MathInstrument.ruler,
      focus: 'side-a',
    ),
    GeometryBeat(
      title: 'Rule the base AB',
      why: 'A ruler keeps the base perfectly straight.',
      instrument: MathInstrument.pencil,
      focus: 'side-a',
      draws: 'side-a',
    ),
    GeometryBeat(
      title: 'Set the right angle',
      why: 'The protractor confirms the 90 degree corner.',
      instrument: MathInstrument.protractor,
      focus: 'right-angle',
      draws: 'right-angle',
    ),
    GeometryBeat(
      title: 'Rule the upright leg',
      why: 'A right triangle has two perpendicular legs.',
      instrument: MathInstrument.pencil,
      focus: 'side-b',
      draws: 'side-b',
    ),
    GeometryBeat(
      title: 'Join the free ends',
      why: 'The hypotenuse closes the triangle.',
      instrument: MathInstrument.pencil,
      focus: 'side-c',
      draws: 'side-c',
    ),
    GeometryBeat(
      title: 'Rub out the guide',
      why: 'A construction guide comes away once it has done its job.',
      instrument: MathInstrument.eraser,
      focus: 'guide-base',
    ),
    GeometryBeat(
      title: 'Highlight the hypotenuse',
      why: 'The unknown side lies opposite the right angle.',
      instrument: MathInstrument.none,
      focus: 'side-c',
    ),
  ];

  factory GeometryLesson.rightTriangle(GeometryScene scene) => GeometryLesson(scene: scene, beats: _rightTriangleBeats);
}
