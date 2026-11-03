import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

typedef SmartboardEvent = void Function(Map<String, dynamic> event);

class SmartboardController {
  SmartboardController(this._controller);

  final InAppWebViewController _controller;

  Future<Map<String, dynamic>> getState() async {
    final result = await _controller.evaluateJavascript(
      source: 'JSON.stringify(window.MapReading.getState())',
    );
    if (result is! String) {
      throw StateError('The smartboard did not return its current map state.');
    }
    return (jsonDecode(result) as Map).cast<String, dynamic>();
  }

  Future<void> setState(Map<String, dynamic> state) async {
    await _controller.evaluateJavascript(
      source: 'window.MapReading.setState(${jsonEncode(state)})',
    );
  }

  Future<String> getPng() async {
    final result = await _controller.evaluateJavascript(
      source: 'window.MapReading.getPng()',
    );
    if (result is! String || !result.startsWith('data:image/png;base64,')) {
      throw StateError('The smartboard could not create a PNG image.');
    }
    return result;
  }

  Future<void> printMap() async {
    await _controller.evaluateJavascript(
      source: 'window.MapReading.printMap()',
    );
  }
}

class SmartboardView extends StatefulWidget {
  const SmartboardView({
    required this.onReady,
    required this.onEvent,
    required this.darkMode,
    super.key,
  });

  final ValueChanged<SmartboardController> onReady;
  final SmartboardEvent onEvent;
  final bool darkMode;

  @override
  State<SmartboardView> createState() => _SmartboardViewState();
}

class _SmartboardViewState extends State<SmartboardView> {
  late final Future<String> _page = _loadSmartboard();

  Future<String> _loadSmartboard() async {
    var html = await rootBundle.loadString('assets/smartboard/index.html');
    const scripts = [
      'engine.js',
      'features.js',
      'questions.js',
      'annotate.js',
      'demo.js',
      'smartboard-bridge.js',
    ];
    for (final name in scripts) {
      final source = await rootBundle.loadString('assets/smartboard/$name');
      html = html.replaceFirst(
        '<script src="$name"></script>',
        '<script>\n$source\n</script>',
      );
    }
    return html;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _page,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text(
            'Smartboard assets could not be loaded: ${snapshot.error}',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return InAppWebView(
        initialData: InAppWebViewInitialData(
          data: snapshot.requireData,
          baseUrl: WebUri('https://mapreads.local/'),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          transparentBackground: false,
          supportZoom: true,
        ),
        onWebViewCreated: (controller) {
          if (!kIsWeb) {
            controller.addJavaScriptHandler(
              handlerName: 'mapreadsEvent',
              callback: (arguments) {
                if (arguments.isNotEmpty &&
                    arguments.first is Map<String, dynamic>) {
                  widget.onEvent(arguments.first as Map<String, dynamic>);
                }
                return null;
              },
            );
          }
          widget.onReady(SmartboardController(controller));
        },
        onLoadStop: (controller, url) async {
          final theme = widget.darkMode ? 'dark' : 'light';
          await controller.evaluateJavascript(
            source: "window.setTheme('$theme')",
          );
        },
      );
    },
  );
}
