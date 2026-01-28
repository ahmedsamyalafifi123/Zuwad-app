import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WordwallWebView extends StatefulWidget {
  final String url;

  const WordwallWebView({super.key, required this.url});

  @override
  State<WordwallWebView> createState() => _WordwallWebViewState();
}

class _WordwallWebViewState extends State<WordwallWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF8b0628),
            ),
          ),
      ],
    );
  }
}
