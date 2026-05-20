import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';
import '../main_layout.dart';
import '../admin/admin_layout.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showError('Please fill in both fields.');
      return;
    }
    if (newPass != confirmPass) {
      _showError('Passwords do not match.');
      return;
    }
    if (newPass.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPass));

      final userId = supabase.auth.currentUser!.id;
      await supabase
          .from('profiles')
          .update({'needs_password_reset': false})
          .eq('id', userId);

      if (!mounted) return;

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        final isAdmin = profile?['role'] == 'admin';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => isAdmin ? const AdminLayout() : const MainLayout(),
          ),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Error updating password: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.w(AppStyles.containerPadding)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: context.h(32)),
                  Container(
                    padding: EdgeInsets.all(context.r(12)),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset, color: AppColors.brand, size: context.r(28)),
                  ),
                  SizedBox(height: context.h(20)),
                  Text(
                    'Set Your Password',
                    style: AppStyles.displayFont.copyWith(
                      fontSize: context.sp(28),
                      fontWeight: FontWeight.bold,
                      color: context.fg,
                    ),
                  ),
                  SizedBox(height: context.h(8)),
                  Text(
                    'Your account was set up with a temporary password. Please create a new secure password to continue.',
                    style: AppStyles.bodyFont.copyWith(
                      color: context.mutedFg,
                      fontSize: context.sp(14),
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: context.h(36)),
                  _buildLabel('NEW PASSWORD'),
                  SizedBox(height: context.h(8)),
                  _buildPasswordField(_newPasswordController, _obscureNew,
                      () => setState(() => _obscureNew = !_obscureNew)),
                  SizedBox(height: context.h(20)),
                  _buildLabel('CONFIRM PASSWORD'),
                  SizedBox(height: context.h(8)),
                  _buildPasswordField(_confirmPasswordController, _obscureConfirm,
                      () => setState(() => _obscureConfirm = !_obscureConfirm)),
                  SizedBox(height: context.h(32)),
                  SizedBox(
                    width: double.infinity,
                    height: context.h(52),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(context.r(14)),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              'Set Password & Continue',
                              style: AppStyles.bodyFont.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: context.sp(15),
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) => Text(
        label,
        style: AppStyles.eyebrow.copyWith(color: context.mutedFg, letterSpacing: 1.2),
      );

  Widget _buildPasswordField(
      TextEditingController controller, bool obscure, VoidCallback toggle) {
    return SizedBox(
      height: context.h(52),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: AppStyles.bodyFont.copyWith(fontSize: context.sp(14), color: context.fg),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: AppStyles.bodyFont.copyWith(
              color: context.mutedFg, letterSpacing: 4, fontSize: context.sp(14)),
          contentPadding: EdgeInsets.symmetric(
              horizontal: context.w(16), vertical: 0),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: context.mutedFg, size: context.r(18)),
            onPressed: toggle,
          ),
          filled: true,
          fillColor: context.card,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusSm)),
            borderSide: BorderSide(color: context.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusSm)),
            borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
          ),
        ),
      ),
    );
  }
}
