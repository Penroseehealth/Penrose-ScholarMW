/// Penrose Academic Speech Normalizer (Dart).
///
/// Converts mathematical, chemical, and scientific notation
/// into TTS-friendly spoken text for the voice engine.
class AcademicSpeechNormalizer {
  AcademicSpeechNormalizer._();

  static const Map<String, String> _chemicalReadings = {
    'H2O': 'H two O',
    'CO2': 'C O two',
    'NaCl': 'N A C L',
    'H2SO4': 'H two S O four',
    'NaOH': 'N A O H',
    'CaCO3': 'C A C O three',
    'O2': 'O two',
    'N2': 'N two',
    'CH4': 'C H four',
    'NH3': 'N H three',
    'HCl': 'H C L',
    'Fe2O3': 'F e two O three',
    'CaO': 'C A O',
    'MgO': 'M g O',
    'KOH': 'K O H',
    'Na2CO3': 'N a two C O three',
  };

  static const Map<String, String> _greekLetters = {
    'α': 'alpha',
    'β': 'beta',
    'γ': 'gamma',
    'δ': 'delta',
    'ε': 'epsilon',
    'θ': 'theta',
    'λ': 'lambda',
    'μ': 'mu',
    'π': 'pi',
    'σ': 'sigma',
    'τ': 'tau',
    'φ': 'phi',
    'ω': 'omega',
    'Δ': 'Delta',
    'Σ': 'Sigma',
    'Ω': 'Omega',
    '∞': 'infinity',
  };

  static const Map<String, String> _mathOperators = {
    '×': ' times ',
    '÷': ' divided by ',
    '±': ' plus or minus ',
    '≠': ' not equal to ',
    '≤': ' less than or equal to ',
    '≥': ' greater than or equal to ',
    '√': ' square root of ',
    '∫': ' integral of ',
    '∑': ' sum of ',
    '∈': ' is in ',
    '⊂': ' is a subset of ',
    '→': ' yields ',
    '⇌': ' is in equilibrium with ',
    '≈': ' approximately equals ',
    '∝': ' is proportional to ',
    '∇': ' del ',
    '∂': ' partial ',
  };

  static final _superscriptPattern = RegExp(r'([a-zA-Z0-9]+)([²³⁴⁵⁶⁷⁸⁹⁰¹⁺⁻]+)');
  static final _latexPowerPattern = RegExp(r'\^\{?(\d+)\}?');
  static final _fractionPattern = RegExp(r'(\d+)/(\d+)');
  static final _percentPattern = RegExp(r'(\d+)%');

  /// Convert notation-heavy text into spoken words.
  static String normalize(String text) {
    var result = text;
    result = _normalizeChemicals(result);
    result = _normalizeSuperscripts(result);
    result = _normalizeSubscripts(result);
    result = _normalizeGreek(result);
    result = _normalizeMathOperators(result);
    result = _normalizePatterns(result);
    return result.trim();
  }

  static String _normalizeChemicals(String text) {
    var result = text;
    for (final entry in _chemicalReadings.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String _normalizeSuperscripts(String text) {
    return text.replaceAllMapped(_superscriptPattern, (m) {
      final base = m.group(1)!;
      final exp = m.group(2)!;
      final spokenExp = exp.split('').map((c) {
        const map = {
          '⁰': '0',
          '¹': '1',
          '²': '2',
          '³': '3',
          '⁴': '4',
          '⁵': '5',
          '⁶': '6',
          '⁷': '7',
          '⁸': '8',
          '⁹': '9',
          '⁺': '+',
          '⁻': '-',
        };
        return map[c] ?? c;
      }).join();
      return '$base to the power of $spokenExp';
    }).replaceAllMapped(_latexPowerPattern, (m) {
      final exp = m.group(1)!;
      if (exp == '2') return ' squared';
      if (exp == '3') return ' cubed';
      return ' to the power of $exp';
    });
  }

  static String _normalizeSubscripts(String text) {
    return text.replaceAllMapped(RegExp(r'[₀-₉]+'), (m) {
      return m.group(0)!.split('').map((c) {
        const map = {
          '₀': '0',
          '₁': '1',
          '₂': '2',
          '₃': '3',
          '₄': '4',
          '₅': '5',
          '₆': '6',
          '₇': '7',
          '₈': '8',
          '₉': '9',
        };
        return map[c] ?? c;
      }).join();
    });
  }

  static String _normalizeGreek(String text) {
    var result = text;
    for (final entry in _greekLetters.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String _normalizeMathOperators(String text) {
    var result = text;
    for (final entry in _mathOperators.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String _normalizePatterns(String text) {
    var result = text;
    result = result.replaceAllMapped(_fractionPattern, (m) {
      return '${m.group(1)} over ${m.group(2)}';
    });
    result = result.replaceAllMapped(_percentPattern, (m) {
      return '${m.group(1)} percent';
    });
    result = result.replaceAll('e.g.', 'for example');
    result = result.replaceAll('i.e.', 'that is');
    result = result.replaceAll('etc.', 'et cetera');
    return result;
  }
}
