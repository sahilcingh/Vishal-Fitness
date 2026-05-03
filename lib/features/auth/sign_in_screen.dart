import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../main_layout.dart';
import '../admin/admin_layout.dart';
import '../onboarding/programs_screen.dart';
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
  bool isSignIn = true;
  bool isLoading = false;
  bool isAdminMode = false;

  // OTP Verification State
  bool isOtpSent = false;
  bool isForgotPasswordOtpSent = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    // NEW LOGIC: Admin mode is ONLY for signing in.
    if (isAdminMode) {
      setState(() => isLoading = true);
      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        await _navigateToDashboard();
      } on AuthException catch (e) {
        _showError(e.message);
      } catch (e) {
        _showError('Error: $e');
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
      return;
    }

    // MEMBER FLOW
    if (isSignIn) {
      // Member Sign In
      setState(() => isLoading = true);
      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        await _navigateToDashboard();
      } on AuthException catch (e) {
        _showError(e.message);
      } catch (e) {
        _showError('Error: $e');
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    } else {
      // Member Sign Up
      if (name.isEmpty || phone.isEmpty) {
        _showError('Please fill in name and phone.');
        return;
      }

      final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (phoneDigits.length != 10) {
        _showError('Phone number must be exactly 10 digits.');
        return;
      }

      if (password.length < 6) {
        _showError('Password must be at least 6 characters long.');
        return;
      }

      if (!RegExp(r'[!@#\$&*~`%^()_\-+={}\[\]|\\:;"<>,.?/]').hasMatch(password)) {
        _showError('Password must contain at least one special character.');
        return;
      }

      setState(() => isLoading = true);
      try {
        final bool emailExists = await supabase.rpc(
          'check_email_exists',
          params: {'email_to_check': email},
        );

        if (emailExists) {
          _showError(
            'This email is already registered. Please sign in instead.',
          );
          setState(() => isSignIn = true);
          return;
        }

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProgramsScreen(
              prefillName: name,
              prefillPhone: phone,
              prefillEmail: email,
              prefillPassword: password,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error checking email: $e');
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProgramsScreen(
                prefillName: name,
                prefillPhone: phone,
                prefillEmail: email,
                prefillPassword: password,
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
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

      await _navigateToDashboard();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Invalid verification code.');
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
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          final isRoleAdmin = profile?['role'] == 'admin';

          if (isAdminMode && !isRoleAdmin) {
            // Log out if they tried to log in via admin portal but aren't admin
            await supabase.auth.signOut();
            _showError('Access denied. Admin privileges required.');
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
    return Scaffold(
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _buildBackgroundImage(context, key: ValueKey(isAdminMode)),
          ),
          SafeArea(
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

                      // Wrap in AnimatedSize so the card smoothly expands when fields are added
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
        ],
      ),
    );
  }

  Widget _buildBackgroundImage(BuildContext context, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isAdminMode
                ? 'assets/vishal/gym_bg.jpg'
                : 'assets/vishal/signin_bg.jpg',
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            isAdminMode
                ? Colors.black.withOpacity(0.8)
                : (context.isDark
                      ? Colors.black.withOpacity(0.6)
                      : Colors.white.withOpacity(0.4)),
            isAdminMode
                ? BlendMode.darken
                : (context.isDark ? BlendMode.darken : BlendMode.lighten),
          ),
        ),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: isAdminMode ? 8.0 : 2.0,
          sigmaY: isAdminMode ? 8.0 : 2.0,
        ),
        child: Container(color: Colors.transparent),
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
                            color: AppColors.brand.withOpacity(0.15),
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
            Text(
              isAdminMode ? 'SECURE ACCESS' : 'WELCOME BACK',
              style: AppStyles.eyebrow.copyWith(
                color: context.mutedFg,
                fontSize: context.sp(10),
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: isAdminMode
            ? Border.all(color: AppColors.aqua.withOpacity(0.3), width: 1)
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
                  : (isOtpSent ? _buildOtpForm() : _buildStandardAuthForm()),
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
        SizedBox(height: context.h(4)),

        // Custom Tab Toggle (Hidden in Admin Mode)
        if (!isAdminMode) ...[
          Container(
            height: context.h(48),
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius: BorderRadius.circular(
                context.r(AppStyles.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => isSignIn = true),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSignIn ? AppColors.gradientBrand : null,
                        borderRadius: BorderRadius.circular(
                          context.r(AppStyles.radiusMd),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sign in',
                        style: AppStyles.bodyFont.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: context.sp(14),
                          color: isSignIn ? context.primaryFg : context.mutedFg,
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
                        borderRadius: BorderRadius.circular(
                          context.r(AppStyles.radiusMd),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Sign up',
                        style: AppStyles.bodyFont.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: context.sp(14),
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
          SizedBox(height: context.h(24)),
        ] else ...[
          // Admin Mode Header inside card
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: AppColors.aqua,
                size: context.w(18),
              ),
              SizedBox(width: context.w(8)),
              Text(
                'AUTHORIZED PERSONNEL ONLY',
                style: AppStyles.eyebrow.copyWith(
                  color: AppColors.aqua,
                  fontSize: context.sp(10),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(20)),
        ],

        // --- Extra Fields for Sign Up (User only) ---
        if (!isSignIn && !isAdminMode) ...[
          _buildInputLabel('FULL NAME'),
          _buildTextField(_nameController, 'Mara Voss', TextInputType.name),
          SizedBox(height: context.h(20)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInputLabel('PHONE NUMBER'),
              SizedBox(width: context.w(8)),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Icon(
                        Icons.mark_chat_unread_outlined,
                        size: context.w(12),
                        color: context.mutedFg,
                      ),
                      SizedBox(width: context.w(4)),
                      Text(
                        'WhatsApp verify coming soon',
                        style: AppStyles.eyebrow.copyWith(
                          color: context.mutedFg,
                          fontSize: context.sp(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildTextField(
            _phoneController,
            '9876543210',
            TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          SizedBox(height: context.h(20)),
        ],

        // --- Standard Fields ---
        _buildInputLabel(isAdminMode ? 'ADMIN EMAIL' : 'EMAIL'),
        _buildTextField(
          _emailController,
          isAdminMode ? 'admin@gym.com' : 'you@gmail.com',
          TextInputType.emailAddress,
        ),
        SizedBox(height: context.h(20)),

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
              Icon(
                Icons.fingerprint,
                color: context.mutedFg,
                size: context.w(12),
              ),
              SizedBox(width: context.w(4)),
              Text(
                'Biometrics enabled',
                style: AppStyles.eyebrow.copyWith(
                  color: context.mutedFg,
                  fontSize: context.sp(9),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(12)),
        ] else ...[
          if (isSignIn) ...[
            SizedBox(height: context.h(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _handleForgotPassword,
                  child: Text(
                    'Forgot Password?',
                    style: AppStyles.bodyFont.copyWith(
                      color: AppColors.brand,
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(12)),
          ] else ...[
            SizedBox(height: context.h(24)),
          ],
        ],

        // Primary Action Button
        Container(
          width: double.infinity,
          height: context.h(52),
          decoration: BoxDecoration(
            gradient: isAdminMode
                ? AppColors.gradientCool
                : AppColors.gradientBrand,
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleAuth,
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isAdminMode
                            ? 'Authenticate'
                            : (isSignIn ? 'Sign in' : 'Choose Pass & Sign Up'),
                        style: AppStyles.bodyFont.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: context.sp(16),
                          color: context.primaryColor,
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

        if (!isAdminMode) ...[
          SizedBox(height: context.h(20)),
          // Footer Link (User only)
          Center(
            child: GestureDetector(
              onTap: () => setState(() => isSignIn = !isSignIn),
              child: RichText(
                text: TextSpan(
                  style: AppStyles.bodyFont.copyWith(
                    color: context.mutedFg,
                    fontSize: context.sp(13),
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
                color: AppColors.energy.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_reset,
                color: AppColors.energy,
                size: context.w(20),
              ),
            ),
            SizedBox(width: context.w(12)),
            Text(
              'RESET PASSWORD',
              style: AppStyles.eyebrow.copyWith(
                color: context.fg,
                fontSize: context.sp(14),
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
          '123456',
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

  // --- OTP VERIFICATION FORM ---
  Widget _buildOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: context.h(8)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(8)),
              decoration: BoxDecoration(
                color: AppColors.pulse.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mark_email_read,
                color: AppColors.pulse,
                size: context.w(20),
              ),
            ),
            SizedBox(width: context.w(12)),
            Text(
              'VERIFY EMAIL',
              style: AppStyles.eyebrow.copyWith(
                color: context.fg,
                fontSize: context.sp(14),
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
          '123456',
          TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        SizedBox(height: context.h(24)),

        // Verify Button
        Container(
          width: double.infinity,
          height: context.h(52),
          decoration: BoxDecoration(
            gradient: AppColors.gradientBrand,
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _verifyOtp,
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
                    'Verify & Continue',
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
            onPressed: () => setState(() => isOtpSent = false),
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
                  ? AppColors.aqua.withOpacity(0.3)
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
          fillColor: isAdminMode ? Colors.white.withOpacity(0.05) : null,
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
          color: isAdminMode ? Colors.black.withOpacity(0.4) : context.card,
          borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
          border: Border.all(
            color: isAdminMode
                ? iconColor.withOpacity(0.3)
                : context.border.withOpacity(0.5),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(10)),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
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
              color: context.mutedFg.withOpacity(0.5),
              size: context.w(14),
            ),
            SizedBox(width: context.w(6)),
            Text(
              isAdminMode ? 'RETURN TO MEMBER LOGIN' : 'STAFF / ADMIN ACCESS',
              style: AppStyles.eyebrow.copyWith(
                color: context.mutedFg.withOpacity(0.5),
                letterSpacing: 2.5,
                fontSize: context.sp(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
