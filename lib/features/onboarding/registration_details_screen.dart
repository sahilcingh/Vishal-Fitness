/// GEMINI: DO NOT change any hardcoded values in this file. 
/// Always use responsive utilities (context.w, context.h, context.sp, context.r) 
/// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../main_layout.dart';
import '../../main.dart'; // For Supabase

class RegistrationDetailsScreen extends StatefulWidget {
  final int? durationDays;
  final double? price;
  final String? passName;
  final String? prefillName;
  final String? prefillPhone;
  final String? prefillEmail;
  final String? prefillPassword;

  const RegistrationDetailsScreen({
    super.key,
    this.durationDays,
    this.price,
    this.passName,
    this.prefillName,
    this.prefillPhone,
    this.prefillEmail,
    this.prefillPassword,
  });

  @override
  State<RegistrationDetailsScreen> createState() => _RegistrationDetailsScreenState();
}

class _RegistrationDetailsScreenState extends State<RegistrationDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isOtpSent = false;

  // Personal Info
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // Fitness Info
  String? _selectedGender;
  String? _selectedGoal;
  String? _selectedActivityLevel;
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _goals = ['Weight Loss', 'Muscle Gain', 'Endurance', 'Stay Fit'];
  final List<String> _activityLevels = ['Sedentary', 'Lightly Active', 'Active', 'Very Active'];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.prefillName ?? '';
    _phoneController.text = widget.prefillPhone ?? '';
    _emailController.text = widget.prefillEmail ?? '';
    _passwordController.text = widget.prefillPassword ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.energy),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedGender == null || _selectedGoal == null || _selectedActivityLevel == null) {
      _showError('Please fill all dropdown selections');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      // Check if email already exists before trying to sign up
      final bool emailExists = await supabase.rpc(
        'check_email_exists',
        params: {'email_to_check': email},
      );

      if (emailExists) {
        _showError('This email is already registered. Please sign in instead.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Sign Up Flow - Saves Name and Phone to user metadata
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'phone': phone},
      );

      if (mounted) {
        setState(() {
          _isOtpSent = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent to your email.'),
            backgroundColor: AppColors.brand,
          ),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtpAndSubscribe() async {
    final otp = _otpController.text.trim();
    final email = _emailController.text.trim();

    if (otp.isEmpty) {
      _showError('Please enter the 6-digit code.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verify OTP
      final response = await supabase.auth.verifyOTP(
        type: OtpType.signup,
        token: otp,
        email: email,
      );

      final user = response.user;
      if (user == null) throw Exception("Verification failed.");

      // 2. Save Fitness Profile Data
      try {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'gender': _selectedGender,
          'age': int.tryParse(_ageController.text),
          'weight': double.tryParse(_weightController.text),
          'height': double.tryParse(_heightController.text),
          'fitness_goal': _selectedGoal,
          'activity_level': _selectedActivityLevel,
          'role': 'member', // Default role
        });
      } catch (profileError) {
        debugPrint('Warning: Profile extra data not saved (schema missing columns?): $profileError');
      }

      // 3. Create Subscription if a pass was selected
      if (widget.durationDays != null && widget.price != null) {
        // Find or create the pass in gym_passes
        final passRes = await supabase.from('gym_passes')
            .select('id')
            .eq('duration_days', widget.durationDays!)
            .eq('price', widget.price!)
            .maybeSingle();
            
        String passId;
        if (passRes != null) {
          passId = passRes['id'];
        } else {
          // Insert a new one
          final newPass = await supabase.from('gym_passes').insert({
            'name': widget.passName ?? '${widget.durationDays} Days Pass',
            'duration_days': widget.durationDays,
            'price': widget.price,
            'features': [],
            'is_active': true,
          }).select('id').single();
          passId = newPass['id'];
        }

        final startDate = DateTime.now();
        final endDate = startDate.add(Duration(days: widget.durationDays!));

        await supabase.from('subscriptions').insert({
          'user_id': user.id,
          'pass_id': passId,
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'amount_paid': widget.price,
          'status': 'active',
        });
      }

      // 4. Navigate to Dashboard
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
      setState(() => _isLoading = false);
    } catch (e) {
      _showError('Error during verification: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.fg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.w(AppStyles.containerPadding)),
          child: _isOtpSent ? _buildOtpSection() : _buildRegistrationForm(),
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create your account',
            style: AppStyles.displayFont.copyWith(
              fontSize: context.sp(28),
              fontWeight: FontWeight.bold,
              color: context.fg,
            ),
          ),
          SizedBox(height: context.h(8)),
          Text(
            'We use this data to recommend exercises and tailor your gym experience.',
            style: AppStyles.bodyFont.copyWith(
              fontSize: context.sp(14),
              color: context.mutedFg,
            ),
          ),
          SizedBox(height: context.h(32)),
          
          Text('BASIC INFO', style: AppStyles.eyebrow.copyWith(color: context.mutedFg)),
          SizedBox(height: context.h(16)),
          _buildTextField(label: 'Full Name', controller: _nameController, keyboardType: TextInputType.name),
          SizedBox(height: context.h(16)),
          _buildTextField(label: 'Phone Number', controller: _phoneController, keyboardType: TextInputType.phone),
          SizedBox(height: context.h(16)),
          _buildTextField(label: 'Email Address', controller: _emailController, keyboardType: TextInputType.emailAddress),
          SizedBox(height: context.h(16)),
          _buildTextField(label: 'Password', controller: _passwordController, keyboardType: TextInputType.visiblePassword, isObscured: true),
          
          SizedBox(height: context.h(32)),
          Text('FITNESS PROFILE', style: AppStyles.eyebrow.copyWith(color: context.mutedFg)),
          SizedBox(height: context.h(16)),
          
          _buildDropdownField(
            label: 'Gender',
            value: _selectedGender,
            items: _genders,
            onChanged: (val) => setState(() => _selectedGender = val),
          ),
          SizedBox(height: context.h(16)),
          
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Age',
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  suffixText: 'yrs',
                ),
              ),
              SizedBox(width: context.w(16)),
              Expanded(
                child: _buildTextField(
                  label: 'Weight',
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  suffixText: 'kg',
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(16)),
          
          _buildTextField(
            label: 'Height',
            controller: _heightController,
            keyboardType: TextInputType.number,
            suffixText: 'cm',
          ),
          SizedBox(height: context.h(16)),

          _buildDropdownField(
            label: 'Fitness Goal',
            value: _selectedGoal,
            items: _goals,
            onChanged: (val) => setState(() => _selectedGoal = val),
          ),
          SizedBox(height: context.h(16)),

          _buildDropdownField(
            label: 'Activity Level',
            value: _selectedActivityLevel,
            items: _activityLevels,
            onChanged: (val) => setState(() => _selectedActivityLevel = val),
          ),
          SizedBox(height: context.h(48)),

          SizedBox(
            width: double.infinity,
            height: context.h(54),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.gradientBrand,
                borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.3),
                    blurRadius: context.r(12),
                    offset: Offset(0, context.h(4)),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Text(
                        'Proceed to Verify',
                        style: AppStyles.bodyFont.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: context.sp(16),
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(height: context.h(24)),
        ],
      ),
    );
  }

  Widget _buildOtpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: context.h(32)),
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.r(8)),
              decoration: BoxDecoration(
                color: AppColors.pulse.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mark_email_read, color: AppColors.pulse, size: context.r(24)),
            ),
            SizedBox(width: context.w(12)),
            Text(
              'VERIFY EMAIL',
              style: AppStyles.eyebrow.copyWith(color: context.fg, fontSize: context.sp(16)),
            ),
          ],
        ),
        SizedBox(height: context.h(16)),
        Text(
          "We've sent a 6-digit secure code to\n${_emailController.text}",
          style: AppStyles.bodyFont.copyWith(color: context.mutedFg, height: 1.5),
        ),
        SizedBox(height: context.h(32)),

        _buildTextField(
          label: 'VERIFICATION CODE',
          controller: _otpController,
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: context.h(32)),

        SizedBox(
          width: double.infinity,
          height: context.h(54),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.gradientBrand,
              borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtpAndSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd))),
              ),
              child: _isLoading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Text(
                      'Verify & Complete',
                      style: AppStyles.bodyFont.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: context.sp(16),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? suffixText,
    bool isObscured = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppStyles.eyebrow.copyWith(color: context.fg)),
        SizedBox(height: context.h(8)),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isObscured,
          style: AppStyles.bodyFont.copyWith(color: context.fg),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.card,
            suffixText: suffixText,
            suffixStyle: AppStyles.bodyFont.copyWith(color: context.mutedFg),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
              borderSide: BorderSide(color: context.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
              borderSide: const BorderSide(color: AppColors.brand, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(14)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppStyles.eyebrow.copyWith(color: context.fg)),
        SizedBox(height: context.h(8)),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: context.card,
          icon: Icon(Icons.keyboard_arrow_down, color: context.mutedFg),
          style: AppStyles.bodyFont.copyWith(color: context.fg),
          decoration: InputDecoration(
            filled: true,
            fillColor: context.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
              borderSide: BorderSide(color: context.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
              borderSide: BorderSide(color: context.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
              borderSide: const BorderSide(color: AppColors.brand, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(14)),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
