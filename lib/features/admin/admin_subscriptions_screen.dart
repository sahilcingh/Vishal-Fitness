// GEMINI: DO NOT change any hardcoded values in this file.
// Always use responsive utilities (context.w, context.h, context.sp, context.r)
// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';
import 'package:intl/intl.dart';

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _subscriptions = [];
  Map<String, double> _paidAmounts = {};
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final subRes = await supabase
          .from('subscriptions')
          .select('''
            id,
            start_date,
            end_date,
            status,
            user_id,
            discount_amount,
            profiles:user_id ( full_name, phone ),
            gym_passes:pass_id ( name, duration_days, price )
          ''')
          .order('end_date', ascending: true);

      final payRes = await supabase
          .from('payments')
          .select('subscription_id, amount');

      final Map<String, double> paidMap = {};
      for (final p in List<Map<String, dynamic>>.from(payRes)) {
        final sid = p['subscription_id'] as String;
        paidMap[sid] = (paidMap[sid] ?? 0) + (p['amount'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _subscriptions = List<Map<String, dynamic>>.from(subRes);
          _paidAmounts = paidMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscriptions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await supabase.from('subscriptions').update({'status': newStatus}).eq('id', id);
      _fetchSubscriptions();
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  void _showPaymentsSheet(Map<String, dynamic> sub, double discountAmount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentsSheet(
        subscription: sub,
        discountAmount: discountAmount,
        onPaymentRecorded: _fetchSubscriptions,
      ),
    );
  }

  Future<void> _setDiscount(String subscriptionId, double amount) async {
    try {
      await supabase.from('subscriptions').update({'discount_amount': amount}).eq('id', subscriptionId);
      _fetchSubscriptions();
    } catch (e) {
      debugPrint('Error setting discount: $e');
    }
  }

  void _showDiscountDialog(String subscriptionId, double passPrice, double currentDiscount) {
    bool isPercent = false;
    final controller = TextEditingController(
      text: currentDiscount > 0 ? currentDiscount.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: context.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.r(20))),
          title: Text(
            'Set Discount',
            style: AppStyles.displayFont.copyWith(
              fontSize: context.sp(18),
              fontWeight: FontWeight.bold,
              color: context.fg,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => isPercent = false),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: context.h(10)),
                        decoration: BoxDecoration(
                          color: !isPercent ? AppColors.brand : Colors.transparent,
                          borderRadius: BorderRadius.circular(context.r(8)),
                          border: Border.all(color: !isPercent ? AppColors.brand : context.border),
                        ),
                        child: Center(
                          child: Text(
                            '₹ Amount',
                            style: AppStyles.bodyFont.copyWith(
                              color: !isPercent ? Colors.white : context.fg,
                              fontWeight: FontWeight.w600,
                              fontSize: context.sp(13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.w(8)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => isPercent = true),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: context.h(10)),
                        decoration: BoxDecoration(
                          color: isPercent ? AppColors.brand : Colors.transparent,
                          borderRadius: BorderRadius.circular(context.r(8)),
                          border: Border.all(color: isPercent ? AppColors.brand : context.border),
                        ),
                        child: Center(
                          child: Text(
                            '% Percent',
                            style: AppStyles.bodyFont.copyWith(
                              color: isPercent ? Colors.white : context.fg,
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
              SizedBox(height: context.h(16)),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isPercent ? 'Discount %' : 'Discount Amount',
                  prefixText: isPercent ? null : '₹ ',
                  suffixText: isPercent ? '%' : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(context.r(8)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: context.mutedFg)),
            ),
            TextButton(
              onPressed: () {
                _setDiscount(subscriptionId, 0);
                Navigator.pop(ctx);
              },
              child: Text('Remove', style: TextStyle(color: AppColors.energy)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text.trim()) ?? 0;
                final discountAmt = isPercent ? (passPrice * val / 100) : val;
                _setDiscount(subscriptionId, discountAmt.clamp(0, passPrice));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.r(8))),
              ),
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _membershipNo(String userId) =>
      'MBR-${userId.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .take(2)
      .map((w) => w.isNotEmpty ? w[0] : '')
      .join()
      .toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _subscriptions.isEmpty
              ? Center(
                  child: Text(
                    'No subscriptions found.',
                    style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    context.w(AppStyles.containerPadding),
                    context.h(16),
                    context.w(AppStyles.containerPadding),
                    context.h(120),
                  ),
                  itemCount: _subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = _subscriptions[index];
                    final id = sub['id'] as String;
                    final isExpanded = _expandedIds.contains(id);
                    final profile = sub['profiles'] ?? {};
                    final pass = sub['gym_passes'] ?? {};
                    final endDate = DateTime.parse(sub['end_date']);
                    final startDate = DateTime.parse(sub['start_date']);
                    final daysLeft = endDate.difference(DateTime.now()).inDays;
                    final isExpired = daysLeft < 0 || sub['status'] == 'expired';
                    final totalFee = (pass['price'] as num?)?.toDouble() ?? 0.0;
                    final discountAmount = (sub['discount_amount'] as num?)?.toDouble() ?? 0.0;
                    final effectivePrice = (totalFee - discountAmount).clamp(0.0, double.infinity);
                    final paid = _paidAmounts[id] ?? 0.0;
                    final balance = effectivePrice - paid;
                    final name = profile['full_name'] as String? ?? 'Unknown';
                    final memberNo = _membershipNo(sub['user_id'] as String);

                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isExpanded) {
                          _expandedIds.remove(id);
                        } else {
                          _expandedIds.add(id);
                        }
                      }),
                      child: Container(
                        margin: EdgeInsets.only(bottom: context.h(10)),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
                          border: Border.all(
                            color: isExpired
                                ? AppColors.energy.withValues(alpha: 0.4)
                                : context.border,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: context.r(8),
                              offset: Offset(0, context.h(3)),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // ── Collapsed header (always visible) ──
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.w(14),
                                vertical: context.h(12),
                              ),
                              child: Row(
                                children: [
                                  // Initials avatar
                                  Container(
                                    width: context.r(38),
                                    height: context.r(38),
                                    decoration: BoxDecoration(
                                      color: (isExpired ? AppColors.energy : AppColors.brand)
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _initials(name),
                                        style: AppStyles.displayFont.copyWith(
                                          fontSize: context.sp(13),
                                          fontWeight: FontWeight.bold,
                                          color: isExpired ? AppColors.energy : AppColors.brand,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: context.w(10)),
                                  // Name + MBR + phone
                                  Flexible(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppStyles.displayFont.copyWith(
                                            fontSize: context.sp(13),
                                            fontWeight: FontWeight.bold,
                                            color: context.fg,
                                          ),
                                        ),
                                        SizedBox(height: context.h(2)),
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: context.w(5),
                                                vertical: context.h(1),
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.brand.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(context.r(4)),
                                              ),
                                              child: Text(
                                                memberNo,
                                                style: AppStyles.eyebrow.copyWith(
                                                  fontSize: context.sp(8),
                                                  color: AppColors.brand,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: context.w(5)),
                                            Flexible(
                                              child: Text(
                                                profile['phone'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppStyles.bodyFont.copyWith(
                                                  fontSize: context.sp(10),
                                                  color: context.mutedFg,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: context.w(8)),
                                  // ── Inline financial strip ──
                                  Expanded(
                                    flex: 4,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: context.h(6),
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.bg,
                                        borderRadius: BorderRadius.circular(context.r(8)),
                                      ),
                                      child: Row(
                                        children: [
                                          _miniStat(context, 'PRICE', '₹${effectivePrice.toStringAsFixed(0)}', context.fg),
                                          _vertDivider(context),
                                          _miniStat(context, 'PAID', '₹${paid.toStringAsFixed(0)}', AppColors.brand),
                                          _vertDivider(context),
                                          _miniStat(
                                            context,
                                            'BALANCE',
                                            '₹${balance.toStringAsFixed(0)}',
                                            balance > 0 ? AppColors.energy : AppColors.brand,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: context.w(8)),
                                  // Status + chevron
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: context.w(7),
                                          vertical: context.h(3),
                                        ),
                                        decoration: BoxDecoration(
                                          color: isExpired
                                              ? AppColors.energy.withValues(alpha: 0.1)
                                              : AppColors.brand.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(context.r(6)),
                                        ),
                                        child: Text(
                                          sub['status'].toString().toUpperCase(),
                                          style: AppStyles.eyebrow.copyWith(
                                            color: isExpired ? AppColors.energy : AppColors.brand,
                                            fontSize: context.sp(9),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: context.h(4)),
                                      AnimatedRotation(
                                        turns: isExpanded ? 0.5 : 0,
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          Icons.keyboard_arrow_down,
                                          size: context.r(18),
                                          color: context.mutedFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ── Expandable details ──
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: isExpanded
                                  ? Column(
                                      children: [
                                        Divider(height: 1, color: context.border),
                                        Padding(
                                          padding: EdgeInsets.all(context.r(14)),
                                          child: Column(
                                            children: [
                                              // Pass type + days left
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _detailCell(
                                                    context,
                                                    'PASS TYPE',
                                                    pass['name'] ?? 'Custom',
                                                    context.fg,
                                                  ),
                                                  _detailCell(
                                                    context,
                                                    'DAYS LEFT',
                                                    isExpired ? 'Expired' : '$daysLeft days',
                                                    isExpired ? AppColors.energy : context.fg,
                                                    align: CrossAxisAlignment.end,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: context.h(12)),
                                              // Start + End dates
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _detailCell(
                                                    context,
                                                    'STARTED',
                                                    DateFormat('MMM d, yyyy').format(startDate),
                                                    context.fg,
                                                  ),
                                                  _detailCell(
                                                    context,
                                                    'ENDS',
                                                    DateFormat('MMM d, yyyy').format(endDate),
                                                    context.fg,
                                                    align: CrossAxisAlignment.end,
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: context.h(12)),
                                              // Discount row
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _detailCell(
                                                    context,
                                                    'DISCOUNT',
                                                    discountAmount > 0
                                                        ? '₹${discountAmount.toStringAsFixed(0)} off'
                                                        : 'None',
                                                    discountAmount > 0 ? AppColors.brand : context.mutedFg,
                                                  ),
                                                  TextButton.icon(
                                                    onPressed: () => _showDiscountDialog(id, totalFee, discountAmount),
                                                    icon: Icon(Icons.local_offer_outlined, size: context.r(14)),
                                                    label: Text('Set', style: TextStyle(fontSize: context.sp(12))),
                                                    style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: context.h(14)),
                                              // Payment summary
                                              Container(
                                                padding: EdgeInsets.all(context.r(10)),
                                                decoration: BoxDecoration(
                                                  color: context.bg,
                                                  borderRadius: BorderRadius.circular(context.r(10)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'PAYMENT',
                                                            style: AppStyles.eyebrow.copyWith(
                                                              color: context.mutedFg,
                                                              fontSize: context.sp(9),
                                                            ),
                                                          ),
                                                          SizedBox(height: context.h(3)),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                '₹${paid.toStringAsFixed(0)} paid',
                                                                style: AppStyles.bodyFont.copyWith(
                                                                  fontSize: context.sp(13),
                                                                  color: AppColors.brand,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                              Text(
                                                                ' / ₹${effectivePrice.toStringAsFixed(0)}',
                                                                style: AppStyles.bodyFont.copyWith(
                                                                  fontSize: context.sp(13),
                                                                  color: context.mutedFg,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          if (balance > 0)
                                                            Text(
                                                              'Balance ₹${balance.toStringAsFixed(0)}',
                                                              style: AppStyles.bodyFont.copyWith(
                                                                fontSize: context.sp(11),
                                                                color: AppColors.energy,
                                                              ),
                                                            )
                                                          else if (totalFee > 0)
                                                            Text(
                                                              'Fully Paid',
                                                              style: AppStyles.bodyFont.copyWith(
                                                                fontSize: context.sp(11),
                                                                color: AppColors.brand,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    OutlinedButton.icon(
                                                      onPressed: () => _showPaymentsSheet(sub, discountAmount),
                                                      icon: Icon(
                                                        Icons.payments_outlined,
                                                        size: context.r(14),
                                                      ),
                                                      label: Text(
                                                        'Received',
                                                        style: TextStyle(fontSize: context.sp(12)),
                                                      ),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor: AppColors.brand,
                                                        side: const BorderSide(color: AppColors.brand),
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: context.w(10),
                                                          vertical: context.h(7),
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(context.r(8)),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: context.h(10)),
                                              // Status actions
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  PopupMenuButton<String>(
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.more_horiz,
                                                          size: context.r(18),
                                                          color: context.mutedFg,
                                                        ),
                                                        SizedBox(width: context.w(4)),
                                                        Text(
                                                          'Change status',
                                                          style: AppStyles.bodyFont.copyWith(
                                                            fontSize: context.sp(12),
                                                            color: context.mutedFg,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    onSelected: (val) => _updateStatus(id, val),
                                                    itemBuilder: (context) => [
                                                      const PopupMenuItem(
                                                        value: 'active',
                                                        child: Text('Mark Active'),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'suspended',
                                                        child: Text('Suspend'),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'cancelled',
                                                        child: Text('Cancel'),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _miniStat(BuildContext context, String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppStyles.eyebrow.copyWith(
              color: context.mutedFg,
              fontSize: context.sp(8),
            ),
          ),
          SizedBox(height: context.h(2)),
          Text(
            value,
            style: AppStyles.displayFont.copyWith(
              fontSize: context.sp(13),
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vertDivider(BuildContext context) {
    return Container(
      width: 1,
      height: context.h(28),
      color: context.border,
    );
  }

  Widget _detailCell(
    BuildContext context,
    String label,
    String value,
    Color valueColor, {
    CrossAxisAlignment align = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: AppStyles.eyebrow.copyWith(
            color: context.mutedFg,
            fontSize: context.sp(9),
          ),
        ),
        SizedBox(height: context.h(2)),
        Text(
          value,
          style: AppStyles.bodyFont.copyWith(
            fontSize: context.sp(13),
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Payments Bottom Sheet
// ─────────────────────────────────────────────────────────────────

class _PaymentsSheet extends StatefulWidget {
  final Map<String, dynamic> subscription;
  final double discountAmount;
  final VoidCallback onPaymentRecorded;

  const _PaymentsSheet({
    required this.subscription,
    required this.discountAmount,
    required this.onPaymentRecorded,
  });

  @override
  State<_PaymentsSheet> createState() => _PaymentsSheetState();
}

class _PaymentsSheetState extends State<_PaymentsSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _payments = [];
  bool _showForm = false;

  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  String _method = 'Cash';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('payments')
          .select()
          .eq('subscription_id', widget.subscription['id'])
          .order('payment_date', ascending: false);
      if (mounted) {
        setState(() {
          _payments = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching payments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recordPayment() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);
    try {
      await supabase.from('payments').insert({
        'subscription_id': widget.subscription['id'],
        'user_id': widget.subscription['user_id'],
        'amount': amount,
        'payment_date': DateFormat('yyyy-MM-dd').format(_paymentDate),
        'payment_method': _method.toLowerCase(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      });

      _amountController.clear();
      _notesController.clear();
      setState(() {
        _showForm = false;
        _isSaving = false;
        _paymentDate = DateTime.now();
        _method = 'Cash';
      });
      await _fetchPayments();
      widget.onPaymentRecorded();
    } catch (e) {
      debugPrint('Error recording payment: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _summaryCell(BuildContext context, String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(10)),
        ),
        SizedBox(height: context.h(4)),
        Text(
          value,
          style: AppStyles.displayFont.copyWith(
            fontSize: context.sp(18),
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;
    final pass = sub['gym_passes'] ?? {};
    final profile = sub['profiles'] ?? {};
    final passPrice = (pass['price'] as num?)?.toDouble() ?? 0.0;
    final totalFee = (passPrice - widget.discountAmount).clamp(0.0, double.infinity);
    final totalPaid = _payments.fold(
      0.0,
      (sum, p) => sum + (p['amount'] as num).toDouble(),
    );
    final balance = totalFee - totalPaid;

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.r(24))),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) {
          return Column(
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: context.h(12), bottom: context.h(8)),
                  width: context.w(40),
                  height: context.h(4),
                  decoration: BoxDecoration(
                    color: context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile['full_name'] ?? 'Member',
                          style: AppStyles.displayFont.copyWith(
                            fontSize: context.sp(18),
                            fontWeight: FontWeight.bold,
                            color: context.fg,
                          ),
                        ),
                        Text(
                          pass['name'] ?? 'Pass',
                          style: AppStyles.bodyFont.copyWith(
                            color: context.mutedFg,
                            fontSize: context.sp(13),
                          ),
                        ),
                      ],
                    ),
                    if (!_showForm)
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _showForm = true),
                        icon: Icon(Icons.add, size: context.r(16), color: Colors.white),
                        label: Text(
                          'Add',
                          style: TextStyle(color: Colors.white, fontSize: context.sp(13)),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: EdgeInsets.symmetric(
                            horizontal: context.w(12),
                            vertical: context.h(8),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(context.r(10)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: context.h(12)),
              Container(
                margin: EdgeInsets.symmetric(horizontal: context.w(20)),
                padding: EdgeInsets.all(context.r(12)),
                decoration: BoxDecoration(
                  color: context.bg,
                  borderRadius: BorderRadius.circular(context.r(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryCell(context, 'TOTAL', '₹${totalFee.toStringAsFixed(0)}', context.fg),
                    _summaryCell(context, 'PAID', '₹${totalPaid.toStringAsFixed(0)}', AppColors.brand),
                    _summaryCell(
                      context,
                      'BALANCE',
                      '₹${balance.toStringAsFixed(0)}',
                      balance > 0 ? AppColors.energy : AppColors.brand,
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(12)),
              if (_showForm) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                  child: Container(
                    padding: EdgeInsets.all(context.r(16)),
                    decoration: BoxDecoration(
                      color: context.bg,
                      borderRadius: BorderRadius.circular(context.r(12)),
                      border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECORD PAYMENT',
                          style: AppStyles.eyebrow.copyWith(
                            color: context.mutedFg,
                            fontSize: context.sp(11),
                          ),
                        ),
                        SizedBox(height: context.h(12)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Amount (₹)',
                                  prefixText: '₹ ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(context.r(8)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: context.w(12),
                                    vertical: context.h(10),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: context.w(12)),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_method),
                                initialValue: _method,
                                decoration: InputDecoration(
                                  labelText: 'Method',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(context.r(8)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: context.w(12),
                                    vertical: context.h(10),
                                  ),
                                ),
                                items: ['Cash', 'UPI', 'Card']
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (v) => setState(() => _method = v!),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.h(12)),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _paymentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _paymentDate = picked);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.w(12),
                              vertical: context.h(12),
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: context.border),
                              borderRadius: BorderRadius.circular(context.r(8)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: context.r(16), color: context.mutedFg),
                                SizedBox(width: context.w(8)),
                                Text(
                                  DateFormat('MMM d, yyyy').format(_paymentDate),
                                  style: AppStyles.bodyFont.copyWith(
                                    fontSize: context.sp(14),
                                    color: context.fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: context.h(12)),
                        TextField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            labelText: 'Note (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(context.r(8)),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: context.w(12),
                              vertical: context.h(10),
                            ),
                          ),
                        ),
                        SizedBox(height: context.h(16)),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() {
                                  _showForm = false;
                                  _amountController.clear();
                                  _notesController.clear();
                                }),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.mutedFg,
                                  side: BorderSide(color: context.border),
                                  padding: EdgeInsets.symmetric(vertical: context.h(12)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(context.r(10)),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            SizedBox(width: context.w(12)),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _recordPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  padding: EdgeInsets.symmetric(vertical: context.h(12)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(context.r(10)),
                                  ),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Record Payment',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.h(12)),
              ],
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                    : _payments.isEmpty
                        ? Center(
                            child: Text(
                              'No payments recorded yet.',
                              style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                            ),
                          )
                        : ListView.builder(
                            controller: controller,
                            padding: EdgeInsets.symmetric(horizontal: context.w(20)),
                            itemCount: _payments.length,
                            itemBuilder: (context, i) {
                              final p = _payments[i];
                              final date = DateTime.parse(p['payment_date']);
                              final method =
                                  (p['payment_method'] as String?)?.toUpperCase() ?? 'CASH';
                              final methodColor = method == 'UPI'
                                  ? AppColors.brand
                                  : method == 'CARD'
                                      ? AppColors.energy
                                      : context.mutedFg;

                              return Container(
                                margin: EdgeInsets.only(bottom: context.h(8)),
                                padding: EdgeInsets.all(context.r(12)),
                                decoration: BoxDecoration(
                                  color: context.bg,
                                  borderRadius: BorderRadius.circular(context.r(10)),
                                  border: Border.all(color: context.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: context.r(40),
                                      height: context.r(40),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(context.r(10)),
                                      ),
                                      child: Icon(
                                        Icons.payments_outlined,
                                        color: AppColors.brand,
                                        size: context.r(20),
                                      ),
                                    ),
                                    SizedBox(width: context.w(12)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '₹${(p['amount'] as num).toStringAsFixed(0)}',
                                            style: AppStyles.displayFont.copyWith(
                                              fontSize: context.sp(16),
                                              fontWeight: FontWeight.bold,
                                              color: context.fg,
                                            ),
                                          ),
                                          if (p['notes'] != null &&
                                              (p['notes'] as String).isNotEmpty)
                                            Text(
                                              p['notes'] as String,
                                              style: AppStyles.bodyFont.copyWith(
                                                fontSize: context.sp(12),
                                                color: context.mutedFg,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: context.w(8),
                                            vertical: context.h(3),
                                          ),
                                          decoration: BoxDecoration(
                                            color: methodColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(context.r(6)),
                                          ),
                                          child: Text(
                                            method,
                                            style: AppStyles.eyebrow.copyWith(
                                              color: methodColor,
                                              fontSize: context.sp(10),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: context.h(4)),
                                        Text(
                                          DateFormat('MMM d, yyyy').format(date),
                                          style: AppStyles.bodyFont.copyWith(
                                            fontSize: context.sp(12),
                                            color: context.mutedFg,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
