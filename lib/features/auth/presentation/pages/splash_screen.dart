import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import 'login_page.dart';
import '../../../student_dashboard/presentation/pages/student_dashboard_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  bool _isNavigating = false;
  bool _isInitialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      // Initialize animation controller
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );

      // Create fade animation
      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController!,
          curve: Curves.easeIn,
        ),
      );

      // Start animation
      _animationController!.forward();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      // Check auth status after a delay
      Timer(const Duration(seconds: 2), () {
        if (mounted && !_isNavigating) {
          try {
            context.read<AuthBloc>().add(CheckAuthStatusEvent());
          } catch (e, stack) {
            FirebaseCrashlytics.instance.recordError(e, stack, key: 'splash_auth_check');
          }
        }
      });
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
        });
      }
      FirebaseCrashlytics.instance.recordError(e, stack, key: 'splash_init');
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _navigateToPage(Widget page) {
    if (_isNavigating || !mounted) return;

    setState(() {
      _isNavigating = true;
    });

    try {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, key: 'splash_navigation');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error screen if initialization failed
    if (_initError != null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ أثناء تحميل التطبيق',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _initError!,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show loading while initializing
    if (!_isInitialized || _fadeAnimation == null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Center(
          child: SpinKitThreeBounce(
            color: AppTheme.secondaryColor,
            size: 24.0,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            _navigateToPage(const StudentDashboardPage());
          } else if (state is AuthUnauthenticated) {
            _navigateToPage(const LoginPage());
          }
        },
        child: AnimatedBuilder(
          animation: _animationController!,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation!.value,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Hero(
                        tag: 'app_logo',
                        child: Image.asset(
                          'assets/images/zuwad.png',
                          width: 180,
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.school, size: 100, color: Colors.white);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // App Name
                      const Text(
                        'أكاديمية زواد',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.whiteColor,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline
                      const Text(
                        'التعلم بكل سهولة',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Loading Indicator
                      const SpinKitThreeBounce(
                        color: AppTheme.secondaryColor,
                        size: 24.0,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
