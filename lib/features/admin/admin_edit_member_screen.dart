import 'package:flutter/foundation.dart' show kIsWeb;
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
  final _extraDaysController = TextEditingController();
  final _emailController = TextEditingController();

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
  String? _memberEmail;
  bool _isResettingPassword = false;

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
    _extraDaysController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    try {
      // Try full profile with all optional columns
      final res = await supabase
          .from('profiles')
          .select('full_name, phone, gender, time_slot, photo_url')
          .eq('id', widget.userId)
          .maybeSingle();
      if (mounted) {
        final phone = res?['phone'] as String?;
        setState(() {
          _nameController.text = res?['full_name'] as String? ?? '';
          _phoneController.text = phone ?? '';
          _selectedGender = res?['gender'] as String?;
          _timeSlotController.text = res?['time_slot'] as String? ?? '';
          _existingPhotoUrl = res?['photo_url'] as String?;
          _isLoading = false;
        });
        _fetchMemberEmail(phone);
      }
    } catch (_) {
      // Fallback: optional columns (gender, time_slot, photo_url) may not exist
      try {
        final res = await supabase
            .from('profiles')
            .select('full_name, phone')
            .eq('id', widget.userId)
            .maybeSingle();
        if (mounted) {
          setState(() {
            _nameController.text = res?['full_name'] as String? ?? '';
            _phoneController.text = res?['phone'] as String? ?? '';
            _isLoading = false;
          });
        }
      } catch (_) {
        // Last resort: just full_name
        try {
          final res = await supabase
              .from('profiles')
              .select('full_name')
              .eq('id', widget.userId)
              .maybeSingle();
          if (mounted) {
            setState(() {
              _nameController.text = res?['full_name'] as String? ?? '';
              _isLoading = false;
            });
          }
        } catch (e) {
          debugPrint('Error loading profile: $e');
          if (mounted) setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _fetchMemberEmail(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    try {
      final email = await supabase.rpc(
        'get_email_by_phone',
        params: {'phone_input': phone.replaceAll(RegExp(r'[^0-9]'), '')},
      ) as String?;
      if (mounted) {
        setState(() => _memberEmail = email ?? '');
        _emailController.text = email ?? '';
      }
    } catch (_) {}
  }

  Future<void> _resetPassword() async {
    setState(() => _isResettingPassword = true);
    try {
      final res = await supabase.functions.invoke(
        'reset-member-password',
        body: {'user_id': widget.userId},
      );
      final data = res.data as Map<String, dynamic>?;
      if (!mounted) return;
      if (data?['success'] == true) {
        final newPass = data!['temp_password'] as String;
        _showCredentialsDialog(newPass);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data?['error'] as String? ??
              'Deploy the reset-member-password Edge Function first.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reset failed. Deploy the Edge Function first.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  void _showCredentialsDialog(String newPassword) {
    final email = _memberEmail ?? '—';
    final name = _nameController.text.trim();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.key, color: AppColors.brand, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('New Credentials',
                  style: AppStyles.displayFont.copyWith(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.bold,
                      color: ctx.fg)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share these with $name:',
                style: AppStyles.bodyFont
                    .copyWith(color: ctx.mutedFg, fontSize: context.sp(13))),
            SizedBox(height: context.h(16)),
            _credRow(ctx, 'LOGIN EMAIL', email),
            SizedBox(height: context.h(10)),
            _credRow(ctx, 'NEW PASSWORD', newPassword),
            SizedBox(height: context.h(16)),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sun.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.sun.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: AppColors.sun, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Member must change this password on first login.',
                        style: AppStyles.bodyFont.copyWith(
                            color: AppColors.sun,
                            fontSize: context.sp(11),
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
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

  Widget _credRow(BuildContext ctx, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.w(12), vertical: context.h(10)),
      decoration: BoxDecoration(
        color: ctx.bg,
        borderRadius: BorderRadius.circular(context.r(10)),
        border: Border.all(color: ctx.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppStyles.eyebrow
                        .copyWith(color: ctx.mutedFg, fontSize: context.sp(9))),
                const SizedBox(height: 3),
                Text(value,
                    style: AppStyles.bodyFont.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: context.sp(13),
                        color: ctx.fg)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Copied to clipboard'),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: Icon(Icons.copy_outlined,
                size: context.r(16), color: ctx.mutedFg),
          ),
        ],
      ),
    );
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

  int get _extraDays => int.tryParse(_extraDaysController.text.trim()) ?? 0;

  DateTime get _endDate {
    if (_selectedPass == null) return _startDate;
    return _startDate.add(Duration(days: (_selectedPass!['duration_days'] as int) + _extraDays));
  }

  Future<void> _pickImage() async {
    ImageSource source;
    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
      final picked = await showModalBottomSheet<ImageSource>(
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
      if (picked == null) return;
      source = picked;
    }
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
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo upload failed: $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }

      // Try full update; check if any row was actually changed (0 rows = RLS blocked or missing)
      bool profileSaved = false;
      try {
        final updated = await supabase
            .from('profiles')
            .update(profileUpdate)
            .eq('id', widget.userId)
            .select('id');
        profileSaved = (updated as List).isNotEmpty;
      } catch (_) {
        // Optional columns missing — fall through to narrower update
      }

      if (!profileSaved) {
        // Try with just full_name
        try {
          final updated = await supabase
              .from('profiles')
              .update({'full_name': profileUpdate['full_name']})
              .eq('id', widget.userId)
              .select('id');
          profileSaved = (updated as List).isNotEmpty;
        } catch (_) {
          // ignore — try upsert below
        }
      }

      if (!profileSaved) {
        // Profile row missing or RLS blocking update — upsert to create/fix it
        await supabase.from('profiles').upsert({
          'id': widget.userId,
          'full_name': profileUpdate['full_name'],
        });
      }

      if (_selectedPass != null) {
        await supabase.from('subscriptions').update({
          'pass_id': _selectedPass!['id'],
          'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
          'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        }).eq('id', widget.subscriptionId);
      }

      // Update email if admin changed it
      final newEmail = _emailController.text.trim();
      if (newEmail.isNotEmpty &&
          newEmail != _memberEmail &&
          newEmail.contains('@')) {
        try {
          await supabase.functions.invoke(
            'reset-member-password',
            body: {'user_id': widget.userId, 'new_email': newEmail},
          );
          if (mounted) setState(() => _memberEmail = newEmail);
        } catch (_) {
          // Email update failed — inform admin but don't block the rest of save
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Profile saved but email update requires the reset-member-password Edge Function.'),
              backgroundColor: AppColors.energy,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
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
                    SizedBox(height: context.h(12)),
                    _buildField(
                      controller: _emailController,
                      label: 'Login Email',
                      hint: _memberEmail == null
                          ? 'Loading…'
                          : 'Member login email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    if (_memberEmail != null && _emailController.text != _memberEmail)
                      Padding(
                        padding: EdgeInsets.only(top: context.h(6)),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: context.r(12), color: AppColors.energy),
                            SizedBox(width: context.w(4)),
                            Expanded(
                              child: Text(
                                'Email will be updated when you save.',
                                style: AppStyles.eyebrow.copyWith(
                                    color: AppColors.energy,
                                    fontSize: context.sp(9)),
                              ),
                            ),
                          ],
                        ),
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoTile(
                              label: 'End Date (auto-calculated)',
                              value: fmt.format(_endDate),
                              icon: Icons.event_available_outlined,
                              valueColor: _extraDays > 0 ? AppColors.brand : AppColors.brand,
                            ),
                          ),
                          SizedBox(width: context.w(10)),
                          SizedBox(
                            width: context.w(110),
                            child: TextFormField(
                              controller: _extraDaysController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => setState(() {}),
                              style: AppStyles.bodyFont.copyWith(
                                  color: context.fg, fontSize: context.sp(14)),
                              decoration: InputDecoration(
                                labelText: 'Extra Days',
                                hintText: '0',
                                hintStyle: AppStyles.bodyFont.copyWith(
                                    color: context.mutedFg, fontSize: context.sp(12)),
                                labelStyle: AppStyles.bodyFont.copyWith(
                                    color: context.mutedFg, fontSize: context.sp(12)),
                                prefixIcon: Icon(Icons.add_circle_outline,
                                    color: context.mutedFg, size: context.r(16)),
                                filled: true,
                                fillColor: context.card,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: context.w(10), vertical: context.h(14)),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(context.r(12)),
                                    borderSide: BorderSide(color: context.border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(context.r(12)),
                                    borderSide: BorderSide(
                                        color: context.border.withValues(alpha: 0.6))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(context.r(12)),
                                    borderSide: const BorderSide(
                                        color: AppColors.brand, width: 1.5)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_extraDays > 0) ...[
                        SizedBox(height: context.h(8)),
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: context.r(13), color: AppColors.brand),
                            SizedBox(width: context.w(6)),
                            Text(
                              '+$_extraDays extra days added to membership',
                              style: AppStyles.bodyFont.copyWith(
                                  color: AppColors.brand,
                                  fontSize: context.sp(12)),
                            ),
                          ],
                        ),
                      ],
                    ],

                    SizedBox(height: context.h(28)),

                    // ── Login Credentials ─────────────────────────
                    Container(
                      padding: EdgeInsets.all(context.r(16)),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(context.r(14)),
                        border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.key_outlined,
                                  size: context.r(14), color: AppColors.brand),
                              SizedBox(width: context.w(6)),
                              Text('LOGIN CREDENTIALS',
                                  style: AppStyles.eyebrow.copyWith(
                                      color: AppColors.brand,
                                      fontSize: context.sp(10),
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                          SizedBox(height: context.h(12)),
                          // Email row
                          Row(
                            children: [
                              Icon(Icons.email_outlined,
                                  size: context.r(16), color: context.mutedFg),
                              SizedBox(width: context.w(10)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('LOGIN EMAIL',
                                        style: AppStyles.eyebrow.copyWith(
                                            color: context.mutedFg,
                                            fontSize: context.sp(9))),
                                    SizedBox(height: context.h(2)),
                                    _memberEmail == null
                                        ? Row(children: [
                                            SizedBox(
                                              width: context.r(12),
                                              height: context.r(12),
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  color: AppColors.brand),
                                            ),
                                            SizedBox(width: context.w(6)),
                                            Text('Loading…',
                                                style: AppStyles.bodyFont
                                                    .copyWith(
                                                        color: context.mutedFg,
                                                        fontSize:
                                                            context.sp(13))),
                                          ])
                                        : Text(
                                            _memberEmail!.isEmpty
                                                ? 'Not found'
                                                : _memberEmail!,
                                            style: AppStyles.bodyFont.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: context.sp(13),
                                                color: context.fg),
                                          ),
                                  ],
                                ),
                              ),
                              if (_memberEmail != null &&
                                  _memberEmail!.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                        ClipboardData(text: _memberEmail!));
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text('Email copied'),
                                      duration: Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(context.r(7)),
                                    decoration: BoxDecoration(
                                      color: context.card,
                                      borderRadius:
                                          BorderRadius.circular(context.r(8)),
                                      border:
                                          Border.all(color: context.border),
                                    ),
                                    child: Icon(Icons.copy_outlined,
                                        size: context.r(15),
                                        color: context.mutedFg),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: context.h(14)),
                          // Reset password button
                          SizedBox(
                            width: double.infinity,
                            height: context.h(44),
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isResettingPassword ? null : _resetPassword,
                              icon: _isResettingPassword
                                  ? SizedBox(
                                      width: context.r(14),
                                      height: context.r(14),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: AppColors.energy),
                                    )
                                  : Icon(Icons.lock_reset_outlined,
                                      size: context.r(16)),
                              label: Text(
                                _isResettingPassword
                                    ? 'Resetting…'
                                    : 'Reset Password & Show Credentials',
                                style: AppStyles.bodyFont.copyWith(
                                    fontSize: context.sp(13),
                                    fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.energy,
                                side: BorderSide(
                                    color:
                                        AppColors.energy.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(context.r(12))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.h(24)),

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
