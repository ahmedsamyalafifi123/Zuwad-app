import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isNavigating = false;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Create fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    // Start animation
    _animationController.forward();
    
    // Check auth status after a delay
    Timer(const Duration(seconds: 2), () {
      if (!_isNavigating) {
        context.read<AuthBloc>().add(CheckAuthStatusEvent());
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToPage(Widget page) {
    if (_isNavigating) return;
    
    setState(() {
      _isNavigating = true;
    });
    
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
  }

  @override
  Widget build(BuildContext context) {
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
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
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
