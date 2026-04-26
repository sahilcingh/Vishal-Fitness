import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../main_layout.dart';
import '../../main.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool isSignIn = true;
  bool isLoading = false;

  // OTP Verification State
  bool isOtpSent = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --- Step 1: Initial Sign In / Sign Up Logic ---
  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        (!isSignIn && (name.isEmpty || phone.isEmpty))) {
      _showError('Please fill in all fields.');
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isSignIn) {
        // Sign In Flow
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        _navigateToDashboard();
      } else {
        // Sign Up Flow - Saves Name and Phone to user metadata
        await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name, 'phone': phone},
        );

        // Transition to OTP UI
        if (mounted) {
          setState(() {
            isOtpSent = true;
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent to your email.'),
              backgroundColor: AppColors.brand,
            ),
          );
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('An unexpected error occurred.');
    } finally {
      if (mounted && !isOtpSent) setState(() => isLoading = false);
    }
  }

  // --- Step 2: OTP Verification Logic ---
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    final email = _emailController.text.trim();

    if (otp.isEmpty) {
      _showError('Please enter the 6-digit code.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await supabase.auth.verifyOTP(
        type: OtpType.signup,
        token: otp,
        email: email,
      );

      _navigateToDashboard();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Invalid verification code.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _navigateToDashboard() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.energy),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackgroundImage(context),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppStyles.containerPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildLogoAndEyebrow(context),
                  const SizedBox(height: 16),
                  _buildMainHeading(context),
                  const SizedBox(height: 8),
                  Text(
                    'Your streak is waiting. Let\'s pick up where you\nleft off.',
                    style: AppStyles.bodyFont.copyWith(
                      color: context.mutedFg,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Wrap in AnimatedSize so the card smoothly expands when fields are added
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: _buildAuthCard(context),
                  ),

                  const SizedBox(height: 24),
                  _buildFeaturePills(context),
                  const SizedBox(height: 20),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'VISHAL FITNESS',
                        style: AppStyles.eyebrow.copyWith(
                          color: context.mutedFg.withOpacity(0.5),
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundImage(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/vishal/signin_bg.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            context.isDark 
                ? Colors.black.withOpacity(0.6) 
                : Colors.white.withOpacity(0.4),
            context.isDark ? BlendMode.darken : BlendMode.lighten,
          ),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }
  Widget _buildLogoAndEyebrow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      size: 24,
                      color: AppColors.brand,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'VISHAL FITNESS',
                  style: GoogleFonts.anton(
                    color: context.isDark ? Colors.white : Colors.black,
                    fontSize: 28,
                    letterSpacing: 2.0,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'WELCOME BACK',
              style: AppStyles.eyebrow.copyWith(
                color: context.mutedFg,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainHeading(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(
          context,
        ).textTheme.displayLarge?.copyWith(height: 1.1, fontSize: 36),
        children: const [
          TextSpan(text: 'Sign in to '),
          TextSpan(
            text: 'continue\n',
            style: TextStyle(color: AppColors.aqua),
          ),
          TextSpan(text: 'training.'),
        ],
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.sun, AppColors.energy, AppColors.pulse],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: isOtpSent ? _buildOtpForm() : _buildStandardAuthForm(),
            ),
          ],
        ),
      ),
    );
  }

  // --- STANDARD SIGN IN / SIGN UP FORM ---
  Widget _buildStandardAuthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        // Custom Tab Toggle
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: context.bg,
            borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => isSignIn = true),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isSignIn ? AppColors.gradientBrand : null,
                      borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign in',
                      style: AppStyles.bodyFont.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSignIn
                            ? context.primaryFg
                            : context.mutedFg,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => isSignIn = false),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: !isSignIn ? AppColors.gradientBrand : null,
                      borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Sign up',
                      style: AppStyles.bodyFont.copyWith(
                        fontWeight: FontWeight.w600,
                        color: !isSignIn
                            ? context.primaryFg
                            : context.mutedFg,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- Extra Fields for Sign Up ---
        if (!isSignIn) ...[
          _buildInputLabel('FULL NAME'),
          _buildTextField(_nameController, 'Mara Voss', TextInputType.name),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInputLabel('PHONE NUMBER'),
              // Subtle hint for the future WhatsApp feature
              Row(
                children: [
                  Icon(
                    Icons.mark_chat_unread_outlined,
                    size: 12,
                    color: context.mutedFg,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'WhatsApp verify coming soon',
                    style: AppStyles.eyebrow.copyWith(
                      color: context.mutedFg,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildTextField(
            _phoneController,
            '+1 (555) 000-0000',
            TextInputType.phone,
          ),
          const SizedBox(height: 20),
        ],

        // --- Standard Fields ---
        _buildInputLabel('EMAIL'),
        _buildTextField(
          _emailController,
          'you@gym.com',
          TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),

        _buildInputLabel('PASSWORD'),
        _buildTextField(
          _passwordController,
          '••••••••',
          TextInputType.visiblePassword,
          isObscured: true,
        ),
        const SizedBox(height: 24),

        // Primary Action Button
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.gradientBrand,
            borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppStyles.radiusMd),
              ),
              disabledBackgroundColor: Colors.transparent,
            ),
            child: isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: context.primaryColor,
                      strokeWidth: 3,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isSignIn ? 'Sign in' : 'Create account',
                        style: AppStyles.bodyFont.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: context.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: context.primaryColor,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Footer Link
        Center(
          child: GestureDetector(
            onTap: () => setState(() => isSignIn = !isSignIn),
            child: RichText(
              text: TextSpan(
                style: AppStyles.bodyFont.copyWith(
                  color: context.mutedFg,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: isSignIn
                        ? "Don't have an account? "
                        : "Already have an account? ",
                  ),
                  TextSpan(
                    text: isSignIn ? 'Sign up' : 'Sign in',
                    style: AppStyles.bodyFont.copyWith(
                      color: context.primaryColor,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- OTP VERIFICATION FORM ---
  Widget _buildOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pulse.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read,
                color: AppColors.pulse,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'VERIFY EMAIL',
              style: AppStyles.eyebrow.copyWith(
                color: context.fg,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "We've sent a 6-digit secure code to\n${_emailController.text}",
          style: AppStyles.bodyFont.copyWith(
            color: context.mutedFg,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),

        _buildInputLabel('VERIFICATION CODE'),
        _buildTextField(_otpController, '123456', TextInputType.number),
        const SizedBox(height: 24),

        // Verify Button
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.gradientBrand,
            borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppStyles.radiusMd),
              ),
              disabledBackgroundColor: Colors.transparent,
            ),
            child: isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: context.primaryColor,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    'Verify & Continue',
                    style: AppStyles.bodyFont.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: context.primaryColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Cancel / Back Button
        Center(
          child: TextButton(
            onPressed: () => setState(() => isOtpSent = false),
            child: Text(
              'Cancel',
              style: AppStyles.bodyFont.copyWith(
                color: context.mutedFg,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Helper Widgets ---
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: AppStyles.eyebrow.copyWith(
          color: context.mutedFg,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    TextInputType type, {
    bool isObscured = false,
  }) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: isObscured,
        style: AppStyles.bodyFont,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppStyles.bodyFont.copyWith(
            color: context.mutedFg,
            letterSpacing: isObscured ? 4 : 0,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppStyles.radiusSm),
            borderSide: BorderSide(color: context.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppStyles.radiusSm),
            borderSide: const BorderSide(color: AppColors.brand),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePills(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildIconPill(Icons.local_fire_department, AppColors.pulse, 'Streaks'),
        _buildIconPill(Icons.bolt, AppColors.aqua, 'Classes'),
        _buildIconPill(Icons.auto_awesome, AppColors.energy, 'Progress'),
      ],
    );
  }

  Widget _buildIconPill(IconData icon, Color iconColor, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
          border: Border.all(color: context.border.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppStyles.bodyFont.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
