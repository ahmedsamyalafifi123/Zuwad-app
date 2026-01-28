import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
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
  static const Color goldColor = Color(0xFFF7BF00);

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
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // ========== EASY CONTROLS ==========
    // Phone bg_top settings
    const double phoneBgTopPosition = 0;
    const double phoneBgTopHeight = 0.65;

    // Tablet bg_top settings
    const double tabletBgTopPosition = 0;
    const double tabletBgTopHeight = 0.85;
    // ====================================

    // Apply settings based on device
    final bgTopPosition = isTablet ? tabletBgTopPosition : phoneBgTopPosition;
    final bgTopHeight = isTablet ? tabletBgTopHeight : phoneBgTopHeight;

    // Responsive values
    final isSmallScreen = screenHeight < 700;

    // Kid image height - separate for phone and tablet
    final double phoneKidHeight =
        isSmallScreen ? screenHeight * 0.22 : screenHeight * 0.28;
    const double tabletKidHeightPercent = 0.50;
    final kidImageHeight =
        isTablet ? screenHeight * tabletKidHeightPercent : phoneKidHeight;

    final cardTopPadding = isSmallScreen ? 25.0 : 35.0;
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

                  // Main content
                  SafeArea(
                    child: _buildContent(
                      context: context,
                      state: state,
                      screenHeight: screenHeight,
                      screenWidth: screenWidth,
                      isSmallScreen: isSmallScreen,
                      isTablet: isTablet,
                      keyboardOpen: keyboardOpen,
                      kidImageHeight: kidImageHeight,
                      cardTopPadding: cardTopPadding,
                      horizontalPadding: horizontalPadding,
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

  Widget _buildContent({
    required BuildContext context,
    required AuthState state,
    required double screenHeight,
    required double screenWidth,
    required bool isSmallScreen,
    required bool isTablet,
    required bool keyboardOpen,
    required double kidImageHeight,
    required double cardTopPadding,
    required double horizontalPadding,
  }) {
    Widget content = Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisSize: keyboardOpen ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Top spacing - smaller when not scrolling
            SizedBox(height: keyboardOpen ? 10 : screenHeight * 0.02),

            // Arabic text at top
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 20,
                  fontFamily: 'Qatar',
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                children: const [
                  TextSpan(
                    text: 'أنت على بعد ',
                    style: TextStyle(color: Colors.black),
                  ),
                  TextSpan(
                    text: 'خطوات قليلة',
                    style: TextStyle(
                      color: bgColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' \n من رحلتك مع أكاديمية زوّاد',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
            ),

            SizedBox(height: isSmallScreen ? 5 : 10),

            // Login card with kid image overlapping
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // White login card
                Container(
                  margin: EdgeInsets.only(top: kidImageHeight - 5),
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 450),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.50),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, cardTopPadding, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title with underline
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontFamily: 'Qatar',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 140,
                                  height: 1,
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 0, 0, 0),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Phone Field
                          _buildTextField(
                            controller: _phoneController,
                            hintText: 'رقم الهاتف',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),

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
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'نسيت كلمة المرور',
                                style: TextStyle(
                                  color: bgColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Login Button
                          CustomButton(
                            text: 'تسجيل الدخول',
                            onPressed: state is AuthLoading
                                ? () {} // pass empty logic or handle in CustomButton via isLoading
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      context.read<AuthBloc>().add(
                                            LoginWithPhoneEvent(
                                              phone:
                                                  _phoneController.text.trim(),
                                              password:
                                                  _passwordController.text,
                                            ),
                                          );
                                    }
                                  },
                            isLoading: state is AuthLoading,
                            backgroundColor: goldColor,
                            // Text is black in original, but foreground was white.
                            // CustomButton uses textColor for foreground.
                            // If we want black text, we should pass black.
                            textColor: Colors.black,
                            borderRadius: 22,
                            // Inherit responsive height/padding from CustomButton
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
          ],
        ),
      ),
    );

    // Always allow scrolling when content overflows
    return SingleChildScrollView(
      child: content,
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey[500],
          fontSize: 13,
        ),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Icon(icon, color: bgColor, size: 18),
        ),
        prefixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'هذا الحقل مطلوب';
        }
        return null;
      },
    );
  }
}
