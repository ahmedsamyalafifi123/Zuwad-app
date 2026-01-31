import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView page for displaying Fawaterk payment gateway.
///
/// This page loads the payment URL in a WebView and monitors
/// for payment completion via URL patterns.
class FawaterkPaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;

  const FawaterkPaymentWebViewPage({
    super.key,
    required this.paymentUrl,
  });

  @override
  State<FawaterkPaymentWebViewPage> createState() =>
      _FawaterkPaymentWebViewPageState();
}

class _FawaterkPaymentWebViewPageState
    extends State<FawaterkPaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _paymentCompleted = false;

  // URL patterns for payment status detection
  static const String _successPattern = 'payment-has-been-successfully-completed';
  static const String _failPattern = 'payment-has-failed';
  static const String _pendingPattern = 'payment-is-pending';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _checkPaymentStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('WebView Error: ${error.description}');
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            _checkPaymentStatus(request.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _checkPaymentStatus(String url) {
    if (_paymentCompleted) return;

    final lowerUrl = url.toLowerCase();

    if (lowerUrl.contains(_successPattern)) {
      _paymentCompleted = true;
      _showPaymentResult(true, 'تمت عملية الدفع بنجاح!');
    } else if (lowerUrl.contains(_failPattern)) {
      _paymentCompleted = true;
      _showPaymentResult(false, 'فشلت عملية الدفع. يرجى المحاولة مرة أخرى.');
    } else if (lowerUrl.contains(_pendingPattern)) {
      _paymentCompleted = true;
      _showPaymentResult(true, 'الدفع قيد المعالجة. سيتم تحديث رصيدك قريباً.');
    }
  }

  void _showPaymentResult(bool success, String message) {
    if (!mounted) return;

    // Close the WebView and return to settings
    Navigator.pop(context);

    // Show result message via SnackBar on the settings page
    // We use a small delay to ensure we're back on the settings page
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontFamily: 'Qatar'),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8b0628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8b0628),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'الدفع',
          style: TextStyle(
            fontFamily: 'Qatar',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8b0628)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل بوابة الدفع...',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 16,
                        color: Color(0xFF8b0628),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
