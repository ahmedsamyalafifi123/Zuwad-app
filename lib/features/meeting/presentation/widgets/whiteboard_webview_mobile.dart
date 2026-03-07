import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WhiteboardWebView extends StatefulWidget {
  final String roomName;
  final String studentId;
  final String studentName;
  final String studentEmail;

  const WhiteboardWebView({
    super.key,
    required this.roomName,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
  });

  @override
  State<WhiteboardWebView> createState() => _WhiteboardWebViewState();
}

class _WhiteboardWebViewState extends State<WhiteboardWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasInjectedAuth = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      print('WhiteboardWebView: initState for room ${widget.roomName}');
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (kDebugMode && progress % 20 == 0) {
              print('Whiteboard loading progress: $progress%');
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasInjectedAuth = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              _injectAuthHandshake();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print('Whiteboard error: ${error.description}, code: ${error.errorCode}');
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://board.zuwad-academy.com/${widget.roomName}'));
  }

  void _injectAuthHandshake() {
    if (_hasInjectedAuth) return;
    
    final authMessage = {
      'type': 'WORDPRESS_USER_AUTH',
      'payload': {
        'userId': widget.studentId,
        'userName': widget.studentName,
        'userEmail': widget.studentEmail,
        'roles': ['student'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    };

    final jsCode = '''
      (function() {
        try {
          // 1. Force Viewport for "Zoom Out" effect
          // Using a very wide virtual width (1600px) forces a significant zoom out
          let meta = document.querySelector('meta[name="viewport"]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = "viewport";
            document.head.appendChild(meta);
          }
          meta.content = "width=1600, initial-scale=0.25, maximum-scale=5.0, user-scalable=yes";

          // 2. Authentication
          setTimeout(() => {
            if (window.postMessage) {
              window.postMessage(${jsonEncode(authMessage)}, 'https://board.zuwad-academy.com');
            }
          }, 500);

          // 3. UI Cleanup and Scaling
          const style = document.createElement('style');
          style.innerHTML = `
            /* Hide headers, footers, and sidebars */
            header, footer, .sidebar, .nav-menu, .upper-menu, .left-menu, #header, #footer { 
              display: none !important; 
              height: 0 !important;
              visibility: hidden !important;
            }
            
            body, html { 
              margin: 0 !important; 
              padding: 0 !important; 
              overflow: hidden !important;
              background-color: #ffffff !important;
              width: 100% !important;
              height: 100% !important;
            }

            /* Ensure board fills the scaled container */
            #board-container, .board-wrapper, #canvas-container {
              width: 100% !important;
              height: 100% !important;
              position: absolute !important;
              top: 0 !important;
              left: 0 !important;
            }
          `;
          document.head.appendChild(style);

          // 4. Reset position
          window.scrollTo(0, 0);
          
        } catch (e) {
          console.error('Flutter JS injection error:', e);
        }
      })();
    ''';

    if (mounted) {
      _controller.runJavaScript(jsCode).then((_) {
        if (mounted) {
          setState(() {
            _hasInjectedAuth = true;
          });
        }
      }).catchError((e) {
        if (kDebugMode) {
          print('Whiteboard: Failed to inject JS: $e');
        }
      });
      if (kDebugMode) {
        print('Whiteboard: Injected auth handshake for ${widget.studentName}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFf6c302),
              ),
            ),
        ],
      ),
    );
  }
}
