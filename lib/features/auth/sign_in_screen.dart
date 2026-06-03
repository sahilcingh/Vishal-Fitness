import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../main_layout.dart';
import '../admin/admin_layout.dart';
import 'change_password_screen.dart';
import '../../main.dart';

/// Sign In Screen with dynamic layout.
/// GEMINI: DO NOT revert these dynamic values (context.w, context.h, context.sp, context.r)
/// to hardcoded pixels. This ensures the app works on all devices.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool isLoading = false;
  bool isAdminMode = false;

  // OTP Verification State
  bool isForgotPasswordOtpSent = false;

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // --- Step 1: Initial Sign In / Sign Up Logic ---
  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    setState(() => isLoading = true);
    try {
      String signinEmail = email;

      // Allow members to sign in with 10-digit phone number
      if (!isAdminMode) {
        final onlyDigits = email.replaceAll(RegExp(r'[^0-9]'), '');
        if (onlyDigits.length == 10 && !email.contains('@')) {
          final found = await supabase.rpc(
            'get_email_by_phone',
            params: {'phone_input': onlyDigits},
          ) as String?;
          if (found == null || found.isEmpty) {
            _showError('No account found for this phone number.');
            setState(() => isLoading = false);
            return;
          }
          signinEmail = found;
        }
      }

      await supabase.auth.signInWithPassword(
        email: signinEmail,
        password: password,
      );
      await _navigateToDashboard();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address first to reset password.');
      return;
    }

    setState(() => isLoading = true);
    try {
      final bool emailExists = await supabase.rpc(
        'check_email_exists',
        params: {'email_to_check': email},
      );

      if (!emailExists) {
        _showError('This email is not registered.');
        return;
      }

      await supabase.auth.resetPasswordForEmail(email);
      setState(() {
        isForgotPasswordOtpSent = true;
      });
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Error processing request: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _verifyForgotPasswordOtp() async {
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final email = _emailController.text.trim();

    if (otp.isEmpty || newPassword.isEmpty) {
      _showError('Please enter the 6-digit code and a new password.');
      return;
    }

    if (newPassword.length < 6) {
      _showError('Password must be at least 6 characters long.');
      return;
    }

    if (!RegExp(r'[!@#\$&*~`%^()_\-+={}\[\]|\\:;"<>,.?/]').hasMatch(newPassword)) {
      _showError('Password must contain at least one special character.');
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Verify OTP for recovery
      await supabase.auth.verifyOTP(
        type: OtpType.recovery,
        token: otp,
        email: email,
      );

      // 2. Update Password
      await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.r(20)),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.brand,
                  size: context.w(24),
                ),
                SizedBox(width: context.w(8)),
                Text(
                  'Success',
                  style: AppStyles.displayFont.copyWith(
                    fontSize: context.sp(20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Password updated successfully. You can now sign in.',
              style: AppStyles.bodyFont.copyWith(
                fontSize: context.sp(14),
                color: context.fg,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    isForgotPasswordOtpSent = false;
                    _passwordController.clear();
                    _otpController.clear();
                    _newPasswordController.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(12)),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Invalid verification code or error updating password.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _navigateToDashboard() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profile = await supabase
            .from('profiles')
            .select('role, needs_password_reset')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          final isRoleAdmin = profile?['role'] == 'admin';

          if (isAdminMode && !isRoleAdmin) {
            await supabase.auth.signOut();
            _showError('Access denied. Admin privileges required.');
            return;
          }

          final needsReset = profile?['needs_password_reset'] as bool? ?? false;
          if (!isRoleAdmin && needsReset) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
            return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  isRoleAdmin ? const AdminLayout() : const MainLayout(),
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error checking user role.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.r(20)),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.energy,
                size: context.w(24),
              ),
              SizedBox(width: context.w(8)),
              Text(
                'Notice',
                style: AppStyles.displayFont.copyWith(
                  fontSize: context.sp(20),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: AppStyles.bodyFont.copyWith(
              fontSize: context.sp(14),
              color: context.fg,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.r(12)),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _buildBackground(context, key: ValueKey(isAdminMode)),
          ),
          SafeArea(
            child: screenWidth > 800
                ? _buildWideLayout(context)
                : _buildNarrowLayout(context),
          ),
        ],
      ),
    );
  }

  // Wide (web/tablet) layout: left = branding, right = form card
  Widget _buildWideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.w(48),
              vertical: context.h(32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogoAndEyebrow(context),
                SizedBox(height: context.h(32)),
                _buildMainHeading(context),
                SizedBox(height: context.h(16)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isAdminMode
                        ? 'Enter secure credentials to access the gym command center and manage operations.'
                        : 'Your streak is waiting. Let\'s pick up where you left off.',
                    key: ValueKey(isAdminMode),
                    style: AppStyles.bodyFont.copyWith(
                      color: context.mutedFg,
                      height: 1.5,
                      fontSize: context.sp(15),
                    ),
                  ),
                ),
                SizedBox(height: context.h(36)),
                _buildWideHighlights(context),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildFeaturePills(context, key: ValueKey(isAdminMode)),
                ),
                SizedBox(height: context.h(16)),
                _buildAdminToggle(context),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 440,
          child: Container(
            decoration: BoxDecoration(
              color: context.isDark || isAdminMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.015),
              border: Border(
                left: BorderSide(color: context.border.withValues(alpha: 0.4)),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(context.w(32)),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  child: _buildAuthCard(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Narrow (mobile) layout: original stacked layout
  Widget _buildNarrowLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: context.w(AppStyles.containerPadding),
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(height: context.h(16)),
                  _buildLogoAndEyebrow(context),
                  SizedBox(height: context.h(16)),
                  _buildMainHeading(context),
                  SizedBox(height: context.h(8)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isAdminMode
                          ? 'Enter secure credentials to access the gym command center and manage operations.'
                          : 'Your streak is waiting. Let\'s pick up where you\nleft off.',
                      key: ValueKey(isAdminMode),
                      style: AppStyles.bodyFont.copyWith(
                        color: context.mutedFg,
                        height: 1.5,
                        fontSize: context.sp(14),
                      ),
                    ),
                  ),
                  SizedBox(height: context.h(24)),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: _buildAuthCard(context),
                  ),
                  SizedBox(height: context.h(24)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildFeaturePills(
                      context,
                      key: ValueKey(isAdminMode),
                    ),
                  ),
                ]),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(AppStyles.containerPadding),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(height: context.h(20)),
                    _buildAdminToggle(context),
                    SizedBox(height: context.h(16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context, {Key? key}) {
    final bool useDark = context.isDark || isAdminMode;
    final bgColor = useDark ? AppColors.darkBackground : AppColors.lightBackground;
    final gradient = isAdminMode ? AppColors.gradientCool : AppColors.gradientBrand;
    final orbPrimary = isAdminMode ? AppColors.aqua : AppColors.brand;
    final orbSecondary = isAdminMode ? AppColors.pulse : AppColors.energy;

    return Container(
      key: key,
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      child: Stack(
        children: [
          // Soft orb top-right
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    orbPrimary.withValues(alpha: useDark ? 0.18 : 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Soft orb bottom-left
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    orbSecondary.withValues(alpha: useDark ? 0.13 : 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Left accent stripe
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(gradient: gradient),
            ),
          ),
        ],
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
              borderRadius: BorderRadius.circular(context.r(10)),
              child: isAdminMode
                  ? Container(
                      width: context.w(44),
                      height: context.w(44),
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientCool,
                        borderRadius: BorderRadius.circular(context.r(10)),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings,
                        size: context.w(24),
                        color: Colors.white,
                      ),
                    )
                  : Image.asset(
                      'assets/icon.png',
                      width: context.w(44),
                      height: context.w(44),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: context.w(44),
                          height: context.w(44),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(context.r(10)),
                          ),
                          child: Icon(
                            Icons.fitness_center,
                            size: context.w(24),
                            color: AppColors.brand,
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(width: context.w(12)),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isAdminMode ? 'STAFF PORTAL' : 'VISHAL FITNESS',
                  style: GoogleFonts.anton(
                    color: isAdminMode || context.isDark
                        ? Colors.white
                        : Colors.black,
                    fontSize: context.sp(28),
                    letterSpacing: 2.0,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(24)),
        Row(
          children: [
            Container(
              width: context.w(6),
              height: context.w(6),
              decoration: BoxDecoration(
                color: isAdminMode ? AppColors.aqua : AppColors.brand,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: context.w(8)),
            Flexible(
              child: Text(
                isAdminMode ? 'SECURE ACCESS' : 'WELCOME BACK',
                style: AppStyles.eyebrow.copyWith(
                  color: context.mutedFg,
                  fontSize: context.sp(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainHeading(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: RichText(
        key: ValueKey(isAdminMode),
        text: TextSpan(
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            height: 1.1,
            fontSize: context.sp(36),
            color: isAdminMode
                ? Colors.white
                : (context.isDark ? Colors.white : Colors.black),
          ),
          children: isAdminMode
              ? const [
                  TextSpan(text: 'Admin Command\n'),
                  TextSpan(
                    text: 'Center.',
                    style: TextStyle(color: AppColors.aqua),
                  ),
                ]
              : const [
                  TextSpan(text: 'Sign in to '),
                  TextSpan(
                    text: 'continue\n',
                    style: TextStyle(color: AppColors.aqua),
                  ),
                  TextSpan(text: 'training.'),
                ],
        ),
      ),
    );
  }

  Widget _buildAuthCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: isAdminMode
            ? Border.all(color: AppColors.aqua.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: context.h(4),
                decoration: BoxDecoration(
                  gradient: isAdminMode
                      ? AppColors.gradientCool
                      : const LinearGradient(
                          colors: [
                            AppColors.sun,
                            AppColors.energy,
                            AppColors.pulse,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(context.w(24)),
              child: isForgotPasswordOtpSent
                  ? _buildForgotPasswordForm()
                  : _buildStandardAuthForm(),
            ),
          ],
        ),
      ),
    );
  }

  // --- SIGN IN FORM ---
  Widget _buildStandardAuthForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: context.h(4)),

        // Admin Mode Header
        if (isAdminMode) ...[
          Row(
            children: [
              Icon(Icons.shield_outlined, color: AppColors.aqua, size: context.w(18)),
              SizedBox(width: context.w(8)),
              Flexible(
                child: Text(
                  'AUTHORIZED PERSONNEL ONLY',
                  style: AppStyles.eyebrow.copyWith(color: AppColors.aqua, fontSize: context.sp(10)),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(20)),
        ],

        // Email / Phone field
        _buildInputLabel(isAdminMode ? 'ADMIN EMAIL' : 'EMAIL OR PHONE'),
        _buildTextField(
          _emailController,
          isAdminMode ? 'admin@yourgym.com' : 'Email or 10-digit phone',
          TextInputType.emailAddress,
        ),
        SizedBox(height: context.h(20)),

        // Password field
        _buildInputLabel(isAdminMode ? 'MASTER PASSWORD' : 'PASSWORD'),
        _buildTextField(
          _passwordController,
          '••••••••',
          TextInputType.visiblePassword,
          isObscured: true,
        ),

        if (isAdminMode) ...[
          SizedBox(height: context.h(12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.fingerprint, color: context.mutedFg, size: context.w(12)),
              SizedBox(width: context.w(4)),
              Flexible(
                child: Text(
                  'Biometrics enabled',
                  style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(9)),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(12)),
        ] else ...[
          SizedBox(height: context.h(12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: GestureDetector(
                  onTap: _handleForgotPassword,
                  child: Text(
                    'Forgot Password?',
                    style: AppStyles.bodyFont.copyWith(
                      color: AppColors.brand,
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(12)),
        ],

        // Sign In Button
        Container(
          width: double.infinity,
          height: context.h(52),
          decoration: BoxDecoration(
            gradient: isAdminMode ? AppColors.gradientCool : AppColors.gradientBrand,
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
              ),
              disabledBackgroundColor: Colors.transparent,
            ),
            child: isLoading
                ? SizedBox(
                    height: context.w(24),
                    width: context.w(24),
                    child: CircularProgressIndicator(color: context.primaryColor, strokeWidth: 3),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          isAdminMode ? 'Authenticate' : 'Sign in',
                          style: AppStyles.bodyFont.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: context.sp(16),
                            color: context.primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: context.w(8)),
                      Icon(
                        isAdminMode ? Icons.security : Icons.arrow_forward,
                        size: context.w(20),
                        color: context.primaryColor,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // --- FORGOT PASSWORD OTP FORM ---
  Widget _buildForgotPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: context.h(8)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(8)),
              decoration: BoxDecoration(
                color: AppColors.energy.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset,
                color: AppColors.energy,
                size: context.w(20),
              ),
            ),
            SizedBox(width: context.w(12)),
            Flexible(
              child: Text(
                'RESET PASSWORD',
                style: AppStyles.eyebrow.copyWith(
                  color: context.fg,
                  fontSize: context.sp(14),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(16)),
        Text(
          "We've sent a 6-digit secure code to\n${_emailController.text}",
          style: AppStyles.bodyFont.copyWith(
            color: context.mutedFg,
            height: 1.5,
            fontSize: context.sp(14),
          ),
        ),
        SizedBox(height: context.h(24)),

        _buildInputLabel('VERIFICATION CODE'),
        _buildTextField(
          _otpController,
          'Enter 6-digit code',
          TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        SizedBox(height: context.h(20)),

        _buildInputLabel('NEW PASSWORD'),
        _buildTextField(
          _newPasswordController,
          '••••••••',
          TextInputType.visiblePassword,
          isObscured: true,
        ),
        SizedBox(height: context.h(24)),

        // Verify & Update Button
        Container(
          width: double.infinity,
          height: context.h(52),
          decoration: BoxDecoration(
            gradient: AppColors.gradientBrand,
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _verifyForgotPasswordOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  context.r(AppStyles.radiusMd),
                ),
              ),
              disabledBackgroundColor: Colors.transparent,
            ),
            child: isLoading
                ? SizedBox(
                    height: context.w(24),
                    width: context.w(24),
                    child: CircularProgressIndicator(
                      color: context.primaryColor,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    'Verify & Update',
                    style: AppStyles.bodyFont.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: context.sp(16),
                      color: context.primaryColor,
                    ),
                  ),
          ),
        ),
        SizedBox(height: context.h(16)),

        // Cancel / Back Button
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              isForgotPasswordOtpSent = false;
              _otpController.clear();
              _newPasswordController.clear();
            }),
            child: Text(
              'Cancel',
              style: AppStyles.bodyFont.copyWith(
                color: context.mutedFg,
                fontWeight: FontWeight.w500,
                fontSize: context.sp(14),
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
      padding: EdgeInsets.only(bottom: context.h(8)),
      child: Text(
        label,
        style: AppStyles.eyebrow.copyWith(
          color: context.mutedFg,
          fontSize: context.sp(10),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    TextInputType type, {
    bool isObscured = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      height: context.h(52),
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: isObscured,
        inputFormatters: inputFormatters,
        style: AppStyles.bodyFont.copyWith(
          fontSize: context.sp(14),
          color: isAdminMode ? Colors.white : context.fg,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppStyles.bodyFont.copyWith(
            color: context.mutedFg,
            letterSpacing: isObscured ? 4 : 0,
            fontSize: context.sp(14),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: context.w(16),
            vertical: 0,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusSm)),
            borderSide: BorderSide(
              color: isAdminMode
                  ? AppColors.aqua.withValues(alpha: 0.3)
                  : context.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusSm)),
            borderSide: BorderSide(
              color: isAdminMode ? AppColors.aqua : AppColors.brand,
            ),
          ),
          filled: isAdminMode,
          fillColor: isAdminMode ? Colors.white.withValues(alpha: 0.05) : null,
        ),
      ),
    );
  }

  Widget _buildFeaturePills(BuildContext context, {Key? key}) {
    if (isAdminMode) {
      return Row(
        key: key,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildIconPill(
            Icons.dashboard_customize,
            AppColors.aqua,
            'Dashboard',
          ),
          _buildIconPill(Icons.people_alt, AppColors.energy, 'Members'),
          _buildIconPill(Icons.insights, AppColors.pulse, 'Analytics'),
        ],
      );
    }

    return Row(
      key: key,
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
        margin: EdgeInsets.symmetric(horizontal: context.w(4)),
        padding: EdgeInsets.symmetric(vertical: context.h(14)),
        decoration: BoxDecoration(
          color: isAdminMode ? Colors.black.withValues(alpha: 0.4) : context.card,
          borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
          border: Border.all(
            color: isAdminMode
                ? iconColor.withValues(alpha: 0.3)
                : context.border.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(10)),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: context.w(20)),
            ),
            SizedBox(height: context.h(8)),
            Text(
              label,
              style: AppStyles.bodyFont.copyWith(
                fontSize: context.sp(11),
                fontWeight: FontWeight.w500,
                color: isAdminMode ? Colors.white70 : context.mutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideHighlights(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isAdminMode
          ? _buildAdminHighlights(context, key: const ValueKey('admin_hl'))
          : _buildMemberHighlights(context, key: const ValueKey('member_hl')),
    );
  }

  Widget _buildMemberHighlights(BuildContext context, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStatChip(context, '200+', 'Athletes', AppColors.brand),
            SizedBox(width: context.w(12)),
            _buildStatChip(context, '100/wk', 'Classes', AppColors.energy),
            SizedBox(width: context.w(12)),
            _buildStatChip(context, '4.9★', 'Rating', AppColors.aqua),
          ],
        ),
        SizedBox(height: context.h(28)),
        _buildHighlightRow(
          context,
          Icons.fitness_center,
          AppColors.brand,
          'Premium Equipment',
          'Free weights, machines & dedicated cardio zones for every goal.',
        ),
        SizedBox(height: context.h(20)),
        _buildHighlightRow(
          context,
          Icons.event_available,
          AppColors.energy,
          '100+ Classes Weekly',
          'Yoga, Zumba, HIIT & CrossFit — guided by expert trainers.',
        ),
        SizedBox(height: context.h(20)),
        _buildHighlightRow(
          context,
          Icons.qr_code_scanner,
          AppColors.aqua,
          'Instant Digital Pass',
          'Buy once, scan on arrival. No queues, no paperwork.',
        ),
      ],
    );
  }

  Widget _buildAdminHighlights(BuildContext context, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighlightRow(
          context,
          Icons.people_alt,
          AppColors.aqua,
          'Member Management',
          'Add, edit and track all gym subscriptions in one place.',
        ),
        SizedBox(height: context.h(20)),
        _buildHighlightRow(
          context,
          Icons.bar_chart,
          AppColors.energy,
          'Live Analytics',
          'Monitor revenue, attendance and expiring memberships.',
        ),
        SizedBox(height: context.h(20)),
        _buildHighlightRow(
          context,
          Icons.campaign,
          AppColors.pulse,
          'Announcements',
          'Push updates and alerts directly to all members instantly.',
        ),
      ],
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(14),
        vertical: context.h(9),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(context.r(20)),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppStyles.displayFont.copyWith(
              fontSize: context.sp(15),
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          SizedBox(width: context.w(6)),
          Text(
            label,
            style: AppStyles.bodyFont.copyWith(
              fontSize: context.sp(12),
              color: context.mutedFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(context.w(12)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(context.r(12)),
          ),
          child: Icon(icon, color: color, size: context.w(22)),
        ),
        SizedBox(width: context.w(16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppStyles.bodyFont.copyWith(
                  fontSize: context.sp(15),
                  fontWeight: FontWeight.w700,
                  color: context.fg,
                ),
              ),
              SizedBox(height: context.h(3)),
              Text(
                subtitle,
                style: AppStyles.bodyFont.copyWith(
                  fontSize: context.sp(13),
                  color: context.mutedFg,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdminToggle(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          isAdminMode = !isAdminMode;
          // Clear fields when switching modes
          _emailController.clear();
          _passwordController.clear();
        });
      },
      borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.h(8),
          horizontal: context.w(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAdminMode ? Icons.person : Icons.admin_panel_settings,
              color: context.mutedFg.withValues(alpha: 0.5),
              size: context.w(14),
            ),
            SizedBox(width: context.w(6)),
            Flexible(
              child: Text(
                isAdminMode ? 'RETURN TO MEMBER LOGIN' : 'STAFF / ADMIN ACCESS',
                style: AppStyles.eyebrow.copyWith(
                  color: context.mutedFg.withValues(alpha: 0.5),
                  letterSpacing: 2.5,
                  fontSize: context.sp(10),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
