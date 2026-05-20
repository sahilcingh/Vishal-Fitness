import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';

class AdminEditMemberScreen extends StatefulWidget {
  final String userId;
  final String subscriptionId;
  final String? initialPassId;
  final DateTime initialStartDate;
  final VoidCallback onSaved;

  const AdminEditMemberScreen({
    super.key,
    required this.userId,
    required this.subscriptionId,
    this.initialPassId,
    required this.initialStartDate,
    required this.onSaved,
  });

  @override
  State<AdminEditMemberScreen> createState() => _AdminEditMemberScreenState();
}

class _AdminEditMemberScreenState extends State<AdminEditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _timeSlotController = TextEditingController();

  String? _selectedGender;
  Map<String, dynamic>? _selectedPass;
  late DateTime _startDate;

  XFile? _pickedImage;
  Uint8List? _imageBytes;
  String? _existingPhotoUrl;

  List<Map<String, dynamic>> _passes = [];
  bool _isSubmitting = false;
  bool _isLoading = true;
  bool _passesLoading = true;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _loadProfileData();
    _fetchPasses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _timeSlotController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      final res = await supabase
          .from('profiles')
          .select('full_name, phone, gender, time_slot, photo_url')
          .eq('id', widget.userId)
          .single();
      if (mounted) {
        setState(() {
          _nameController.text = res['full_name'] as String? ?? '';
          _phoneController.text = res['phone'] as String? ?? '';
          _selectedGender = res['gender'] as String?;
          _timeSlotController.text = res['time_slot'] as String? ?? '';
          _existingPhotoUrl = res['photo_url'] as String?;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Fallback if optional columns (gender, time_slot, photo_url) don't exist yet
      try {
        final res = await supabase
            .from('profiles')
            .select('full_name, phone')
            .eq('id', widget.userId)
            .single();
        if (mounted) {
          setState(() {
            _nameController.text = res['full_name'] as String? ?? '';
            _phoneController.text = res['phone'] as String? ?? '';
            _isLoading = false;
          });
        }
      } catch (e2) {
        debugPrint('Error loading profile: $e2');
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchPasses() async {
    try {
      final response = await supabase
          .from('gym_passes')
          .select()
          .eq('is_active', true)
          .order('duration_days', ascending: true);
      if (mounted) {
        final passes = List<Map<String, dynamic>>.from(response);
        setState(() {
          _passes = passes;
          _passesLoading = false;
          if (widget.initialPassId != null) {
            _selectedPass = passes
                .where((p) => p['id'] == widget.initialPassId)
                .firstOrNull;
          }
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

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(ctx.r(20))),
        ),
        padding: EdgeInsets.all(ctx.r(20)),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: ctx.w(40),
                height: ctx.h(4),
                decoration: BoxDecoration(
                    color: ctx.border, borderRadius: BorderRadius.circular(2)),
                margin: EdgeInsets.only(bottom: ctx.h(16)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.brand),
                title: Text('Choose from Gallery',
                    style: AppStyles.bodyFont.copyWith(color: ctx.fg)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.brand),
                title: Text('Take a Photo',
                    style: AppStyles.bodyFont.copyWith(color: ctx.fg)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      final xfile = await ImagePicker()
          .pickImage(source: source, imageQuality: 70, maxWidth: 512);
      if (xfile != null && mounted) {
        final bytes = await xfile.readAsBytes();
        setState(() {
          _pickedImage = xfile;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not pick image: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
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

    setState(() => _isSubmitting = true);
    try {
      final profileUpdate = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        'time_slot': _timeSlotController.text.trim().isEmpty ? null : _timeSlotController.text.trim(),
      };

      if (_imageBytes != null && _pickedImage != null) {
        try {
          final ext = _pickedImage!.name.contains('.')
              ? _pickedImage!.name.split('.').last.toLowerCase()
              : 'jpg';
          final path = '${widget.userId}/avatar.$ext';
          await supabase.storage.from('member-photos').uploadBinary(
                path,
                _imageBytes!,
                fileOptions: const FileOptions(upsert: true),
              );
          profileUpdate['photo_url'] =
              supabase.storage.from('member-photos').getPublicUrl(path);
        } catch (_) {}
      }

      await supabase
          .from('profiles')
          .update(profileUpdate)
          .eq('id', widget.userId);

      if (_selectedPass != null) {
        await supabase.from('subscriptions').update({
          'pass_id': _selectedPass!['id'],
          'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
          'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        }).eq('id', widget.subscriptionId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member updated successfully'),
            backgroundColor: AppColors.brand,
          ),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
          'Edit Member',
          style: AppStyles.displayFont.copyWith(
            fontSize: context.sp(20),
            fontWeight: FontWeight.bold,
            color: context.fg,
          ),
        ),
      ),
      body: (_isLoading || _passesLoading)
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
                    // ── Photo ─────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: context.r(88),
                              height: context.r(88),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.brand.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: AppColors.brand.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: _imageBytes != null
                                    ? Image.memory(_imageBytes!,
                                        fit: BoxFit.cover,
                                        width: context.r(88),
                                        height: context.r(88))
                                    : _existingPhotoUrl != null
                                        ? Image.network(_existingPhotoUrl!,
                                            fit: BoxFit.cover,
                                            width: context.r(88),
                                            height: context.r(88))
                                        : Icon(Icons.person_outline,
                                            size: context.r(36),
                                            color: AppColors.brand),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: context.r(26),
                                height: context.r(26),
                                decoration: BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.bg, width: 2),
                                ),
                                child: Icon(Icons.camera_alt,
                                    size: context.r(12), color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: context.h(20)),

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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone is required';
                        if (v.trim().length != 10) return 'Enter a valid 10-digit number';
                        return null;
                      },
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
                    SizedBox(height: context.h(12)),
                    _buildField(
                      controller: _timeSlotController,
                      label: 'Time Slot (optional)',
                      hint: 'e.g. 6:00 AM - 8:00 AM',
                      icon: Icons.schedule_outlined,
                    ),

                    SizedBox(height: context.h(28)),

                    // ── Membership ────────────────────────────────
                    _sectionLabel('MEMBERSHIP'),
                    SizedBox(height: context.h(12)),
                    _buildDropdown<Map<String, dynamic>>(
                      label: 'Pass Type',
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
                        label: 'Start Date',
                        value: fmt.format(_startDate),
                        icon: Icons.calendar_today_outlined,
                        trailing: Icon(Icons.edit_calendar_outlined,
                            size: context.r(16), color: context.mutedFg),
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

                    // ── Save ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: context.h(52),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              AppColors.brand.withValues(alpha: 0.4),
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
                                    color: Colors.black, strokeWidth: 2),
                              )
                            : Text(
                                'Save Changes',
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
              color: context.mutedFg, letterSpacing: 1.5),
        ),
      );

  InputDecoration _fieldDecoration(
      {required String label, required String hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle:
          AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(12)),
      labelStyle:
          AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
      prefixIcon: Icon(icon, color: context.mutedFg, size: context.r(18)),
      filled: true,
      fillColor: context.card,
      contentPadding: EdgeInsets.symmetric(
          horizontal: context.w(16), vertical: context.h(14)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(12)),
          borderSide: BorderSide(color: context.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(12)),
          borderSide: BorderSide(color: context.border.withValues(alpha: 0.6))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(12)),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(12)),
          borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.r(12)),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
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
      style:
          AppStyles.bodyFont.copyWith(color: context.fg, fontSize: context.sp(14)),
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
      key: ValueKey(label),
      initialValue: value,
      isExpanded: true,
      decoration: _fieldDecoration(label: label, hint: '', icon: icon),
      dropdownColor: context.card,
      style:
          AppStyles.bodyFont.copyWith(color: context.fg, fontSize: context.sp(13)),
      items: items
          .map((item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item), overflow: TextOverflow.ellipsis)))
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
          horizontal: context.w(16), vertical: context.h(14)),
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
                Text(label,
                    style: AppStyles.bodyFont.copyWith(
                        color: context.mutedFg, fontSize: context.sp(11))),
                SizedBox(height: context.h(2)),
                Text(value,
                    style: AppStyles.bodyFont.copyWith(
                        color: valueColor ?? context.fg,
                        fontWeight: FontWeight.w600,
                        fontSize: context.sp(14))),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
