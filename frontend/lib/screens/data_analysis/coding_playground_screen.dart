import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../services/services.dart';
import '../../core/theme/theme_colors.dart';

class CodingPlaygroundScreen extends StatefulWidget {
  const CodingPlaygroundScreen({super.key});

  @override
  State<CodingPlaygroundScreen> createState() => _CodingPlaygroundScreenState();
}

class _CodingPlaygroundScreenState extends State<CodingPlaygroundScreen> {
  final AiService _aiService = AiService();
  final TextEditingController _codeCtrl = TextEditingController();
  final ScrollController _outputScroll = ScrollController();

  String _language = 'python';
  String _output = '';
  String? _error;
  bool _isRunning = false;

  final Map<String, String> _templates = {
    'python': '''# Python Playground
# Try writing some Python code!

def greet(name):
    return f"Hello, {name}!"

# Calculate factorial
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

# Test
print(greet("ScholarMW Student"))
for i in range(1, 8):
    print(f"{i}! = {factorial(i)}")

# List comprehension
squares = [x**2 for x in range(1, 11)]
print(f"Squares: {squares}")''',
    'javascript': r'''// JavaScript Playground
function greet(name) {
    return `Hello, ${name}!`;
}

console.log(greet("ScholarMW Student"));

// Array operations
const numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const doubled = numbers.map(n => n * 2);
console.log("Doubled:", doubled);

const evens = numbers.filter(n => n % 2 === 0);
console.log("Evens:", evens);''',
    'html': '''<!-- HTML Playground -->
<div style="font-family: Arial, sans-serif; padding: 20px;">
  <h1 style="color: #4A90D9;">Hello ScholarMW!</h1>
  <p>This is an HTML preview.</p>
  <ul>
    <li>Mathematics</li>
    <li>Computer Science</li>
    <li>Physics</li>
  </ul>
</div>''',
  };

  @override
  void initState() {
    super.initState();
    _codeCtrl.text = _templates['python'] ?? '';
  }

  Future<void> _runCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please write some code first');
      return;
    }
    setState(() {
      _isRunning = true;
      _output = '';
      _error = null;
    });

    final res = await _aiService.runCode(code: code, language: _language);

    if (mounted) {
      setState(() {
        _isRunning = false;
        if (res['success']) {
          final data = res['data'];
          _output = data['output'] ?? '';
          _error = data['error'];
        } else {
          _error = res['error'] ?? 'Execution failed';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: const Row(
          children: [
            Icon(Icons.code_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text(
              'Coding Playground',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _language,
                isDense: true,
                style: TextStyle(fontSize: 13, color: context.colors.textPrimary),
                dropdownColor: context.colors.surfaceElevated,
                items: [
                  const DropdownMenuItem(value: 'python', child: Text('Python')),
                  const DropdownMenuItem(value: 'javascript', child: Text('JavaScript')),
                  const DropdownMenuItem(value: 'html', child: Text('HTML')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _language = v;
                      _codeCtrl.text = _templates[v] ?? '';
                    });
                  }
                },
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isRunning ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
              color: _isRunning ? context.colors.textMuted : context.colors.success,
            ),
            tooltip: 'Run code',
            onPressed: _isRunning ? null : _runCode,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildCodeEditor(),
          ),
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildOutputPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditor() {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF181825),
            child: Row(
              children: [
                Icon(Icons.code_rounded, size: 14, color: context.colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Code Editor — $_language',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _codeCtrl.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: context.colors.textMuted),
                      const SizedBox(width: 4),
                      Text('Copy', style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Semantics(
              label: 'Code editor',
              child: TextField(
                controller: _codeCtrl,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFFCDD6F4),
                  height: 1.6,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputPanel() {
    return Container(
      color: const Color(0xFF11111B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF181825),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, size: 14, color: context.colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Output',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_output.isNotEmpty || _error != null)
                  GestureDetector(
                    onTap: () {
                      final text = _error != null ? 'ERROR: $_error' : _output;
                      Clipboard.setData(ClipboardData(text: text));
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: context.colors.textMuted),
                        const SizedBox(width: 4),
                        Text('Copy', style: TextStyle(fontSize: 10, color: context.colors.textMuted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Semantics(
              label: 'Code output panel',
              child: _isRunning
                  ? Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Text('Running...', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  : _error != null
                      ? _buildErrorOutput()
                      : _buildSuccessOutput(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOutput() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        'ERROR:\n$_error',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFFF38BA8),
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSuccessOutput() {
    if (_output.isEmpty) {
      return Center(
        child: Text(
          'Click Run to execute your code',
          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
        ),
      );
    }
    return SingleChildScrollView(
      controller: _outputScroll,
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        _output,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Color(0xFFA6E3A1),
          height: 1.5,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _outputScroll.dispose();
    super.dispose();
  }
}
