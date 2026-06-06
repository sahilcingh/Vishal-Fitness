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
  final _extraDaysController = TextEditingController();

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
    _extraDaysController.dispose();
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

  int get _extraDays => int.tryParse(_extraDaysController.text.trim()) ?? 0;

  DateTime get _endDate {
    if (_selectedPass == null) return _startDate;
    final baseDays = (_selectedPass!['duration_days'] as int?) ?? 0;
    return _startDate.add(Duration(days: baseDays + _extraDays));
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

  void _showMemberExistsDialog(Map profile, List allSubs) {
    final memberName = profile['full_name'] as String? ?? _nameController.text.trim();
    final phone = profile['phone'] as String? ?? _phoneController.text.trim();
    final now = DateTime.now();

    bool hasActive = false;
    DateTime? latestEnd;

    for (final rawSub in allSubs) {
      final sub = rawSub as Map;
      final status = sub['status'] as String? ?? '';
      final endDateStr = sub['end_date'] as String?;
      if (status == 'active' && endDateStr != null) {
        final endDate = DateTime.parse(endDateStr);
        if (endDate.isAfter(now)) {
          hasActive = true;
          if (latestEnd == null || endDate.isAfter(latestEnd)) {
            latestEnd = endDate;
          }
        }
      }
    }

    final daysLeft = latestEnd != null ? latestEnd.difference(now).inDays : 0;

    final String actionLabel;
    final Color actionColor;
    DateTime? suggestedStart;
    final String contextMessage;

    if (allSubs.isEmpty) {
      actionLabel = 'Add First Pass';
      actionColor = AppColors.brand;
      contextMessage = 'No membership history found. Add their first pass below.';
    } else if (!hasActive) {
      actionLabel = 'Re-enroll';
      actionColor = AppColors.brand;
      contextMessage = 'All previous memberships have expired. Re-enroll them with a new pass.';
    } else if (daysLeft <= 7) {
      actionLabel = 'Renew Now';
      actionColor = AppColors.brand;
      suggestedStart = latestEnd!.add(const Duration(days: 1));
      contextMessage = 'Active pass expires in $daysLeft day${daysLeft == 1 ? '' : 's'}. Renewal will start the day after.';
    } else if (daysLeft <= 30) {
      actionLabel = 'Schedule Renewal';
      actionColor = AppColors.sun;
      suggestedStart = latestEnd!.add(const Duration(days: 1));
      contextMessage = 'Active pass has $daysLeft days remaining. Schedule a renewal to start after it ends.';
    } else {
      actionLabel = 'Add Anyway';
      actionColor = AppColors.energy;
      contextMessage = 'Active pass still has $daysLeft days remaining. Adding a new pass this early is unusual — confirm only if intentional.';
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _memberDialogHeader(ctx, memberName, phone),
              const SizedBox(height: 16),
              if (allSubs.isNotEmpty) ...[
                Text(
                  'SUBSCRIPTION HISTORY',
                  style: AppStyles.displayFont.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ctx.mutedFg,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: allSubs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _subRow(ctx, allSubs[i] as Map, now),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: actionColor.withValues(alpha: 0.30)),
                ),
                child: Text(
                  contextMessage,
                  style: AppStyles.bodyFont.copyWith(
                    color: actionColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: TextStyle(color: ctx.mutedFg)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (suggestedStart != null) {
                          setState(() => _startDate = suggestedStart!);
                        }
                        _addSubscriptionToExistingMember();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _memberDialogHeader(BuildContext ctx, String name, String phone) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.brand.withValues(alpha: 0.15),
          child: Text(
            initials,
            style: AppStyles.displayFont.copyWith(
              color: AppColors.brand,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppStyles.displayFont.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: ctx.fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                phone,
                style: AppStyles.bodyFont.copyWith(color: ctx.mutedFg, fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Existing',
            style: AppStyles.bodyFont.copyWith(
              color: AppColors.brand,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _subRow(BuildContext ctx, Map sub, DateTime now) {
    final passName = (sub['pass'] as Map?)?['name'] as String? ?? 'Pass';
    final startDateStr = sub['start_date'] as String?;
    final endDateStr = sub['end_date'] as String?;
    final status = sub['status'] as String? ?? '';

    Color badgeColor;
    String badgeLabel;

    if (endDateStr != null) {
      final endDate = DateTime.parse(endDateStr);
      if (status == 'active' && endDate.isAfter(now)) {
        final days = endDate.difference(now).inDays;
        if (days <= 7) {
          badgeColor = AppColors.energy;
          badgeLabel = '${days}d left';
        } else {
          badgeColor = AppColors.brand;
          badgeLabel = 'Active';
        }
      } else {
        badgeColor = Colors.grey;
        badgeLabel = 'Expired';
      }
    } else {
      badgeColor = Colors.grey;
      badgeLabel = status.isEmpty ? 'Unknown' : status;
    }

    final startFormatted = startDateStr != null
        ? DateFormat('d MMM yy').format(DateTime.parse(startDateStr))
        : '–';
    final endFormatted = endDateStr != null
        ? DateFormat('d MMM yy').format(DateTime.parse(endDateStr))
        : '–';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ctx.fg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passName,
                  style: AppStyles.bodyFont.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ctx.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$startFormatted → $endFormatted',
                  style: AppStyles.bodyFont.copyWith(color: ctx.mutedFg, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeLabel,
              style: AppStyles.bodyFont.copyWith(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
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
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Something Went Wrong',
                style: AppStyles.displayFont.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ctx.fg,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppStyles.bodyFont.copyWith(color: ctx.mutedFg, fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSubscriptionToExistingMember() async {
    if (_selectedPass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pass type.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final phone = _phoneController.text.trim();
      final profileList = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('phone', phone)
          .limit(1);

      if (profileList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find existing member. Please check the phone number.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final profile   = profileList[0];
      final userId    = profile['id'] as String;
      final passId    = _selectedPass!['id'];
      final startStr  = DateFormat('yyyy-MM-dd').format(_startDate);
      final memberName = profile['full_name'] as String? ?? '';
      final passName   = _selectedPass!['name'] as String? ?? '';

      // ── Guard 1: Exact duplicate — same pass + same start date ──────────
      // Seen in production: AMAN KHAN had 3 identical entries on the same day.
      final exactMatch = await supabase
          .from('subscriptions')
          .select('id')
          .eq('user_id', userId)
          .eq('pass_id', passId)
          .eq('start_date', startStr)
          .neq('status', 'cancelled')
          .limit(1);

      if (exactMatch.isNotEmpty) {
        setState(() => _isSubmitting = false);
        _showBlockedDuplicateDialog(
          memberName,
          passName,
          DateFormat('d MMM yyyy').format(_startDate),
        );
        return;
      }

      // ── Guard 2: Near-duplicate — same pass, start date within 7 days ───
      // Seen in production: ABHAY YADAV added twice 3 days apart.
      final windowStart = _startDate.subtract(const Duration(days: 7));
      final windowEnd   = _startDate.add(const Duration(days: 7));
      final nearMatch   = await supabase
          .from('subscriptions')
          .select('id, start_date')
          .eq('user_id', userId)
          .eq('pass_id', passId)
          .neq('status', 'cancelled')
          .gte('start_date', DateFormat('yyyy-MM-dd').format(windowStart))
          .lte('start_date', DateFormat('yyyy-MM-dd').format(windowEnd))
          .limit(1);

      if (nearMatch.isNotEmpty) {
        final existingStart = DateFormat('d MMM yyyy').format(
          DateTime.parse(nearMatch[0]['start_date'] as String),
        );
        setState(() => _isSubmitting = false);
        _showNearDuplicateWarning(
          memberName: memberName,
          passName: passName,
          existingStartDate: existingStart,
          onConfirm: () {
            setState(() => _isSubmitting = true);
            _doInsertSubscription(userId, profile);
          },
        );
        return;
      }

      await _doInsertSubscription(userId, profile);
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      if (mounted) _showErrorDialog('Could not add the subscription. Please try again.');
    }
  }

  Future<void> _doInsertSubscription(String userId, Map<String, dynamic> profile) async {
    try {
      final subRes = await supabase.from('subscriptions').insert({
        'user_id': userId,
        'pass_id': _selectedPass!['id'],
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'status': 'active',
        'discount_amount': _discountAmount > 0 ? _discountAmount : 0,
      }).select('id').single();

      final subscriptionId = subRes['id'] as String;

      if (_paidAmount > 0) {
        await supabase.from('payments').insert({
          'subscription_id': subscriptionId,
          'user_id': userId,
          'amount': _paidAmount,
          'payment_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'payment_method': _paymentMethod.toLowerCase(),
          'notes': _notesController.text.trim().isEmpty
              ? 'Payment at re-enrollment'
              : _notesController.text.trim(),
        });
      }

      final profileUpdate = <String, dynamic>{};
      if (_timeSlotController.text.trim().isNotEmpty) {
        profileUpdate['time_slot'] = _timeSlotController.text.trim();
      }
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
              SnackBar(content: Text('Photo upload failed: $e'), backgroundColor: Colors.redAccent),
            );
          }
        }
      }
      if (profileUpdate.isNotEmpty) {
        await supabase.from('profiles').update(profileUpdate).eq('id', userId);
      }

      if (!mounted) return;
      _showReEnrollSuccessDialog(profile['full_name'] as String? ?? '');
    } catch (e) {
      if (mounted) _showErrorDialog('Could not add the subscription. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showReEnrollSuccessDialog(String memberName) {
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
                'Subscription Added!',
                style: AppStyles.displayFont.copyWith(
                    fontSize: 18, fontWeight: FontWeight.bold, color: ctx.fg),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new subscription has been added for $memberName.',
              style: AppStyles.bodyFont.copyWith(color: ctx.fg, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ctx.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _successStat(ctx, 'TOTAL', '₹${_effectivePrice.toStringAsFixed(0)}', ctx.fg),
                  _successStat(ctx, 'PAID', '₹${_paidAmount.toStringAsFixed(0)}', AppColors.brand),
                  _successStat(ctx, 'BALANCE', '₹${_balance.toStringAsFixed(0)}',
                      _balance > 0 ? AppColors.energy : AppColors.brand),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(ctx, Icons.event_available_outlined,
                'Valid till ${DateFormat('d MMM yyyy').format(_endDate)}'),
            const SizedBox(height: 8),
            _buildInfoRow(ctx, Icons.info_outline,
                'Member logs in with their existing credentials.'),
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

  Widget _buildInfoRow(BuildContext ctx, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brand, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppStyles.bodyFont.copyWith(
                    color: AppColors.brand, fontSize: 11, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // Exact duplicate — hard block, no proceed option.
  void _showBlockedDuplicateDialog(
      String memberName, String passName, String startDate) {
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
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block_outlined, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Duplicate Entry Blocked',
                style: AppStyles.displayFont.copyWith(
                    fontSize: 18, fontWeight: FontWeight.bold, color: ctx.fg),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A $passName starting on $startDate already exists for $memberName.',
              style: AppStyles.bodyFont.copyWith(
                  color: ctx.mutedFg, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      color: Colors.redAccent, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If the discount or amount was wrong on the original entry, edit it from the Subscriptions screen instead of creating a new one.',
                      style: AppStyles.bodyFont.copyWith(
                          color: Colors.redAccent, fontSize: 11, height: 1.4),
                    ),
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Near-duplicate — warns but lets admin override if intentional.
  void _showNearDuplicateWarning({
    required String memberName,
    required String passName,
    required String existingStartDate,
    required VoidCallback onConfirm,
  }) {
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
                color: AppColors.sun.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.sun, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Possible Duplicate',
                style: AppStyles.displayFont.copyWith(
                    fontSize: 18, fontWeight: FontWeight.bold, color: ctx.fg),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$memberName already has a $passName that started on $existingStartDate — within 7 days of the date you\'re entering.',
              style: AppStyles.bodyFont.copyWith(
                  color: ctx.mutedFg, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sun.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.sun.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.help_outline, color: AppColors.sun, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only proceed if this is a genuine separate enrollment, not a re-entry of the same membership.',
                      style: AppStyles.bodyFont.copyWith(
                          color: AppColors.sun, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ctx.mutedFg)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sun,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pass type.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

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
      // Pre-check: is this phone already registered?
      // Using limit(1) instead of maybeSingle() so existing duplicate rows
      // in the DB don't cause a PostgREST error.
      final phone = _phoneController.text.trim();
      final existingList = await supabase
          .from('profiles')
          .select('id, full_name, phone')
          .eq('phone', phone)
          .limit(1);
      final existing = existingList.isNotEmpty ? existingList[0] : null;

      if (existing != null) {
        final List allSubs = await supabase
            .from('subscriptions')
            .select('id, start_date, end_date, status, pass:gym_passes(name)')
            .eq('user_id', existing['id'] as String)
            .neq('status', 'cancelled')
            .order('created_at', ascending: false)
            .limit(5);

        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showMemberExistsDialog(existing as Map, allSubs);
        return;
      }

      // No existing member — create new account
      await _createNewMember();
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
      if (mounted) _showErrorDialog('Could not complete the request. Please check your connection and try again.');
    }
  }

  Future<void> _createNewMember() async {
    // _isSubmitting is already true when this is called
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
        final msg = data?['error'] as String? ?? 'Unknown error occurred.';
        if (!mounted) return;
        // Fallback: Edge Function detected duplicate (race condition).
        // Re-query with full subscription history to show the rich dialog.
        if (msg.toLowerCase().contains('already been registered') ||
            msg.toLowerCase().contains('already registered')) {
          try {
            final phone = _phoneController.text.trim();
            final profileList = await supabase
                .from('profiles')
                .select('id, full_name, phone')
                .eq('phone', phone)
                .limit(1);
            if (profileList.isNotEmpty && mounted) {
              final profile = profileList[0] as Map;
              final allSubs = await supabase
                  .from('subscriptions')
                  .select('id, start_date, end_date, status, pass:gym_passes(name)')
                  .eq('user_id', profile['id'] as String)
                  .neq('status', 'cancelled')
                  .order('created_at', ascending: false)
                  .limit(5);
              if (mounted) _showMemberExistsDialog(profile, allSubs);
            } else if (mounted) {
              _showErrorDialog('This phone number is already registered. Please search for the member to add a pass.');
            }
          } catch (_) {
            if (mounted) _showErrorDialog('This phone number is already registered. Please search for the member to add a pass.');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }

      final userId = data['user_id'] as String;

      final subRes = await supabase
          .from('subscriptions')
          .select('id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      final subscriptionId = subRes['id'] as String;

      final subPatch = <String, dynamic>{};
      if (_discountAmount > 0) subPatch['discount_amount'] = _discountAmount;
      if (_extraDays > 0) subPatch['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate);
      if (subPatch.isNotEmpty) {
        await supabase.from('subscriptions').update(subPatch).eq('id', subscriptionId);
      }

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

      final profileUpdate = <String, dynamic>{'needs_password_reset': true};
      if (_timeSlotController.text.trim().isNotEmpty) {
        profileUpdate['time_slot'] = _timeSlotController.text.trim();
      }
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
              SnackBar(content: Text('Photo upload failed: $e'), backgroundColor: Colors.redAccent),
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
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('already been registered') || errStr.contains('already registered')) {
          try {
            final phone = _phoneController.text.trim();
            final profileList = await supabase
                .from('profiles')
                .select('id, full_name, phone')
                .eq('phone', phone)
                .limit(1);
            if (profileList.isNotEmpty) {
              final profile = profileList[0] as Map;
              final allSubs = await supabase
                  .from('subscriptions')
                  .select('id, start_date, end_date, status, pass:gym_passes(name)')
                  .eq('user_id', profile['id'] as String)
                  .neq('status', 'cancelled')
                  .order('created_at', ascending: false)
                  .limit(5);
              if (mounted) _showMemberExistsDialog(profile, allSubs);
            } else if (mounted) {
              _showErrorDialog('This phone number is already registered. Please search for the member to add a pass.');
            }
          } catch (_) {
            if (mounted) _showErrorDialog('This phone number is already registered. Please search for the member to add a pass.');
          }
        } else {
          _showErrorDialog('Could not add the member. Please check your connection and try again.');
        }
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
    _extraDaysController.clear();
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
                    SizedBox(height: context.h(12)),
                    _buildField(
                      controller: _extraDaysController,
                      label: 'Extra Days (optional)',
                      hint: 'e.g. 5 — extends membership end date',
                      icon: Icons.more_time_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_selectedPass != null) ...[
                      SizedBox(height: context.h(12)),
                      _buildInfoTile(
                        label: _extraDays > 0
                            ? 'End Date (+$_extraDays extra days)'
                            : 'End Date (auto-calculated)',
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
