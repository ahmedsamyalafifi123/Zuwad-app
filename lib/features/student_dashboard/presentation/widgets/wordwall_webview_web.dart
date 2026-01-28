import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

class WordwallWebView extends StatelessWidget {
  final String url;

  const WordwallWebView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    // Register the view factory
    // Use a unique ID based on the URL to ensure the factory captures the correct URL
    // and forces a fresh IFrame when the URL changes.
    final String viewType = 'wordwall-game-iframe-${url.hashCode}';

    // Register only once if possible, but safe to re-register usually or handle via logic.
    // However, platformViewRegistry is global.
    // In strict mode, we might check if registered, but registry doesn't expose list.
    // Ideally this registration happens once in main, but for this widget usage, we can do it here lazily.
    // Note: registerViewFactory is safe to call multiple times with same name?
    // Actually, usually it overwrites.

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final element = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return element;
    });

    return HtmlElementView(viewType: viewType);
  }
}
