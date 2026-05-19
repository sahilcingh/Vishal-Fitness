import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';

class AdminAddMemberScreen extends StatefulWidget {
  const AdminAddMemberScreen({super.key});

  @override
  State<AdminAddMemberScreen> createState() => _AdminAddMemberScreenState();
}

class _AdminAddMemberScreenState extends State<AdminAddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String? _selectedGender;
  Map<String, dynamic>? _selectedPass;
  DateTime _startDate = DateTime.now();

  List<Map<String, dynamic>> _passes = [];
  bool _isSubmitting = false;
  bool _passesLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPasses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _fetchPasses() async {
    try {
      final response = await supabase
          .from('gym_passes')
          .select()
          .eq('is_active', true)
          .order('duration_days', ascending: true);
      if (mounted) {
        setState(() {
          _passes = List<Map<String, dynamic>>.from(response);
          _passesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _passesLoading = false);
    }
  }

  DateTime get _endDate {
    if (_selectedPass == null) return _startDate;
    return _startDate.add(Duration(days: _selectedPass!['duration_days'] as int));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.brand,
            onPrimary: Colors.black,
            surface: ctx.card,
            onSurface: ctx.fg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pass type.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await supabase.functions.invoke(
        'create-member',
        body: {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'gender': _selectedGender,
          'pass_id': _selectedPass!['id'],
          'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        },
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['success'] != true) {
        final msg = data?['error'] ?? 'Unknown error occurred.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      _showSuccessDialog(
        name: _nameController.text.trim(),
        email: data['email'] as String,
        password: data['temp_password'] as String,
        endDate: data['end_date'] as String,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog({
    required String name,
    required String email,
    required String password,
    required String endDate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppColors.brand, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Member Added!',
                style: AppStyles.displayFont.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ctx.fg,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name has been added successfully.',
              style: AppStyles.bodyFont.copyWith(color: ctx.fg, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildCredentialTile(ctx, 'Login Email', email),
            const SizedBox(height: 10),
            _buildCredentialTile(ctx, 'Temp Password', password),
            const SizedBox(height: 10),
            _buildCredentialTile(
              ctx,
              'Pass Expires',
              DateFormat('d MMM yyyy').format(DateTime.parse(endDate)),
              copyable: false,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sun.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.sun.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.sun, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share these credentials with the member. They can reset the password anytime using Forgot Password.',
                      style: AppStyles.bodyFont.copyWith(
                        color: AppColors.sun,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            child: Text('Add Another', style: TextStyle(color: ctx.mutedFg)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialTile(BuildContext context, String label, String value,
      {bool copyable = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: 9),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppStyles.bodyFont.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: context.fg,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Icon(Icons.copy_outlined, size: 16, color: context.mutedFg),
            ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    setState(() {
      _selectedGender = null;
      _selectedPass = null;
      _startDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Add Member',
          style: AppStyles.displayFont.copyWith(
            fontSize: context.sp(20),
            fontWeight: FontWeight.bold,
            color: context.fg,
          ),
        ),
      ),
      body: _passesLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.w(AppStyles.containerPadding),
                  context.h(8),
                  context.w(AppStyles.containerPadding),
                  context.h(40),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Personal Details ──────────────────────────
                    _sectionLabel('PERSONAL DETAILS'),
                    SizedBox(height: context.h(12)),
                    _buildField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'e.g. Rahul Sharma',
                      icon: Icons.person_outline,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    SizedBox(height: context.h(12)),
                    _buildField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: 'e.g. 9876543210',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone is required';
                        if (v.trim().length < 10) return 'Enter a valid 10-digit number';
                        return null;
                      },
                    ),
                    SizedBox(height: context.h(12)),
                    _buildField(
                      controller: _emailController,
                      label: 'Email (optional)',
                      hint: 'Leave blank to auto-generate',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: context.h(12)),
                    _buildDropdown<String>(
                      label: 'Gender (optional)',
                      icon: Icons.people_outline,
                      value: _selectedGender,
                      items: const ['Male', 'Female', 'Other'],
                      itemLabel: (g) => g,
                      onChanged: (v) => setState(() => _selectedGender = v),
                    ),

                    SizedBox(height: context.h(28)),

                    // ── Membership ────────────────────────────────
                    _sectionLabel('MEMBERSHIP'),
                    SizedBox(height: context.h(12)),
                    _buildDropdown<Map<String, dynamic>>(
                      label: 'Pass Type *',
                      icon: Icons.local_activity_outlined,
                      value: _selectedPass,
                      items: _passes,
                      itemLabel: (p) =>
                          '${p['name']}  ·  ₹${p['price']}  ·  ${p['duration_days']} days',
                      onChanged: (v) => setState(() => _selectedPass = v),
                    ),
                    SizedBox(height: context.h(12)),
                    GestureDetector(
                      onTap: _pickStartDate,
                      child: _buildInfoTile(
                        label: 'Start Date *',
                        value: fmt.format(_startDate),
                        icon: Icons.calendar_today_outlined,
                        trailing: Icon(
                          Icons.edit_calendar_outlined,
                          size: context.r(16),
                          color: context.mutedFg,
                        ),
                      ),
                    ),
                    if (_selectedPass != null) ...[
                      SizedBox(height: context.h(12)),
                      _buildInfoTile(
                        label: 'End Date (auto-calculated)',
                        value: fmt.format(_endDate),
                        icon: Icons.event_available_outlined,
                        valueColor: AppColors.brand,
                      ),
                    ],

                    SizedBox(height: context.h(36)),

                    // ── Submit ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: context.h(52),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.r(14)),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Add Member',
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
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: EdgeInsets.only(bottom: context.h(2)),
        child: Text(
          label,
          style: AppStyles.eyebrow.copyWith(
            color: context.mutedFg,
            letterSpacing: 1.5,
          ),
        ),
      );

  InputDecoration _fieldDecoration({required String label, required String hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(12)),
      labelStyle: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
      prefixIcon: Icon(icon, color: context.mutedFg, size: context.r(18)),
      filled: true,
      fillColor: context.card,
      contentPadding: EdgeInsets.symmetric(
        horizontal: context.w(16),
        vertical: context.h(14),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.r(12)),
        borderSide: BorderSide(color: context.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.r(12)),
        borderSide: BorderSide(color: context.border.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.r(12)),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.r(12)),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.r(12)),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: AppStyles.bodyFont.copyWith(color: context.fg, fontSize: context.sp(14)),
      decoration: _fieldDecoration(label: label, hint: hint, icon: icon),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: _fieldDecoration(label: label, hint: '', icon: icon),
      dropdownColor: context.card,
      style: AppStyles.bodyFont.copyWith(color: context.fg, fontSize: context.sp(13)),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    Widget? trailing,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(16),
        vertical: context.h(14),
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(context.r(12)),
        border: Border.all(color: context.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.mutedFg, size: context.r(18)),
          SizedBox(width: context.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppStyles.bodyFont.copyWith(
                    color: context.mutedFg,
                    fontSize: context.sp(11),
                  ),
                ),
                SizedBox(height: context.h(2)),
                Text(
                  value,
                  style: AppStyles.bodyFont.copyWith(
                    color: valueColor ?? context.fg,
                    fontWeight: FontWeight.w600,
                    fontSize: context.sp(14),
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
