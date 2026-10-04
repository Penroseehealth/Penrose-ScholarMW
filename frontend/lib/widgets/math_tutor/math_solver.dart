import 'dart:math' as math;

import 'math_solution.dart';

/// Deterministic, offline maths engine for the tutor.
///
/// Every number that appears in a step is computed here rather than by a
/// language model, so the worked solution and the verification step can never
/// disagree. Supported today: Pythagoras, linear equations, percentages and
/// plain arithmetic (with precedence, powers and brackets).
class TutorSolver {
  /// Returns a solution, or null when the input is not recognised.
  ///
  /// Ambiguous right-triangle questions are *not* rejected: they come back as a
  /// clarification solution so the tutor can ask instead of inventing values.
  static TutorSolution? solve(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed
        .toLowerCase()
        .replaceAll('\u2212', '-')
        .replaceAll('\u00d7', '*')
        .replaceAll('\u00f7', '/')
        .replaceAll('\u00b2', '^2');

    return _solvePythagoras(trimmed, lower) ??
        _solveLinearEquation(trimmed, lower) ??
        _solvePercentage(trimmed, lower) ??
        _solveArithmetic(trimmed);
  }

  // ---------------------------------------------------------------------
  // Pythagoras
  // ---------------------------------------------------------------------

  static TutorSolution? _solvePythagoras(String original, String lower) {
    if (!lower.contains('triangle') && !lower.contains('pythagor')) return null;
    final numbers = _numbersIn(lower);
    final unit = _unitIn(lower);

    // A hypotenuse that is *given* ("hypotenuse of 10 cm") is not the unknown,
    // so only treat it as the target when the question never states its length.
    final statedHypotenuse = RegExp(r'hypotenuse[^0-9]{0,12}(\d+(?:\.\d+)?)').firstMatch(lower)?.group(1);
    final wantsHypotenuse =
        (lower.contains('hypotenuse') || lower.contains('longest side')) && statedHypotenuse == null;

    if (numbers.length < 2) {
      return _clarification(
        original,
        'I can solve this, but I need one more detail. '
        'A right-angled triangle needs two known side lengths before I can '
        'work out the third one. What are the two sides you were given?',
      );
    }

    final first = numbers[0];
    final second = numbers[1];
    final steps = <TutorStep>[];

    if (wantsHypotenuse) {
      final squaredA = first * first;
      final squaredB = second * second;
      final total = squaredA + squaredB;
      final hypotenuse = math.sqrt(total);

      steps.add(TutorStep(
        id: 1,
        title: 'Identify the triangle',
        narration: 'We have a right-angled triangle with one side '
            '${_say(first)} $unit and the other side ${_say(second)} $unit. '
            'We need the hypotenuse, which is the longest side, the one '
            'opposite the right angle.',
      ));
      steps.add(const TutorStep(
        id: 2,
        title: 'Apply the Pythagorean theorem',
        equation: 'a\u00b2 + b\u00b2 = c\u00b2',
        narration: 'For any right-angled triangle, the square of the '
            'hypotenuse equals the sum of the squares of the other two sides.',
      ));
      steps.add(TutorStep(
        id: 3,
        title: 'Substitute the known sides',
        equation: '${_fmt(first)}\u00b2 + ${_fmt(second)}\u00b2 = c\u00b2',
        narration: 'Now substitute the side lengths we were given.',
      ));
      steps.add(TutorStep(
        id: 4,
        title: 'Square each length',
        equation: '${_fmt(squaredA)} + ${_fmt(squaredB)} = c\u00b2',
        narration: '${_say(first)} squared is ${_say(squaredA)}, and '
            '${_say(second)} squared is ${_say(squaredB)}.',
      ));
      steps.add(TutorStep(
        id: 5,
        title: 'Add the two squares',
        equation: '${_fmt(squaredA)} + ${_fmt(squaredB)} = ${_fmt(total)}',
        narration: 'Adding those gives ${_say(squaredA)} plus ${_say(squaredB)}, '
            'which is ${_say(total)}.',
      ));
      steps.add(TutorStep(
        id: 6,
        title: 'So c\u00b2 equals the total',
        equation: '${_fmt(total)} = c\u00b2',
        narration: 'That means c squared is ${_say(total)}.',
      ));
      steps.add(TutorStep(
        id: 7,
        title: 'Take the square root',
        equation: 'c = \u221a${_fmt(total)}',
        narration: 'To undo the square, we take the square root of both sides.',
      ));
      steps.add(TutorStep(
        id: 8,
        title: 'State the answer',
        equation: 'c = ${_fmt(hypotenuse)} $unit',
        narration: 'The square root of ${_say(total)} is ${_say(hypotenuse)}, '
            'so the hypotenuse is ${_say(hypotenuse)} $unit.',
      ));
      steps.add(TutorStep(
        id: 9,
        title: 'Check the answer',
        equation: '${_fmt(first)}\u00b2 + ${_fmt(second)}\u00b2 = '
            '${_fmt(hypotenuse)}\u00b2',
        narration: 'Let us verify. ${_say(first)} squared plus ${_say(second)} '
            'squared is ${_say(total)}, and ${_say(hypotenuse)} squared is also '
            '${_say(hypotenuse * hypotenuse)}. They match, so the answer is correct.',
      ));

      return TutorSolution(
        problem: original,
        subject: TutorSubject.geometry,
        topic: 'pythagorean_theorem',
        steps: steps,
        finalAnswer: '${_fmt(hypotenuse)} $unit',
        visualKind: TutorVisualKind.rightTriangle,
        sideA: first,
        sideB: second,
        sideC: hypotenuse,
        unit: unit,
      );
    }

    // Missing leg: the largest known side is the hypotenuse.
    final double larger;
    final double smaller;
    if (statedHypotenuse != null) {
      final hypotenuse = double.parse(statedHypotenuse);
      final known = numbers.where((n) => n != hypotenuse).toList();
      if (known.isEmpty) {
        return _clarification(
            original, 'I have the hypotenuse, but I still need the length of one of the shorter sides.');
      }
      larger = hypotenuse;
      smaller = known.first;
    } else {
      larger = math.max(first, second);
      smaller = math.min(first, second);
    }
    if (larger <= smaller) {
      return _clarification(
        original,
        'I need to know which side is the hypotenuse before I can find the '
        'missing side. Which of the two lengths is the longest?',
      );
    }
    final squaredC = larger * larger;
    final squaredA = smaller * smaller;
    final difference = squaredC - squaredA;
    final missing = math.sqrt(difference);

    steps.add(TutorStep(
      id: 1,
      title: 'Identify the triangle',
      narration: 'This is a right-angled triangle. We know the hypotenuse is '
          '${_say(larger)} $unit and one shorter side is ${_say(smaller)} $unit. '
          'We need the other shorter side.',
    ));
    steps.add(const TutorStep(
      id: 2,
      title: 'Apply the Pythagorean theorem',
      equation: 'a\u00b2 + b\u00b2 = c\u00b2',
      narration: 'Again we use the Pythagorean theorem, where c is the hypotenuse.',
    ));
    steps.add(TutorStep(
      id: 3,
      title: 'Substitute the known sides',
      equation: '${_fmt(smaller)}\u00b2 + b\u00b2 = ${_fmt(larger)}\u00b2',
      narration: 'Substituting the values we know gives this equation.',
    ));
    steps.add(TutorStep(
      id: 4,
      title: 'Square the lengths',
      equation: '${_fmt(squaredA)} + b\u00b2 = ${_fmt(squaredC)}',
      narration: '${_say(smaller)} squared is ${_say(squaredA)} and '
          '${_say(larger)} squared is ${_say(squaredC)}.',
    ));
    steps.add(TutorStep(
      id: 5,
      title: 'Isolate b\u00b2',
      equation: 'b\u00b2 = ${_fmt(squaredC)} - ${_fmt(squaredA)}',
      narration: 'Subtract ${_say(squaredA)} from both sides to leave b squared '
          'on its own.',
    ));
    steps.add(TutorStep(
      id: 6,
      title: 'Subtract',
      equation: 'b\u00b2 = ${_fmt(difference)}',
      narration: '${_say(squaredC)} minus ${_say(squaredA)} is ${_say(difference)}.',
    ));
    steps.add(TutorStep(
      id: 7,
      title: 'Take the square root',
      equation: 'b = \u221a${_fmt(difference)}',
      narration: 'Taking the square root undoes the squaring.',
    ));
    steps.add(TutorStep(
      id: 8,
      title: 'State the answer',
      equation: 'b = ${_fmt(missing)} $unit',
      narration: 'The missing side is ${_say(missing)} $unit.',
    ));
    steps.add(TutorStep(
      id: 9,
      title: 'Check the answer',
      equation: '${_fmt(smaller)}\u00b2 + ${_fmt(missing)}\u00b2 = ${_fmt(larger)}\u00b2',
      narration: 'To check, ${_say(smaller)} squared plus ${_say(missing)} '
          'squared is ${_say(smaller * smaller + missing * missing)}, and '
          '${_say(larger)} squared is ${_say(squaredC)}. They match.',
    ));

    return TutorSolution(
      problem: original,
      subject: TutorSubject.geometry,
      topic: 'pythagorean_theorem',
      steps: steps,
      finalAnswer: '${_fmt(missing)} $unit',
      visualKind: TutorVisualKind.rightTriangle,
      sideA: smaller,
      sideB: missing,
      sideC: larger,
      unit: unit,
    );
  }

