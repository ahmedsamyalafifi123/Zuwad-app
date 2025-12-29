import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../student_dashboard/presentation/pages/student_dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Custom maroon color from design
  static const Color bgColor = Color(0xFF7D0D21);
  static const Color goldColor = Color(0xFFD4A940);

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // ========== EASY CONTROLS ==========
    // Phone bg_top settings
    const double phoneBgTopPosition =
        0; // Move up (negative) or down (positive)
    const double phoneBgTopHeight = 0.50; // Percentage of screen (0.50 = 50%)

    // Tablet bg_top settings
    const double tabletBgTopPosition =
        -50; // Move up (negative) or down (positive)
    const double tabletBgTopHeight = 0.65; // Percentage of screen (0.65 = 65%)
    // ====================================

    // Apply settings based on device
    final bgTopPosition = isTablet ? tabletBgTopPosition : phoneBgTopPosition;
    final bgTopHeight = isTablet ? tabletBgTopHeight : phoneBgTopHeight;

    // Responsive values
    final isSmallScreen = screenHeight < 700;
    final kidImageHeight =
        isSmallScreen ? screenHeight * 0.25 : screenHeight * 0.30;
    final cardTopPadding = isSmallScreen ? 30.0 : 40.0;
    final horizontalPadding = isTablet ? screenWidth * 0.15 : 24.0;

    return Scaffold(
      backgroundColor: bgColor,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const StudentDashboardPage(),
              ),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        builder: (context, state) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background top image - full width on all devices
                  Positioned(
                    top: bgTopPosition,
                    left: 0,
                    right: 0,
                    child: Image.asset(
                      'assets/images/bg_top.webp',
                      fit: BoxFit.fill,
                      width: screenWidth,
                      height: screenHeight * bgTopHeight,
                    ),
                  ),

                  // Main scrollable content
                  SafeArea(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              screenHeight - MediaQuery.of(context).padding.top,
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding),
                            child: Column(
                              children: [
                                // Top spacing
                                SizedBox(height: screenHeight * 0.04),

                                // Arabic text at top
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 22,
                                      fontFamily: 'Cairo',
                                      height: 1.4,
                                    ),
                                    children: const [
                                      TextSpan(
                                        text: 'أنت على ',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                      TextSpan(
                                        text: 'خطوات قليلة',
                                        style: TextStyle(color: bgColor),
                                      ),
                                      TextSpan(
                                        text: ' من\n',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                      TextSpan(
                                        text: 'رحلتك مع القرآن الكريم',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: isSmallScreen ? 10 : 20),

                                // Login card with kid image overlapping
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.topCenter,
                                  children: [
                                    // White login card
                                    Container(
                                      margin: EdgeInsets.only(
                                          top: kidImageHeight - 5),
                                      width: double.infinity,
                                      constraints:
                                          const BoxConstraints(maxWidth: 450),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.15),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                            24, cardTopPadding, 24, 32),
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // Title
                                              const Center(
                                                child: Text(
                                                  'تسجيل دخول',
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                    color: bgColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 24),

                                              // Phone Field
                                              _buildTextField(
                                                controller: _phoneController,
                                                hintText: 'رقم الهاتف',
                                                icon: Icons.phone,
                                                keyboardType:
                                                    TextInputType.phone,
                                              ),
                                              const SizedBox(height: 14),

                                              // Password Field
                                              _buildTextField(
                                                controller: _passwordController,
                                                hintText: 'كلمة المرور',
                                                icon: Icons.lock,
                                                obscureText: _obscurePassword,
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscurePassword
                                                        ? Icons.visibility
                                                        : Icons.visibility_off,
                                                    color: Colors.grey,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _obscurePassword =
                                                          !_obscurePassword;
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(height: 10),

                                              // Forgot Password
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: TextButton(
                                                  onPressed: () {
                                                    // Implement forgot password functionality
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: const Text(
                                                    'نسيت كلمة المرور',
                                                    style: TextStyle(
                                                      color: bgColor,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 20),

                                              // Login Button
                                              SizedBox(
                                                height: 48,
                                                child: ElevatedButton(
                                                  onPressed:
                                                      state is AuthLoading
                                                          ? null
                                                          : () {
                                                              if (_formKey
                                                                  .currentState!
                                                                  .validate()) {
                                                                context
                                                                    .read<
                                                                        AuthBloc>()
                                                                    .add(
                                                                      LoginWithPhoneEvent(
                                                                        phone: _phoneController
                                                                            .text
                                                                            .trim(),
                                                                        password:
                                                                            _passwordController.text,
                                                                      ),
                                                                    );
                                                              }
                                                            },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: goldColor,
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              25),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  child: state is AuthLoading
                                                      ? const SizedBox(
                                                          width: 22,
                                                          height: 22,
                                                          child:
                                                              CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      : const Text(
                                                          'تسجيل الدخول',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Kid image - positioned above the card
                                    Positioned(
                                      top: 5,
                                      child: Image.asset(
                                        'assets/images/kid.webp',
                                        height: kidImageHeight,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ],
                                ),

                                // Bottom spacing
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 14,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(icon, color: bgColor, size: 20),
          ),
          prefixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          return null;
        },
      ),
    );
  }
}
