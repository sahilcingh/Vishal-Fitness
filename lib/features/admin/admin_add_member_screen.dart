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
  final _discountController = TextEditingController();
  final _paidController = TextEditingController();
  final _timeSlotController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedGender;
  Map<String, dynamic>? _selectedPass;
  DateTime _startDate = DateTime.now();
  bool _isPercent = false;
  String _paymentMethod = 'Cash';
  XFile? _pickedImage;
  Uint8List? _imageBytes;

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
    _discountController.dispose();
    _paidController.dispose();
    _timeSlotController.dispose();
    _notesController.dispose();
    super.dispose();
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
                  decoration: BoxDecoration(color: ctx.border, borderRadius: BorderRadius.circular(2)),
                  margin: EdgeInsets.only(bottom: ctx.h(16)),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.brand),
                  title: Text('Choose from Gallery', style: AppStyles.bodyFont.copyWith(color: ctx.fg)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppColors.brand),
                  title: Text('Take a Photo', style: AppStyles.bodyFont.copyWith(color: ctx.fg)),
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
      final xfile = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 512);
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
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: Colors.redAccent),
        );
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

  double get _passPrice => (_selectedPass?['price'] as num?)?.toDouble() ?? 0;

  double get _discountAmount {
    final val = double.tryParse(_discountController.text.trim()) ?? 0;
    if (_isPercent) return (_passPrice * val / 100).clamp(0, _passPrice);
    return val.clamp(0, _passPrice);
  }

  double get _effectivePrice => (_passPrice - _discountAmount).clamp(0, double.infinity);

  double get _paidAmount => double.tryParse(_paidController.text.trim()) ?? 0;

  double get _balance => (_effectivePrice - _paidAmount).clamp(0, double.infinity);

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
        const SnackBar(content: Text('Please select a pass type.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Amount validation
    final rawDiscount = double.tryParse(_discountController.text.trim()) ?? 0;
    if (_isPercent && rawDiscount > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount percentage cannot exceed 100%.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (!_isPercent && rawDiscount > _passPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discount cannot exceed pass price (₹${_passPrice.toStringAsFixed(0)}).'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (_paidAmount > _effectivePrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Amount paid (₹${_paidAmount.toStringAsFixed(0)}) exceeds effective price (₹${_effectivePrice.toStringAsFixed(0)}).'), backgroundColor: Colors.redAccent),
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
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
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

      final userId = data['user_id'] as String;

      // Fetch the created subscription
      final subRes = await supabase
          .from('subscriptions')
          .select('id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      final subscriptionId = subRes['id'] as String;

      // Apply discount if any
      if (_discountAmount > 0) {
        await supabase
            .from('subscriptions')
            .update({'discount_amount': _discountAmount})
            .eq('id', subscriptionId);
      }

      // Record initial payment if any
      if (_paidAmount > 0) {
        await supabase.from('payments').insert({
          'subscription_id': subscriptionId,
          'user_id': userId,
          'amount': _paidAmount,
          'payment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'payment_method': _paymentMethod.toLowerCase(),
          'notes': _notesController.text.trim().isEmpty
              ? 'Initial payment at enrollment'
              : _notesController.text.trim(),
        });
      }

      // Upload photo + update profile extras
      final profileUpdate = <String, dynamic>{'needs_password_reset': true};
      if (_timeSlotController.text.trim().isNotEmpty) profileUpdate['time_slot'] = _timeSlotController.text.trim();
      if (_imageBytes != null && _pickedImage != null) {
        try {
          final ext = _pickedImage!.name.contains('.')
              ? _pickedImage!.name.split('.').last.toLowerCase()
              : 'jpg';
          final storagePath = '$userId/avatar.$ext';
          await supabase.storage
              .from('member-photos')
              .uploadBinary(storagePath, _imageBytes!, fileOptions: const FileOptions(upsert: true));
          profileUpdate['photo_url'] =
              supabase.storage.from('member-photos').getPublicUrl(storagePath);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo upload failed: $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
      if (profileUpdate.isNotEmpty) {
        await supabase.from('profiles').update(profileUpdate).eq('id', userId);
      }

      _showSuccessDialog(
        name: _nameController.text.trim(),
        email: data['email'] as String,
        password: data['temp_password'] as String,
        endDate: data['end_date'] as String,
        totalFee: _effectivePrice,
        paid: _paidAmount,
        balance: _balance,
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
    required double totalFee,
    required double paid,
    required double balance,
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
            const SizedBox(height: 16),
            // Payment summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ctx.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _successStat(ctx, 'TOTAL', '₹${totalFee.toStringAsFixed(0)}', ctx.fg),
                  _successStat(ctx, 'PAID', '₹${paid.toStringAsFixed(0)}', AppColors.brand),
                  _successStat(ctx, 'BALANCE', '₹${balance.toStringAsFixed(0)}',
                      balance > 0 ? AppColors.energy : AppColors.brand),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                      'Share these credentials with the member. They can reset the password anytime.',
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

  Widget _successStat(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(9))),
        SizedBox(height: context.h(4)),
        Text(value,
            style: AppStyles.displayFont.copyWith(
                fontSize: context.sp(16), fontWeight: FontWeight.bold, color: color)),
      ],
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
                Text(label.toUpperCase(),
                    style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: 9)),
                const SizedBox(height: 3),
                Text(value,
                    style: AppStyles.bodyFont.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 13, color: context.fg)),
              ],
            ),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
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
    _discountController.clear();
    _paidController.clear();
    _timeSlotController.clear();
    _notesController.clear();
    setState(() {
      _selectedGender = null;
      _selectedPass = null;
      _startDate = DateTime.now();
      _isPercent = false;
      _paymentMethod = 'Cash';
      _pickedImage = null;
      _imageBytes = null;
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
                                    ? Image.memory(_imageBytes!, fit: BoxFit.cover,
                                        width: context.r(88), height: context.r(88))
                                    : Icon(Icons.person_outline,
                                        size: context.r(36), color: AppColors.brand),
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

                    SizedBox(height: context.h(28)),

                    // ── Payment Details ───────────────────────────
                    _sectionLabel('PAYMENT DETAILS'),
                    SizedBox(height: context.h(12)),

                    // Discount type toggle
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPercent = false),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: context.h(12)),
                              decoration: BoxDecoration(
                                color: !_isPercent ? AppColors.brand : Colors.transparent,
                                borderRadius: BorderRadius.circular(context.r(10)),
                                border: Border.all(
                                    color: !_isPercent ? AppColors.brand : context.border),
                              ),
                              child: Center(
                                child: Text(
                                  '₹ Amount',
                                  style: AppStyles.bodyFont.copyWith(
                                    color: !_isPercent ? Colors.white : context.mutedFg,
                                    fontWeight: FontWeight.w600,
                                    fontSize: context.sp(13),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: context.w(10)),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPercent = true),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: context.h(12)),
                              decoration: BoxDecoration(
                                color: _isPercent ? AppColors.brand : Colors.transparent,
                                borderRadius: BorderRadius.circular(context.r(10)),
                                border: Border.all(
                                    color: _isPercent ? AppColors.brand : context.border),
                              ),
                              child: Center(
                                child: Text(
                                  '% Percent',
                                  style: AppStyles.bodyFont.copyWith(
                                    color: _isPercent ? Colors.white : context.mutedFg,
                                    fontWeight: FontWeight.w600,
                                    fontSize: context.sp(13),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.h(12)),

                    // Discount field
                    _buildField(
                      controller: _discountController,
                      label: _isPercent ? 'Discount %' : 'Discount Amount (₹)',
                      hint: _isPercent ? 'e.g. 10' : 'e.g. 200',
                      icon: Icons.local_offer_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),

                    // Price summary (shown when pass is selected)
                    if (_selectedPass != null) ...[
                      SizedBox(height: context.h(12)),
                      Container(
                        padding: EdgeInsets.all(context.r(14)),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(context.r(12)),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _priceStat(context, 'ORIGINAL',
                                '₹${_passPrice.toStringAsFixed(0)}', context.mutedFg),
                            _priceStat(context, 'DISCOUNT',
                                '-₹${_discountAmount.toStringAsFixed(0)}', AppColors.energy),
                            _priceStat(context, 'FINAL PRICE',
                                '₹${_effectivePrice.toStringAsFixed(0)}', context.fg,
                                bold: true),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: context.h(12)),

                    // Amount paid field
                    _buildField(
                      controller: _paidController,
                      label: 'Amount Paid Now (₹)',
                      hint: 'e.g. 1500',
                      icon: Icons.payments_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: context.h(12)),

                    // Payment method + notes
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: const ValueKey('payment_method'),
                            initialValue: _paymentMethod,
                            isExpanded: true,
                            decoration: _fieldDecoration(
                              label: 'Payment Method',
                              hint: '',
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                            dropdownColor: context.card,
                            style: AppStyles.bodyFont.copyWith(
                                color: context.fg, fontSize: context.sp(13)),
                            items: ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Cheque']
                                .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m, overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(() => _paymentMethod = v!),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.h(12)),
                    _buildField(
                      controller: _notesController,
                      label: 'Payment Note (optional)',
                      hint: 'e.g. Paid by father',
                      icon: Icons.note_outlined,
                    ),

                    // Paid / Balance summary (always visible)
                    SizedBox(height: context.h(12)),
                    Container(
                      padding: EdgeInsets.all(context.r(14)),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(context.r(12)),
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _priceStat(context, 'TOTAL',
                              _selectedPass != null ? '₹${_effectivePrice.toStringAsFixed(0)}' : '—',
                              context.fg),
                          _priceStat(context, 'PAID',
                              '₹${_paidAmount.toStringAsFixed(0)}', AppColors.brand),
                          _priceStat(context, 'BALANCE',
                              _selectedPass != null ? '₹${_balance.toStringAsFixed(0)}' : '—',
                              _balance > 0 ? AppColors.energy : AppColors.brand,
                              bold: true),
                        ],
                      ),
                    ),

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
                                    color: Colors.black, strokeWidth: 2),
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

  Widget _priceStat(BuildContext context, String label, String value, Color color,
      {bool bold = false}) {
    return Column(
      children: [
        Text(label,
            style: AppStyles.eyebrow.copyWith(
                color: context.mutedFg, fontSize: context.sp(9))),
        SizedBox(height: context.h(4)),
        Text(value,
            style: AppStyles.displayFont.copyWith(
              fontSize: context.sp(15),
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            )),
      ],
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: EdgeInsets.only(bottom: context.h(2)),
        child: Text(
          label,
          style: AppStyles.eyebrow.copyWith(color: context.mutedFg, letterSpacing: 1.5),
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
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
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
      key: ValueKey(label),
      initialValue: value,
      isExpanded: true,
      decoration: _fieldDecoration(label: label, hint: '', icon: icon),
      dropdownColor: context.card,
      style: AppStyles.bodyFont.copyWith(color: context.fg, fontSize: context.sp(13)),
      items: items
          .map((item) => DropdownMenuItem<T>(
              value: item, child: Text(itemLabel(item), overflow: TextOverflow.ellipsis)))
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
      padding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(14)),
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