  // ---------------------------------------------------------------------
  // Linear equations
  // ---------------------------------------------------------------------

  static TutorSolution? _solveLinearEquation(String original, String lower) {
    final match = RegExp(
      r'(-?\d+(?:\.\d+)?)?\s*([a-z])\s*([+-])\s*(-?\d+(?:\.\d+)?)?\s*=\s*(-?\d+(?:\.\d+)?)',
    ).firstMatch(lower);
    if (match == null) return null;

    final coefficient = double.tryParse(match.group(1) ?? '') ?? 1;
    final variable = match.group(2) ?? 'x';
    final sign = match.group(3) == '-' ? -1.0 : 1.0;
    final constant = (double.tryParse(match.group(4) ?? '') ?? 0) * sign;
    final right = double.tryParse(match.group(5) ?? '') ?? 0;

    if (coefficient == 0) {
      return _clarification(
        original,
        'The number in front of $variable is zero, so this equation does not '
        'describe a single value of $variable. Could you check the question?',
      );
    }

    final afterMove = right - constant;
    final answer = afterMove / coefficient;
    final hasConstant = match.group(4) != null;
    final steps = <TutorStep>[];

    steps.add(TutorStep(
      id: 1,
      title: 'Write down the equation',
      equation: _linearEquationText(coefficient, variable, constant, right),
      narration: 'We need to solve for $variable in '
          '${_sayNumber(coefficient)} $variable '
          '${hasConstant ? '${constant >= 0 ? 'plus' : 'minus'} ${_say(constant.abs())} ' : ''}'
          'equals ${_say(right)}.',
    ));

    if (hasConstant) {
      steps.add(TutorStep(
        id: 2,
        title: 'Move the constant',
        equation: '${_linearTerm(coefficient, variable)} = ${_fmt(afterMove)}',
        narration: '${constant >= 0 ? 'Subtract' : 'Add'} '
            '${_say(constant.abs())} ${constant >= 0 ? 'from' : 'to'} both '
            'sides so the $variable term is on its own.',
      ));
    }

    if (coefficient != 1) {
      steps.add(TutorStep(
        id: steps.length + 1,
        title: 'Divide by the coefficient',
        equation: '$variable = ${_fmt(answer)}',
        narration: 'Now divide both sides by ${_say(coefficient)} to isolate $variable.',
      ));
    } else {
      steps.add(TutorStep(
        id: steps.length + 1,
        title: 'Isolate the variable',
        equation: '$variable = ${_fmt(answer)}',
        narration: 'That already leaves $variable on its own.',
      ));
    }

    final check = coefficient * answer + constant;
    steps.add(TutorStep(
      id: steps.length + 1,
      title: 'State the answer',
      equation: '$variable = ${_fmt(answer)}',
      narration: 'So $variable equals ${_say(answer)}.',
    ));
    steps.add(TutorStep(
      id: steps.length + 1,
      title: 'Check the answer',
      equation: '${_sayNumber(coefficient)}(${_fmt(answer)}) '
          '${constant >= 0 ? '+' : '-'} ${_fmt(constant.abs())} = ${_fmt(right)}',
      narration: 'Substituting back, we get ${_say(check)}, which matches the '
          'right-hand side of the original equation. The answer is correct.',
    ));

    return TutorSolution(
      problem: original,
      subject: TutorSubject.algebra,
      topic: 'linear_equation',
      steps: steps,
      finalAnswer: '$variable = ${_fmt(answer)}',
      visualKind: TutorVisualKind.balance,
    );
  }

