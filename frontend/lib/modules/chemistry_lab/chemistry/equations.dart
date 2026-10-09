/// Balanced-equation parsing and atom-count verification.
///
/// Equations are **authored, validated data** — this module only *checks*
/// they are balanced; it never invents products or coefficients. Parsing
/// supports the school-level subset:
///
///   `HCl + NaOH -> NaCl + H2O`
///   `2H2 + O2 -> 2H2O`
///   `CaCO3 + 2HCl -> CaCl2 + H2O + CO2`
///
/// with optional state symbols `(aq) (l) (g) (s)` and `=`/`→`/`-->` as the
/// separator.
class ChemicalEquation {
  /// Left-hand side species, each with its coefficient.
  final List<EquationSpecies> reactants;

  /// Right-hand side species.
  final List<EquationSpecies> products;

  /// Raw source string as authored.
  final String source;

  const ChemicalEquation({
    required this.reactants,
    required this.products,
    required this.source,
  });

  /// Parses [source]. Throws [FormatException] on unparseable input so bad
  /// authored data fails tests instead of rendering nonsense.
  factory ChemicalEquation.parse(String source) {
    final normalized =
        source.replaceAll('→', '->').replaceAll('⟶', '->').replaceAll('-->', '->').replaceAll('=', '->').trim();
    final sides = normalized.split('->');
    if (sides.length != 2) {
      throw FormatException('Equation must contain exactly one "->": $source');
    }
    List<EquationSpecies> parseSide(String side) =>
        side.split('+').map((raw) => EquationSpecies.parse(raw.trim())).toList(growable: false);
    final reactants = parseSide(sides[0]);
    final products = parseSide(sides[1]);
    if (reactants.isEmpty || products.isEmpty) {
      throw FormatException('Equation has an empty side: $source');
    }
    return ChemicalEquation(reactants: reactants, products: products, source: source);
  }

  /// Element → count on each side. Only present when both sides agree on
  /// the element set; [isBalanced] uses per-side comparison anyway.
  Map<String, int> get reactantAtomCounts => _counts(reactants);

  Map<String, int> get productAtomCounts => _counts(products);

  /// True when every element appears with the same total on both sides —
  /// i.e. conservation of mass holds as written.
  bool get isBalanced {
    final a = reactantAtomCounts;
    final b = productAtomCounts;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static Map<String, int> _counts(List<EquationSpecies> species) {
    final totals = <String, int>{};
    for (final s in species) {
      s.elementCounts.forEach((element, count) {
        totals[element] = (totals[element] ?? 0) + count;
      });
    }
    return totals;
  }
}

/// One species in an equation, e.g. `2H2O` → coefficient 2, formula H2O.
class EquationSpecies {
  final int coefficient;

  /// Formula without coefficient or state symbol, e.g. `CaCO3`.
  final String formula;

  /// Optional state symbol: aq, l, g, s.
  final String? state;

  const EquationSpecies({
    required this.coefficient,
    required this.formula,
    this.state,
  });

  factory EquationSpecies.parse(String raw) {
    var text = raw;
    String? state;
    final stateMatch = RegExp(r'\((aq|l|g|s)\)$').firstMatch(text);
    if (stateMatch != null) {
      state = stateMatch.group(1);
      text = text.substring(0, stateMatch.start);
    }
    text = text.trim();
    if (text.isEmpty) throw const FormatException('Empty species in equation');

    var coefficient = 1;
    final coeffMatch = RegExp(r'^(\d+)').firstMatch(text);
    if (coeffMatch != null) {
      coefficient = int.parse(coeffMatch.group(1)!);
      text = text.substring(coeffMatch.group(1)!.length);
    }
    if (text.isEmpty) throw const FormatException('Missing formula after coefficient');

    return EquationSpecies(coefficient: coefficient, formula: text, state: state);
  }

  /// Element → atoms in this species (multiplied by the coefficient).
  Map<String, int> get elementCounts {
    final counts = <String, int>{};
    parseFormula(formula).forEach((element, n) {
      counts[element] = (counts[element] ?? 0) + n * coefficient;
    });
    return counts;
  }
}

/// Parses a molecular formula into element → atom count.
///
/// Supports nested parentheses, e.g. `Ca(OH)2`. Element symbols are
/// 1–2 characters with the first uppercased (`Cl` ≠ `C` + `l`).
Map<String, int> parseFormula(String formula) {
  final counts = <String, int>{};
  final tokens = _tokenize(formula);
  _parseRange(tokens, 0, tokens.length, counts, 1);
  return counts;
}

List<_Tok> _tokenize(String formula) {
  final out = <_Tok>[];
  final re = RegExp(r'([A-Z][a-z]?)|(\d+)|(\()|(\))');
  var i = 0;
  while (i < formula.length) {
    final m = re.matchAsPrefix(formula, i);
    if (m == null) {
      throw FormatException('Unexpected character at $i in "$formula"');
    }
    if (m.group(1) != null) {
      out.add(_Tok.symbol(m.group(1)!));
    } else if (m.group(2) != null) {
      out.add(_Tok.num(int.parse(m.group(2)!)));
    } else if (m.group(3) != null) {
      out.add(_Tok.open());
    } else {
      out.add(_Tok.close());
    }
    i = m.end;
  }
  return out;
}

void _parseRange(List<_Tok> toks, int start, int end, Map<String, int> out, int mult) {
  var i = start;
  while (i < end) {
    final t = toks[i];
    if (t.kind == _TokKind.symbol) {
      var n = 1;
      if (i + 1 < end && toks[i + 1].kind == _TokKind.num) {
        n = toks[i + 1].value!;
        i += 2;
      } else {
        i += 1;
      }
      out[t.text!] = (out[t.text!] ?? 0) + n * mult;
    } else if (t.kind == _TokKind.open) {
      // Find matching close.
      var depth = 1;
      var j = i + 1;
      while (j < end && depth > 0) {
        if (toks[j].kind == _TokKind.open) depth++;
        if (toks[j].kind == _TokKind.close) depth--;
        j++;
      }
      if (depth != 0) throw const FormatException('Unbalanced parentheses');
      final inner = <String, int>{};
      _parseRange(toks, i + 1, j - 1, inner, 1);
      var groupMult = 1;
      if (j < end && toks[j].kind == _TokKind.num) {
        groupMult = toks[j].value!;
        j += 1;
      }
      inner.forEach((element, n) {
        out[element] = (out[element] ?? 0) + n * mult * groupMult;
      });
      i = j;
    } else if (t.kind == _TokKind.close) {
      throw const FormatException('Unexpected ")"');
    } else {
      // Leading number without a symbol — only valid as coefficient handled above.
      throw const FormatException('Unexpected number in formula');
    }
  }
}

class _Tok {
  final _TokKind kind;
  final String? text;
  final int? value;

  _Tok(this.kind, {this.text, this.value});

  factory _Tok.symbol(String s) => _Tok(_TokKind.symbol, text: s);
  factory _Tok.num(int n) => _Tok(_TokKind.num, value: n);
  factory _Tok.open() => _Tok(_TokKind.open);
  factory _Tok.close() => _Tok(_TokKind.close);
}

enum _TokKind { symbol, num, open, close }
