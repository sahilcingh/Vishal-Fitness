// GEMINI: DO NOT change any hardcoded values in this file.
// Always use responsive utilities (context.w, context.h, context.sp, context.r)
// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';
import 'admin_add_member_screen.dart';

const _paymentMethods = ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Cheque'];

/// Phone lookup -> renew a membership without leaving the dashboard.
/// Mirrors quick-renew-modal.tsx.
class AdminQuickRenewModal extends StatefulWidget {
  const AdminQuickRenewModal({super.key});

  @override
  State<AdminQuickRenewModal> createState() => _AdminQuickRenewModalState();
}

class _AdminQuickRenewModalState extends State<AdminQuickRenewModal> {
  final _phoneController = TextEditingController();
  final _extraDaysController = TextEditingController();
  final _discountController = TextEditingController();
  final _paidController = TextEditingController();
  final _notesController = TextEditingController();

  bool _checkingPhone = false;
  bool _hasChecked = false;
  String _checkedPhone = '';
  Map<String, dynamic>? _existingProfile;
  List<Map<String, dynamic>> _existingSubs = [];

  List<Map<String, dynamic>> _passes = [];
  bool _passesLoading = true;
  Map<String, dynamic>? _selectedPass;
  DateTime _startDate = DateTime.now();
  DateTime _paymentDate = DateTime.now();
  bool _isPercent = false;
  String _paymentMethod = 'Cash';

  bool _isSubmitting = false;
  String? _error;
  String? _successName;

  @override
  void initState() {
    super.initState();
    _fetchPasses();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _extraDaysController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchPasses() async {
    try {
      final response = await supabase.from('gym_passes').select().eq('is_active', true).order('duration_days', ascending: true);
      if (mounted) setState(() => _passes = List<Map<String, dynamic>>.from(response));
    } catch (_) {
      // ignore — dropdown just stays empty
    } finally {
      if (mounted) setState(() => _passesLoading = false);
    }
  }

  Future<void> _checkPhone() async {
    final trimmed = _phoneController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(trimmed)) return;
    if (trimmed == _checkedPhone && _hasChecked) return;
    setState(() {
      _checkingPhone = true;
      _error = null;
    });
    try {
      final data = await supabase.from('profiles').select('id, full_name, phone').eq('phone', trimmed).limit(1);
      final found = (data as List).isEmpty ? null : Map<String, dynamic>.from(data.first as Map);
      List<Map<String, dynamic>> subs = [];
      if (found != null) {
        final subsRes = await supabase
            .from('subscriptions')
            .select('id, start_date, end_date, status, pass:gym_passes(name)')
            .eq('user_id', found['id'])
            .neq('status', 'cancelled')
            .order('created_at', ascending: false)
            .limit(5);
        subs = List<Map<String, dynamic>>.from(subsRes);
      }
      if (mounted) {
        setState(() {
          _existingProfile = found;
          _existingSubs = subs;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _hasChecked = true;
          _checkedPhone = trimmed;
          _checkingPhone = false;
        });
      }
    }
  }

  String get _statusMessage {
    final now = DateTime.now();
    bool hasActive = false;
    DateTime? latestEnd;
    for (final sub in _existingSubs) {
      if (sub['status'] == 'active' && sub['end_date'] != null) {
        final end = DateTime.parse(sub['end_date'] as String);
        if (end.isAfter(now)) {
          hasActive = true;
          if (latestEnd == null || end.isAfter(latestEnd)) latestEnd = end;
        }
      }
    }
    final daysLeft = latestEnd != null ? latestEnd.difference(now).inDays : 0;
    if (_existingSubs.isEmpty) return 'No membership history found - add their first pass below.';
    if (!hasActive) return 'All previous memberships have expired - re-enroll them below.';
    if (daysLeft <= 7) return 'Active pass expires in $daysLeft day${daysLeft == 1 ? "" : "s"}.';
    if (daysLeft <= 30) return 'Active pass has $daysLeft days remaining.';
    return 'Active pass still has $daysLeft days remaining - adding a new pass this early is unusual.';
  }

  int get _extraDays => int.tryParse(_extraDaysController.text.trim()) ?? 0;
  DateTime get _endDate =>
      _selectedPass == null ? _startDate : _startDate.add(Duration(days: (_selectedPass!['duration_days'] as int) + _extraDays));
  double get _passPrice => (_selectedPass?['price'] as num?)?.toDouble() ?? 0;
  double get _discountAmount {
    final val = double.tryParse(_discountController.text.trim()) ?? 0;
    return _isPercent ? (_passPrice * val / 100).clamp(0, _passPrice) : val.clamp(0, _passPrice);
  }

