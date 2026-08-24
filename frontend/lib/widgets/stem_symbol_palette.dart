import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../core/theme/theme_colors.dart';

class StemSymbolPalette extends StatelessWidget {
  final void Function(String) onSymbolTap;
  final bool showInline;

  const StemSymbolPalette({
    super.key,
    required this.onSymbolTap,
    this.showInline = true,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: showInline ? 220 : 360,
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            top: BorderSide(color: context.colors.border),
          ),
        ),
        child: DefaultTabController(
          length: _categories.length,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: context.colors.textMuted,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                tabs: _categories.map((c) => Tab(text: c.label)).toList(),
              ),
              Expanded(
                child: TabBarView(
                  children: _categories.map((cat) => _buildSymbolGrid(cat.symbols, onSymbolTap)).toList(),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSymbolGrid(List<StemSymbol> symbols, void Function(String) onTap) => GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 48,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: symbols.length,
        itemBuilder: (context, index) {
          final sym = symbols[index];
          return InkWell(
            onTap: () => onTap(sym.latex),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.border),
              ),
              child: Center(
                child: Text(
                  sym.display,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: sym.display.length > 3 ? 10 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class StemSymbol {
  final String display;
  final String latex;
  StemSymbol(this.display, this.latex);
}

class _StemCategory {
  final String label;
  final List<StemSymbol> symbols;
  const _StemCategory(this.label, this.symbols);
}

final _categories = [
  _StemCategory('Basic', [
    StemSymbol('+', '+'),
    StemSymbol('−', '-'),
    StemSymbol('×', '\\times'),
    StemSymbol('÷', '\\div'),
    StemSymbol('=', '='),
    StemSymbol('≠', '\\neq'),
    StemSymbol('≈', '\\approx'),
    StemSymbol('≡', '\\equiv'),
    StemSymbol('<', '<'),
    StemSymbol('>', '>'),
    StemSymbol('≤', '\\leq'),
    StemSymbol('≥', '\\geq'),
    StemSymbol('±', '\\pm'),
    StemSymbol('%', '\\%'),
  ]),
  _StemCategory('Powers', [
    StemSymbol('x²', 'x^{2}'),
    StemSymbol('x³', 'x^{3}'),
    StemSymbol('xⁿ', 'x^{n}'),
    StemSymbol('x₁', 'x_{1}'),
    StemSymbol('x₂', 'x_{2}'),
    StemSymbol('xₙ', 'x_{n}'),
    StemSymbol('√', '\\sqrt{}'),
    StemSymbol('∛', '\\sqrt[3]{}'),
    StemSymbol('ⁿ√', '\\sqrt[n]{}'),
    StemSymbol('a/b', '\\frac{a}{b}'),
  ]),
  _StemCategory('Calculus', [
    StemSymbol('∫', '\\int'),
    StemSymbol('∫ₐᵇ', '\\int_{a}^{b}'),
    StemSymbol('∬', '\\iint'),
    StemSymbol('∭', '\\iiint'),
    StemSymbol('∮', '\\oint'),
    StemSymbol('Σ', '\\sum'),
    StemSymbol('Σᵢ', '\\sum_{i=1}^{n}'),
    StemSymbol('Π', '\\prod'),
    StemSymbol('lim', '\\lim'),
    StemSymbol('d/dx', '\\frac{d}{dx}'),
    StemSymbol('∂', '\\partial'),
    StemSymbol('∞', '\\infty'),
  ]),
  _StemCategory('Greek', [
    StemSymbol('α', '\\alpha'),
    StemSymbol('β', '\\beta'),
    StemSymbol('γ', '\\gamma'),
    StemSymbol('δ', '\\delta'),
    StemSymbol('ε', '\\epsilon'),
    StemSymbol('θ', '\\theta'),
    StemSymbol('λ', '\\lambda'),
    StemSymbol('μ', '\\mu'),
    StemSymbol('π', '\\pi'),
    StemSymbol('σ', '\\sigma'),
    StemSymbol('φ', '\\phi'),
    StemSymbol('ω', '\\omega'),
    StemSymbol('Δ', '\\Delta'),
    StemSymbol('Σ', '\\Sigma'),
    StemSymbol('Ω', '\\Omega'),
    StemSymbol('Π', '\\Pi'),
  ]),
  _StemCategory('Sets', [
    StemSymbol('∈', '\\in'),
    StemSymbol('∉', '\\notin'),
    StemSymbol('⊂', '\\subset'),
    StemSymbol('⊆', '\\subseteq'),
    StemSymbol('∪', '\\cup'),
    StemSymbol('∩', '\\cap'),
    StemSymbol('∅', '\\emptyset'),
    StemSymbol('∀', '\\forall'),
    StemSymbol('∃', '\\exists'),
    StemSymbol('∴', '\\therefore'),
    StemSymbol('∵', '\\because'),
    StemSymbol('⇒', '\\Rightarrow'),
    StemSymbol('⇔', '\\Leftrightarrow'),
    StemSymbol('¬', '\\neg'),
    StemSymbol('∧', '\\wedge'),
    StemSymbol('∨', '\\vee'),
  ]),
  _StemCategory('Vectors', [
    StemSymbol('→', '\\vec{}'),
    StemSymbol('F⃗', '\\vec{F}'),
    StemSymbol('|A|', '\\lvert A \\rvert'),
    StemSymbol('A⁻¹', 'A^{-1}'),
    StemSymbol('Aᵀ', 'A^{T}'),
    StemSymbol('[2×2]', '\\begin{bmatrix} a & b \\\\ c & d \\end{bmatrix}'),
    StemSymbol('[3×3]', '\\begin{bmatrix} a & b & c \\\\ d & e & f \\\\ g & h & i \\end{bmatrix}'),
  ]),
  _StemCategory('Stats', [
    StemSymbol('P(A)', 'P(A)'),
    StemSymbol('P(A|B)', 'P(A|B)'),
    StemSymbol('E(X)', 'E(X)'),
    StemSymbol('Var(X)', '\\text{Var}(X)'),
    StemSymbol('σ', '\\sigma'),
    StemSymbol('μ', '\\mu'),
    StemSymbol('x̄', '\\bar{x}'),
    StemSymbol('χ²', '\\chi^{2}'),
    StemSymbol('R²', 'R^{2}'),
  ]),
  _StemCategory('Chem', [
    StemSymbol('H₂O', 'H_{2}O'),
    StemSymbol('CO₂', 'CO_{2}'),
    StemSymbol('O₂', 'O_{2}'),
    StemSymbol('N₂', 'N_{2}'),
    StemSymbol('CH₄', 'CH_{4}'),
    StemSymbol('H₂SO₄', 'H_{2}SO_{4}'),
    StemSymbol('→', '\\rightarrow'),
    StemSymbol('⇌', '\\rightleftharpoons'),
    StemSymbol('Fe³⁺', 'Fe^{3+}'),
    StemSymbol('Na⁺', 'Na^{+}'),
    StemSymbol('Cl⁻', 'Cl^{-}'),
    StemSymbol('SO₄²⁻', 'SO_{4}^{2-}'),
  ]),
];
