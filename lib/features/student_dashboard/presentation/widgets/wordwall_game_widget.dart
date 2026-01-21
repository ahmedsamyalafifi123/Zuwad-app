import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../domain/models/student_report.dart';
import '../../services/quran_game_service.dart';

class WordwallGameWidget extends StatefulWidget {
  final StudentReport? lastReport;

  const WordwallGameWidget({super.key, this.lastReport});

  @override
  State<WordwallGameWidget> createState() => _WordwallGameWidgetState();
}

class _WordwallGameWidgetState extends State<WordwallGameWidget> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isWebViewInitialized = false;
  String _gameUrl =
      'https://wordwall.net/ar/embed/913a5376b8444a0bbf32a3c56b0e6765?themeId=65&templateId=8&fontStackId=0'; // Default game
  final QuranGameService _gameService = QuranGameService();
  final List<String> _shownGameIds = []; // Track shown game IDs
  bool _isRefreshing = false; // Track refresh state

  @override
  void initState() {
    super.initState();
    _loadGameUrl();
  }

  /// Load game URL based on student's progress
  /// [refresh] - Set to true when refreshing to get a new game
  Future<void> _loadGameUrl({bool refresh = false}) async {
    try {
      if (widget.lastReport == null || widget.lastReport!.nextTasmii.isEmpty) {
        // No report, use default game
        return;
      }

      // Extract surah number from nextTasmii
      final surahNumber =
          _gameService.extractSurahNumber(widget.lastReport!.nextTasmii);

      if (kDebugMode) {
        print(
            'QuranGame: nextTasmii="${widget.lastReport!.nextTasmii}", extracted surah=$surahNumber');
        print('QuranGame: Excluding ${_shownGameIds.length} shown games');
      }

      // Get random game for surahs after the current one, excluding shown games
      final game = await _gameService.getRandomGame(
        surahNumber,
        excludeGameIds: _shownGameIds,
      );

      if (game != null) {
        final gameUrl = _gameService.getGameUrl(game);
        final gameId = game['game_id'] as String?;

        if (gameUrl != null && gameUrl.isNotEmpty) {
          if (mounted) {
            setState(() {
              _gameUrl = gameUrl;
              // Add current game ID to shown list
              if (gameId != null && !_shownGameIds.contains(gameId)) {
                _shownGameIds.add(gameId);
              }
            });
          }
          if (kDebugMode) {
            print('QuranGame: Loaded game URL: $gameUrl (ID: $gameId)');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('QuranGame: Error loading game: $e');
      }
      // Keep default game on error
    }
  }

  /// Refresh to load a new game
  Future<void> _refreshGame() async {
    if (_isRefreshing) return; // Prevent multiple refreshes

    setState(() {
      _isRefreshing = true;
      _isLoading = true; // Show loading indicator
    });

    try {
      // Load a new game URL
      await _loadGameUrl(refresh: true);

      // Wait a bit for state to update
      await Future.delayed(const Duration(milliseconds: 100));

      // If WebView is initialized and we have a new URL, reload it
      if (mounted && _isWebViewInitialized && _controller != null) {
        if (kDebugMode) {
          print('QuranGame: Reloading WebView with new URL: $_gameUrl');
        }
        await _controller!.loadRequest(Uri.parse(_gameUrl));
      }
    } catch (e) {
      if (kDebugMode) {
        print('QuranGame: Error refreshing game: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
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
    return Column(
      children: [
        // Game widget
        _buildGameWidget(),

        // Refresh button - only show when game is initialized and not refreshing
        if (_isWebViewInitialized && !_isRefreshing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 253, 247, 89), // Light yellow
                    Color.fromARGB(255, 240, 191, 12), // Lighter yellow
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton.icon(
                onPressed: _refreshGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'تغيير اللعبة',
                  style: TextStyle(
                    fontFamily: 'Qatar',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),

        // Show loading indicator when refreshing
        if (_isRefreshing)
          const Padding(
            padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 0.0),
            child: CircularProgressIndicator(
              color: Color(0xFFD4AF37),
            ),
          ),
      ],
    );
  }

  Widget _buildGameWidget() {
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
