import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WordwallGameWidget extends StatefulWidget {
  const WordwallGameWidget({super.key});

  @override
  State<WordwallGameWidget> createState() => _WordwallGameWidgetState();
}

class _WordwallGameWidgetState extends State<WordwallGameWidget> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isWebViewInitialized = false;
  final String _gameUrl =
      'https://wordwall.net/ar/embed/913a5376b8444a0bbf32a3c56b0e6765?themeId=65&templateId=8&fontStackId=0';

  @override
  void initState() {
    super.initState();
    // We do NOT initialize the WebView here to prevent startup crashes.
    // Initialization happens when the user clicks "Start Game".
  }

  Future<void> _launchGameInBrowser() async {
    final uri = Uri.parse(_gameUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _initializeWebView() {
    try {
      // Check platform using foundation to be safe
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        setState(() {
          _isWebViewInitialized = true;
          _isLoading = true;
        });

        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                  });
                }
              },
              onPageFinished: (String url) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              onWebResourceError: (WebResourceError error) {
                debugPrint('Wordwall WebView Error: ${error.description}');
              },
            ),
          )
          ..loadRequest(Uri.parse(_gameUrl));
      } else {
        // Desktop or Web - Fallback
        _launchGameInBrowser();
      }
    } catch (e) {
      debugPrint('Error initializing WebView: $e');
      setState(() {
        _isWebViewInitialized = false;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading game: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not initialized, show the start button
    if (!_isWebViewInitialized) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
        margin: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 0,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 255, 255, 255), // Warm cream white
              Color.fromARGB(255, 234, 234, 234), // Subtle gold tint
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/images/game.json',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
            // Removed SizedBox here to eliminate extra space
            ElevatedButton.icon(
              onPressed: _initializeWebView,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8b0628), // App primary color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'بدء اللعبة',
                style: TextStyle(
                  fontFamily: 'Qatar',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Checking _controller availability for safety (though it should be set if _isWebViewInitialized is true for mobile)
    if (_controller == null &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      // Should not happen, but safe fallback
      return const SizedBox();
    }

    // For Desktop fallback when initialized (it would have launched browser, but we can return the placeholder again or a "Playing in browser" message)
    if (!kIsWeb &&
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
            child: Text('تم فتح اللعبة في المتصفح',
                style: TextStyle(fontFamily: 'Qatar'))),
      );
    }

    // Mobile View
    return Container(
      width: double.infinity,
      height: 480,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF8b0628), // App primary color
                ),
              ),
          ],
        ),
      ),
    );
  }
}