  // ---------------------------------------------------------------------
  // Percentages
  // ---------------------------------------------------------------------

  static TutorSolution? _solvePercentage(String original, String lower) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*%\s*of\s*(\d+(?:\.\d+)?)').firstMatch(lower);
    if (match == null) return null;

    final percent = double.parse(match.group(1)!);
    final whole = double.parse(match.group(2)!);
    final decimal = percent / 100;
    final answer = whole * decimal;

    return TutorSolution(
      problem: original,
      subject: TutorSubject.percentage,
      topic: 'percentage_of_quantity',
      steps: <TutorStep>[
        TutorStep(
          id: 1,
          title: 'Identify the parts',
          narration: 'We want $_say(percent) per cent of $_say(whole).',
        ),
        TutorStep(
          id: 2,
          title: 'Convert the percentage',
          equation: '${_fmt(percent)}% = ${_fmt(decimal)}',
          narration: 'To convert a percentage to a decimal, divide by one hundred, '
              'so $_say(percent) per cent becomes ${_say(decimal)}.',
        ),
        TutorStep(
          id: 3,
          title: 'Multiply',
          equation: '${_fmt(decimal)} \u00d7 ${_fmt(whole)} = ${_fmt(answer)}',
          narration: 'Now multiply $_say(decimal) by $_say(whole).',
        ),
        TutorStep(
          id: 4,
          title: 'State the answer',
          equation: _fmt(answer),
          narration: 'So $_say(percent) per cent of $_say(whole) is '
              '${_say(answer)}.',
        ),
        TutorStep(
          id: 5,
          title: 'Check the answer',
          narration: 'As a check, $_say(answer) divided by $_say(whole) is '
              '${_say(answer / whole)}, which is the same as ${_fmt(decimal)}.',
        ),
      ],
      finalAnswer: _fmt(answer),
      visualKind: TutorVisualKind.expression,
    );
  }

  // ---------------------------------------------------------------------
  // Arithmetic
  // ---------------------------------------------------------------------

  static TutorSolution? _solveArithmetic(String original) {
    final expression = _arithmeticExpression(original);
    if (expression == null) return null;

    final parsed = _ArithmeticParser(expression);
    final List<_Operation> operations;
    try {
      operations = parsed.parseOperations();
    } on FormatException {
      return null;
    }
    if (operations.isEmpty) return null;

    final total = operations.last.value;
    final steps = <TutorStep>[
      TutorStep(
        id: 1,
        title: 'Write out the calculation',
        equation: operations.first.renderedBefore,
        narration: 'Let us evaluate this step by step, following the order of '
            'operations.',
      ),
    ];

    for (var i = 0; i < operations.length; i++) {
      final operation = operations[i];
      final isLast = i == operations.length - 1;
      steps.add(TutorStep(
        id: i + 2,
        title: isLast
            ? 'Read the result'
            : 'Simplify ${operation.leftText} '
                '${_symbolName(operation.operator)} ${operation.rightText}',
        equation: operation.renderedAfter,
        narration: '${operation.leftSpoken} ${_symbolName(operation.operator)} '
            '${operation.rightSpoken} gives ${operation.valueSpoken}.',
      ));
    }

    return TutorSolution(
      problem: original,
      subject: TutorSubject.arithmetic,
      topic: 'arithmetic',
      steps: steps,
      finalAnswer: _fmt(total),
      visualKind: TutorVisualKind.expression,
    );
  }

  /// Pulls a bare arithmetic expression out of a sentence.
  static String? _arithmeticExpression(String input) {
    final match = RegExp(
      r'[0-9][0-9\s\.\+\-\*/^()\u00d7\u00f7x\u2212]*[0-9)]',
    ).firstMatch(input);
    if (match == null) return null;
    final text = match.group(0)!.trim();
    if (!RegExp(r'[+\-*/^]').hasMatch(text)) return null;
    return text.replaceAll(' ', '');
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static TutorSolution _clarification(String original, String question) => TutorSolution(
        problem: original,
        subject: TutorSubject.clarification,
        topic: 'needs_more_information',
        steps: <TutorStep>[
          TutorStep(id: 1, title: 'I need one more detail', narration: question),
        ],
        finalAnswer: '',
        visualKind: TutorVisualKind.none,
      );

  static List<double> _numbersIn(String lower) {
    final matches = RegExp(r'\d+(?:\.\d+)?').allMatches(lower);
    return matches.map((m) => double.parse(m.group(0)!)).toList();
  }

  static String _unitIn(String lower) {
    if (lower.contains('km')) return 'kilometres';
    if (lower.contains('cm')) return 'centimetres';
    if (lower.contains('mm')) return 'millimetres';
    if (RegExp(r'\bm\b').hasMatch(lower)) return 'metres';
    if (lower.contains('inch')) return 'inches';
    if (lower.contains('feet') || lower.contains(' ft')) return 'feet';
    return 'units';
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    final rounded = (value * 1000).round() / 1000;
    return rounded.toString();
  }

  /// Compact numeric form used inside equations.
  static String _sayNumber(double value) => _fmt(value);

  /// Spoken form: "3", "4.5", "one over two" style is not attempted, but
  /// fractions such as 0.5 are read naturally enough for narration.
  static String _say(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  static String _symbolName(String symbol) => switch (symbol) {
        '+' => 'plus',
        '-' => 'minus',
        '*' => 'multiplied by',
        '/' => 'divided by',
        '^' => 'raised to the power of',
        _ => symbol,
      };

  static String _linearTerm(double coefficient, String variable) =>
      coefficient == 1 ? variable : '${_fmt(coefficient)}$variable';

  static String _linearEquationText(
    double coefficient,
    String variable,
    double constant,
    double right,
  ) =>
      '${_linearTerm(coefficient, variable)} '
      '${constant >= 0 ? '+' : '-'} ${_fmt(constant.abs())} = ${_fmt(right)}';
}

/// One evaluated operation inside an arithmetic expression.
class _Operation {
  final double left;
  final double right;
  final String operator;
  final double value;
  final String leftText;
  final String rightText;
  final String leftSpoken;
  final String rightSpoken;
  final String valueSpoken;
  final String renderedBefore;
  final String renderedAfter;

  _Operation({
    required this.left,
    required this.right,
    required this.operator,
    required this.value,
    required this.leftText,
    required this.rightText,
    required this.leftSpoken,
    required this.rightSpoken,
    required this.valueSpoken,
    required this.renderedBefore,
    required this.renderedAfter,
  });
}

/// Recursive-descent parser that records each operation in evaluation order,
/// so the tutor can animate the calculation one operation at a time and show
/// the expression genuinely simplifying.
class _ArithmeticParser {
  _ArithmeticParser(this.source);

  final String source;
  final List<String> _tokens = <String>[];
  final Map<int, double> _values = <int, double>{};
  final Map<int, int> _spans = <int, int>{};
  final Map<int, String> _texts = <int, String>{};
  final Map<int, String> _spoken = <int, String>{};
  int _pos = 0;

  List<_Operation> parseOperations() {
    _tokenize();
    final operations = <_Operation>[];
    _parseExpression(operations);
    if (_pos != _tokens.length) {
      throw FormatException('Unexpected token', source, _pos);
    }
    return operations;
  }

  void _tokenize() {
    for (final match in RegExp(r'\d+(?:\.\d+)?|[()+\-*/^]').allMatches(source)) {
      _tokens.add(match.group(0)!);
    }
    if (_tokens.isEmpty) throw FormatException('No numbers found', source, 0);
  }

  void _parseExpression(List<_Operation> operations) {
    _parseTerm(operations);
    while (_pos < _tokens.length && (_tokens[_pos] == '+' || _tokens[_pos] == '-')) {
      final operator = _tokens[_pos++];
      _parseTerm(operations);
      _apply(operations, operator);
    }
  }

  void _parseTerm(List<_Operation> operations) {
    _parsePower(operations);
    while (_pos < _tokens.length && (_tokens[_pos] == '*' || _tokens[_pos] == '/')) {
      final operator = _tokens[_pos++];
      _parsePower(operations);
      _apply(operations, operator);
    }
  }

  void _parsePower(List<_Operation> operations) {
    _parseUnary(operations);
    if (_pos < _tokens.length && _tokens[_pos] == '^') {
      _pos++;
      _parsePower(operations);
      _apply(operations, '^');
    }
  }

  void _parseUnary(List<_Operation> operations) {
    if (_pos < _tokens.length && _tokens[_pos] == '-') {
      final next = _pos + 1 < _tokens.length ? double.tryParse(_tokens[_pos + 1]) : null;
      if (next != null) {
        _values[_pos] = -next;
        _spans[_pos] = _pos + 2;
        _texts[_pos] = '-${_formatValue(next)}';
        _spoken[_pos] = 'negative ${_formatValue(next)}';
        _pos += 2;
        return;
      }
    }
    if (_pos < _tokens.length && _tokens[_pos] == '(') {
      _pos++;
      _parseExpression(operations);
      if (_pos >= _tokens.length || _tokens[_pos] != ')') {
        throw FormatException('Missing closing bracket', source, _pos);
      }
      _pos++;
      return;
    }
    if (_pos >= _tokens.length) {
      throw FormatException('Unexpected end of expression', source, _pos);
    }
    final number = double.tryParse(_tokens[_pos]);
    if (number == null) {
      throw FormatException('Expected a number', source, _pos);
    }
    _values[_pos] = number;
    _spans[_pos] = _pos + 1;
    _texts[_pos] = _formatValue(number);
    _spoken[_pos] = _formatValue(number);
    _pos++;
  }

  /// Collapses the two most recent operands into a single value, recording
  /// what the whole expression looked like either side of the operation.
  void _apply(List<_Operation> operations, String operator) {
    final rightIndex = _rightmostValueIndex();
    final leftIndex = _valueIndexBefore(rightIndex);
    final left = _values[leftIndex]!;
    final right = _values[rightIndex]!;
    final leftText = _texts[leftIndex]!;
    final rightText = _texts[rightIndex]!;
    final leftSpoken = _spoken[leftIndex]!;
    final rightSpoken = _spoken[rightIndex]!;

    final before = _renderState();
    final start = _spans[leftIndex] ?? leftIndex;
    final end = _spans[rightIndex] ?? rightIndex + 1;
    final value = switch (operator) {
      '+' => left + right,
      '-' => left - right,
      '*' => left * right,
      '/' => right == 0 ? double.nan : left / right,
      '^' => math.pow(left, right).toDouble(),
      _ => double.nan,
    };

    for (final index in <int>[leftIndex, rightIndex]) {
      _values.remove(index);
      _spans.remove(index);
      _texts.remove(index);
      _spoken.remove(index);
    }

    _values[start] = value;
    _spans[start] = end;
    final formatted = _formatValue(value);
    _texts[start] = formatted;
    _spoken[start] = formatted;

    operations.add(_Operation(
      left: left,
      right: right,
      operator: operator,
      value: value,
      leftText: leftText,
      rightText: rightText,
      leftSpoken: leftSpoken,
      rightSpoken: rightSpoken,
      valueSpoken: formatted,
      renderedBefore: before,
      renderedAfter: _renderState(),
    ));
  }

  int _rightmostValueIndex() {
    for (var i = _pos - 1; i >= 0; i--) {
      if (_values.containsKey(i)) return i;
    }
    throw FormatException('Missing right operand', source, _pos);
  }

  int _valueIndexBefore(int before) {
    for (var i = before - 1; i >= 0; i--) {
      if (_values.containsKey(i)) return i;
    }
    throw FormatException('Missing left operand', source, before);
  }

  /// Renders the current expression with every collapsed span replaced by its
  /// value. Brackets are dropped because a collapsed group is always a single
  /// number, which leaves the remaining precedence unchanged.
  String _renderState() {
    final buffer = StringBuffer();
    var index = 0;
    while (index < _tokens.length) {
      final end = _spans[index];
      if (end != null) {
        _appendToken(buffer, _formatValue(_values[index]!));
        index = end;
        continue;
      }
      final token = _tokens[index];
      if (token != '(' && token != ')') _appendToken(buffer, token);
      index++;
    }
    return buffer.toString();
  }

  void _appendToken(StringBuffer buffer, String token) {
    const spaced = <String>{'+', '-', '*', '/', '^'};
    if (buffer.isNotEmpty && spaced.contains(token)) buffer.write(' ');
    buffer.write(token);
    if (spaced.contains(token)) buffer.write(' ');
  }

  static String _formatValue(double value) {
    if (value.isNaN) return 'undefined';
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return ((value * 1000).round() / 1000).toString();
  }
}