  double get _effectivePrice => (_passPrice - _discountAmount).clamp(0, double.infinity);
  double get _paidAmountNum => double.tryParse(_paidController.text.trim()) ?? 0;
  double get _balance => (_effectivePrice - _paidAmountNum).clamp(0, double.infinity);

  Future<void> _handleUpdateMembership() async {
    final pass = _selectedPass;
    final profile = _existingProfile;
    if (profile == null) return;
    if (pass == null) {
      setState(() => _error = 'Please select a pass type.');
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    final startYmd = DateFormat('yyyy-MM-dd').format(_startDate);
    try {
      final exact = await supabase
          .from('subscriptions')
          .select('id')
          .eq('user_id', profile['id'])
          .eq('pass_id', pass['id'])
          .eq('start_date', startYmd)
          .neq('status', 'cancelled')
          .limit(1);
      if ((exact as List).isNotEmpty) {
        setState(() {
          _error =
              'A ${pass['name']} starting on ${DateFormat('d MMM yyyy').format(_startDate)} already exists for this member. Edit it from Subscriptions instead.';
          _isSubmitting = false;
        });
        return;
      }

      final windowStart = DateFormat('yyyy-MM-dd').format(_startDate.subtract(const Duration(days: 7)));
      final windowEnd = DateFormat('yyyy-MM-dd').format(_startDate.add(const Duration(days: 7)));
      final near = await supabase
          .from('subscriptions')
          .select('id, start_date')
          .eq('user_id', profile['id'])
          .eq('pass_id', pass['id'])
          .neq('status', 'cancelled')
          .gte('start_date', windowStart)
          .lte('start_date', windowEnd)
          .limit(1);
      if ((near as List).isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ctx.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.r(16))),
            title: Text('Enroll anyway?', style: AppStyles.displayFont.copyWith(fontSize: ctx.sp(16), fontWeight: FontWeight.bold, color: ctx.fg)),
            content: Text(
              '${profile['full_name'] ?? "This member"} already has a ${pass['name']} starting ${DateFormat('d MMM yyyy').format(DateTime.parse(near.first['start_date'] as String))} - within 7 days of this date. Add this as a separate enrollment anyway?',
              style: AppStyles.bodyFont.copyWith(fontSize: ctx.sp(13), color: ctx.fg),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: ctx.mutedFg))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
                child: const Text('Proceed', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final sub = await supabase
          .from('subscriptions')
          .insert({
            'user_id': profile['id'],
            'pass_id': pass['id'],
            'start_date': startYmd,
            'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
            'status': 'active',
            'discount_amount': _discountAmount > 0 ? _discountAmount : 0,
          })
          .select('id')
          .single();

      final safePaid = _paidAmountNum.clamp(0, _effectivePrice);
      bool paymentFailed = false;
      if (safePaid > 0) {
        try {
          await supabase.from('payments').insert({
            'subscription_id': sub['id'],
            'user_id': profile['id'],
            'amount': safePaid,
            'payment_date': DateFormat('yyyy-MM-dd').format(_paymentDate),
            'payment_method': _paymentMethod.toLowerCase(),
            'notes': _notesController.text.trim().isEmpty ? 'Payment at renewal' : _notesController.text.trim(),
          });
        } catch (_) {
          paymentFailed = true;
        }
      }

      if (!mounted) return;
      if (paymentFailed) {
        setState(() {
          _error =
              'Membership updated, but recording the ₹${safePaid.toStringAsFixed(0)} payment failed - add it manually from Subscriptions.';
          _isSubmitting = false;
        });
        return;
      }
      setState(() => _successName = profile['full_name'] as String? ?? 'Member');
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not update the membership: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDate(DateTime initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.brand, onPrimary: Colors.black, surface: ctx.card, onSurface: ctx.fg),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.r(24))),
      insetPadding: EdgeInsets.symmetric(horizontal: context.w(20), vertical: context.h(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.w(440), maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Padding(
          padding: EdgeInsets.all(context.r(20)),
          child: SingleChildScrollView(
            child: _successName != null ? _buildSuccess() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: context.r(36),
              height: context.r(36),
              decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.check, color: AppColors.brand, size: context.r(18)),
            ),
            SizedBox(width: context.w(12)),
            Expanded(
              child: Text('Membership Updated!', style: AppStyles.displayFont.copyWith(fontSize: context.sp(17), fontWeight: FontWeight.bold, color: context.fg)),
            ),
          ],
        ),
        SizedBox(height: context.h(12)),
        Text('A new subscription has been added for $_successName.', style: AppStyles.bodyFont.copyWith(fontSize: context.sp(14), color: context.fg)),
        SizedBox(height: context.h(20)),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, padding: EdgeInsets.symmetric(vertical: context.h(12))),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Update Membership', style: AppStyles.displayFont.copyWith(fontSize: context.sp(17), fontWeight: FontWeight.bold, color: context.fg)),
        SizedBox(height: context.h(4)),
        Text("Enter the member's phone number to look them up.", style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: context.mutedFg)),
        SizedBox(height: context.h(16)),
        _label('Phone Number'),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          autofocus: true,
          onChanged: (_) => setState(() {
            _hasChecked = false;
            _checkedPhone = '';
            _existingProfile = null;
            _existingSubs = [];
            _error = null;
          }),
          onEditingComplete: _checkPhone,
          onTapOutside: (_) => _checkPhone(),
          decoration: _fieldDecoration(hint: 'e.g. 9876543210'),
        ),
        if (_checkingPhone) ...[
          SizedBox(height: context.h(10)),
          Row(children: [
            SizedBox(width: context.r(14), height: context.r(14), child: const CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: context.w(8)),
            Text('Checking...', style: AppStyles.bodyFont.copyWith(fontSize: context.sp(12.5), color: context.mutedFg)),
          ]),
        ],
        if (_hasChecked && !_checkingPhone && _existingProfile == null) ...[
          SizedBox(height: context.h(10)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: context.w(14), vertical: context.h(12)),
            decoration: BoxDecoration(color: context.muted, borderRadius: BorderRadius.circular(context.r(12))),
            child: Row(children: [
              Icon(Icons.person_off_outlined, color: context.mutedFg, size: context.r(20)),
              SizedBox(width: context.w(10)),
              Expanded(child: Text('No member found with this number.', style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: context.mutedFg))),
            ]),
          ),
          SizedBox(height: context.h(10)),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAddMemberScreen(initialPhone: _phoneController.text.trim())));
              },
              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
              label: const Text('Add as New Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, padding: EdgeInsets.symmetric(vertical: context.h(12))),
            ),
          ),
        ],
        if (_existingProfile != null) ..._buildExistingMemberForm(),
        if (_error != null) ...[
          SizedBox(height: context.h(14)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: context.w(14), vertical: context.h(10)),
            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(context.r(12))),
            child: Text(_error!, style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: Colors.redAccent)),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildExistingMemberForm() {
    final profile = _existingProfile!;
    final name = (profile['full_name'] as String? ?? 'M').trim();
    final initials = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return [
      SizedBox(height: context.h(10)),
      Container(
        padding: EdgeInsets.symmetric(horizontal: context.w(14), vertical: context.h(12)),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(context.r(12)),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: context.r(36),
            height: context.r(36),
            decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Center(child: Text(initials, style: AppStyles.displayFont.copyWith(fontSize: context.sp(12), fontWeight: FontWeight.bold, color: AppColors.brand))),
          ),
          SizedBox(width: context.w(10)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name.isEmpty ? 'Unnamed member' : name, style: AppStyles.bodyFont.copyWith(fontWeight: FontWeight.bold, fontSize: context.sp(13.5), color: context.fg)),
              Text(_statusMessage, style: AppStyles.bodyFont.copyWith(fontSize: context.sp(12), color: context.mutedFg)),
            ]),
          ),
        ]),
      ),
      SizedBox(height: context.h(14)),
      _label('Pass Type *'),
      _passesLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : DropdownButtonFormField<String>(
              initialValue: _selectedPass?['id'] as String?,
              decoration: _fieldDecoration(),
              dropdownColor: context.card,
              style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: context.fg),
              hint: Text('Select a pass', style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: context.mutedFg)),
              items: _passes
                  .map((p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text('${p['name']} · ${currency.format(p['price'])} · ${p['duration_days']} days', overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPass = _passes.firstWhere((p) => p['id'] == v)),
            ),
      SizedBox(height: context.h(12)),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Start Date'),
            GestureDetector(
              onTap: () => _pickDate(_startDate, (d) => setState(() => _startDate = d)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: context.w(12), vertical: context.h(13)),
                decoration: BoxDecoration(border: Border.all(color: context.border), borderRadius: BorderRadius.circular(context.r(12))),
                child: Text(DateFormat('d MMM yyyy').format(_startDate), style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: context.fg)),
              ),
            ),
          ]),
        ),
        SizedBox(width: context.w(10)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Extra Days'),
            TextField(
              controller: _extraDaysController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(hint: 'e.g. 5'),
            ),
          ]),
        ),
      ]),
      SizedBox(height: context.h(12)),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Discount Type'),
            Row(children: [
              Expanded(child: _segButton('₹', !_isPercent, () => setState(() => _isPercent = false))),
              SizedBox(width: context.w(8)),
              Expanded(child: _segButton('%', _isPercent, () => setState(() => _isPercent = true))),
            ]),
          ]),
        ),
        SizedBox(width: context.w(10)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label(_isPercent ? 'Discount %' : 'Discount (₹)'),
            TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(hint: _isPercent ? 'e.g. 10' : 'e.g. 200'),
            ),
          ]),
        ),
      ]),
      if (_selectedPass != null) ...[
        SizedBox(height: context.h(12)),
        Container(
          padding: EdgeInsets.symmetric(vertical: context.h(10)),
          decoration: BoxDecoration(border: Border.all(color: context.border), borderRadius: BorderRadius.circular(context.r(12))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _miniStat('FINAL', currency.format(_effectivePrice), context.fg),
            _miniStat('PAID', currency.format(_paidAmountNum), AppColors.brand),
            _miniStat('BALANCE', currency.format(_balance), _balance > 0 ? AppColors.energy : AppColors.brand),
          ]),
        ),
      ],
      SizedBox(height: context.h(12)),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Amount Paid (₹)'),
            TextField(
              controller: _paidController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(hint: 'e.g. 1500'),
            ),
          ]),
        ),
        SizedBox(width: context.w(10)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Payment Date'),
            GestureDetector(
              onTap: () => _pickDate(_paymentDate, (d) => setState(() => _paymentDate = d)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: context.w(12), vertical: context.h(13)),
                decoration: BoxDecoration(border: Border.all(color: context.border), borderRadius: BorderRadius.circular(context.r(12))),
                child: Text(DateFormat('d MMM yyyy').format(_paymentDate), style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: context.fg)),
              ),
            ),
          ]),
        ),
      ]),
      SizedBox(height: context.h(12)),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Payment Method'),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: _fieldDecoration(),
              dropdownColor: context.card,
              style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), color: context.fg),
              items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
            ),
          ]),
        ),
        SizedBox(width: context.w(10)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Note (optional)'),
            TextField(controller: _notesController, decoration: _fieldDecoration(hint: 'e.g. Paid by father')),
          ]),
        ),
      ]),
      SizedBox(height: context.h(18)),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (_isSubmitting || _selectedPass == null) ? null : _handleUpdateMembership,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, padding: EdgeInsets.symmetric(vertical: context.h(13))),
          child: _isSubmitting
              ? SizedBox(width: context.r(18), height: context.r(18), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Update Membership', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    ];
  }

  Widget _segButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.h(13)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : Colors.transparent,
          border: Border.all(color: selected ? AppColors.brand : context.border),
          borderRadius: BorderRadius.circular(context.r(12)),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : context.fg, fontWeight: FontWeight.bold, fontSize: context.sp(12))),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      Text(label, style: AppStyles.eyebrow.copyWith(fontSize: context.sp(8), color: context.mutedFg)),
      SizedBox(height: context.h(4)),
      Text(value, style: AppStyles.displayFont.copyWith(fontSize: context.sp(13), fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: context.h(6)),
        child: Text(text, style: AppStyles.eyebrow.copyWith(fontSize: context.sp(9.5), color: context.mutedFg)),
      );

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppStyles.bodyFont.copyWith(fontSize: context.sp(12.5), color: context.mutedFg.withValues(alpha: 0.6)),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: context.w(12), vertical: context.h(13)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(12)), borderSide: BorderSide(color: context.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(12)), borderSide: BorderSide(color: context.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(context.r(12)), borderSide: const BorderSide(color: AppColors.brand, width: 1.5)),
    );
  }
}
