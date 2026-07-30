import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../core/utils/csv_export.dart';
import '../../main.dart';

/// Simple, non-technical daily report: every payment received on a given
/// day, who it was from, how it was paid, and what they still owe.
class AdminDailyRevenueScreen extends StatefulWidget {
  const AdminDailyRevenueScreen({super.key});

  @override
  State<AdminDailyRevenueScreen> createState() => _AdminDailyRevenueScreenState();
}

class _Txn {
  final String name;
  final String phone;
  final String passType;
  final double packageAmount;
  final double discount;
  final String paymentMethod;
  final double paidAmount;
  final double balanceAmount;
  _Txn(
    this.name,
    this.phone,
    this.passType,
    this.packageAmount,
    this.discount,
    this.paymentMethod,
    this.paidAmount,
    this.balanceAmount,
  );
}

class _AdminDailyRevenueScreenState extends State<AdminDailyRevenueScreen> {
  bool _loading = true;
  bool _exporting = false;
  DateTime _day = DateTime.now();
  List<_Txn> _txns = [];
  double _totalRevenue = 0;

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  String get _dayLabel {
    if (_isToday) return 'Today';
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (_day.year == yesterday.year && _day.month == yesterday.month && _day.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, d MMMM').format(_day);
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final dayStr = DateFormat('yyyy-MM-dd').format(_day);

    try {
      final payRows = await supabase
          .from('payments')
          .select('''
            amount, payment_method, subscription_id,
            subscriptions:subscription_id (
              discount_amount,
              profiles:user_id ( full_name, phone ),
              gym_passes:pass_id ( name, price )
            )
          ''')
          .eq('payment_date', dayStr)
          .order('created_at') as List;

      final ids = <String>{
        for (final r in payRows) r['subscription_id'] as String? ?? '',
      }..remove('');

      final Map<String, double> paidToDate = {};
      if (ids.isNotEmpty) {
        final totals = await supabase
            .from('payments')
            .select('subscription_id, amount')
            .inFilter('subscription_id', ids.toList()) as List;
        for (final t in totals) {
          final sid = t['subscription_id'] as String;
          paidToDate[sid] = (paidToDate[sid] ?? 0) + (t['amount'] as num).toDouble();
        }
      }

      final txns = <_Txn>[];
      double total = 0;
      for (final r in payRows) {
        final sub = r['subscriptions'] as Map?;
        final p = sub?['profiles'] as Map?;
        final g = sub?['gym_passes'] as Map?;
        final sid = r['subscription_id'] as String? ?? '';
        final price = (g?['price'] as num?)?.toDouble() ?? 0;
        final discount = (sub?['discount_amount'] as num?)?.toDouble() ?? 0;
        final effectiveFee = (price - discount).clamp(0, double.infinity);
        final paid = (r['amount'] as num).toDouble();
        final balance = (effectiveFee - (paidToDate[sid] ?? 0)).clamp(0, double.infinity);

        txns.add(_Txn(
          p?['full_name'] as String? ?? 'Member',
          p?['phone'] as String? ?? '',
          g?['name'] as String? ?? 'Pass',
          price,
          discount,
          (r['payment_method'] as String? ?? '').toUpperCase(),
          paid,
          balance.toDouble(),
        ));
        total += paid;
      }

      if (mounted) {
        setState(() {
          _txns = txns;
          _totalRevenue = total;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeDay(int delta) {
    if (delta > 0 && _isToday) return;
    setState(() => _day = _day.add(Duration(days: delta)));
    _fetch();
  }

  // Escapes a value for CSV output
  String _csvValue(dynamic val) => '"${(val ?? '').toString().replaceAll('"', '""')}"';

  Future<void> _download() async {
    setState(() => _exporting = true);
    try {
      final dateStr = DateFormat('dd/MM/yyyy').format(_day);
      final buf = StringBuffer(
        'S.No,Date,Member Name,Mobile Number,Subscription Type,Package Amount (₹),Discount (₹),Mode of Payment,Paid Amount (₹),Balance Amount (₹)\n',
      );
      for (int i = 0; i < _txns.length; i++) {
        final t = _txns[i];
        buf.writeln([
          (i + 1).toString(),
          '"=""$dateStr"""',
          _csvValue(t.name),
          '"=""${t.phone}"""',
          _csvValue(t.passType),
          t.packageAmount.toStringAsFixed(0),
          t.discount.toStringAsFixed(0),
          _csvValue(t.paymentMethod),
          t.paidAmount.toStringAsFixed(0),
          t.balanceAmount.toStringAsFixed(0),
        ].join(','));
      }
      buf.writeln();
      buf.writeln(',,,,,,,,TOTAL REVENUE (₹),${_totalRevenue.toStringAsFixed(0)}');

      final filename = 'daily_revenue_${DateFormat('yyyy_MM_dd').format(_day)}.csv';
      await exportCsv(buf.toString(), filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download the report. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Daily Revenue Report',
          style: AppStyles.displayFont.copyWith(fontSize: context.sp(18), fontWeight: FontWeight.bold, color: context.fg),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.w(8)),
            child: IconButton(
              onPressed: (_loading || _exporting || _txns.isEmpty) ? null : _download,
              icon: _exporting
                  ? SizedBox(
                      width: context.r(18),
                      height: context.r(18),
                      child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2),
                    )
                  : Icon(Icons.download_outlined, color: context.fg),
              tooltip: 'Download report',
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _fetch,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  context.w(AppStyles.containerPadding),
                  context.h(8),
                  context.w(AppStyles.containerPadding),
                  context.h(40),
                ),
                children: [
                  _daySelector(context),
                  SizedBox(height: context.h(16)),
                  _summaryCard(context, currency),
                  SizedBox(height: context.h(24)),
                  if (_txns.isEmpty)
                    _emptyState(context)
                  else
                    ...List.generate(_txns.length, (i) => Padding(
                          padding: EdgeInsets.only(bottom: context.h(10)),
                          child: _txnCard(context, i + 1, _txns[i], currency),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _daySelector(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _changeDay(-1),
          icon: Icon(Icons.chevron_left, color: context.fg),
        ),
        Text(
          _dayLabel,
          style: AppStyles.displayFont.copyWith(fontSize: context.sp(16), fontWeight: FontWeight.bold, color: context.fg),
        ),
        IconButton(
          onPressed: _isToday ? null : () => _changeDay(1),
          icon: Icon(Icons.chevron_right, color: _isToday ? context.mutedFg.withValues(alpha: 0.3) : context.fg),
        ),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, NumberFormat currency) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.r(24)),
      decoration: BoxDecoration(
        gradient: AppColors.gradientInk,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL REVENUE', style: AppStyles.eyebrow.copyWith(color: Colors.white70)),
          SizedBox(height: context.h(8)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currency.format(_totalRevenue),
              style: AppStyles.displayFont.copyWith(fontSize: context.sp(38), fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          SizedBox(height: context.h(6)),
          Text(
            '${_txns.length} payment${_txns.length == 1 ? '' : 's'} recorded',
            style: AppStyles.bodyFont.copyWith(color: Colors.white70, fontSize: context.sp(12)),
          ),
        ],
      ),
    );
  }

  Widget _txnCard(BuildContext context, int sno, _Txn t, NumberFormat currency) {
    return Container(
      padding: EdgeInsets.all(context.r(16)),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: context.w(22),
                child: Text(
                  sno.toString(),
                  style: AppStyles.bodyFont.copyWith(fontSize: context.sp(12), fontWeight: FontWeight.w600, color: context.mutedFg),
                ),
              ),
              SizedBox(width: context.w(4)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name,
                      style: AppStyles.bodyFont.copyWith(fontSize: context.sp(14), fontWeight: FontWeight.w700, color: context.fg),
                    ),
                    if (t.phone.isNotEmpty) ...[
                      SizedBox(height: context.h(2)),
                      Text(
                        t.phone,
                        style: AppStyles.bodyFont.copyWith(fontSize: context.sp(11), color: context.mutedFg),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                currency.format(t.paidAmount),
                style: AppStyles.displayFont.copyWith(fontSize: context.sp(16), fontWeight: FontWeight.bold, color: AppColors.brand),
              ),
            ],
          ),
          SizedBox(height: context.h(8)),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: context.w(8), vertical: context.h(3)),
                decoration: BoxDecoration(
                  color: AppColors.aqua.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(context.r(6)),
                ),
                child: Text(t.passType, style: AppStyles.eyebrow.copyWith(fontSize: context.sp(9), color: AppColors.aqua)),
              ),
              SizedBox(width: context.w(6)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: context.w(8), vertical: context.h(3)),
                decoration: BoxDecoration(
                  color: context.mutedFg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.r(6)),
                ),
                child: Text(t.paymentMethod, style: AppStyles.eyebrow.copyWith(fontSize: context.sp(9), color: context.mutedFg)),
              ),
              const Spacer(),
              Text(
                t.balanceAmount > 0 ? 'Balance ${currency.format(t.balanceAmount)}' : 'Fully Paid',
                style: AppStyles.bodyFont.copyWith(
                  fontSize: context.sp(11),
                  fontWeight: FontWeight.w600,
                  color: t.balanceAmount > 0 ? AppColors.energy : AppColors.brand,
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(8)),
          Row(
            children: [
              Text(
                'Package ${currency.format(t.packageAmount)}',
                style: AppStyles.bodyFont.copyWith(fontSize: context.sp(11), color: context.mutedFg),
              ),
              if (t.discount > 0) ...[
                SizedBox(width: context.w(10)),
                Text(
                  'Discount ${currency.format(t.discount)}',
                  style: AppStyles.bodyFont.copyWith(fontSize: context.sp(11), color: AppColors.energy, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.r(32)),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: context.r(40), color: context.mutedFg),
          SizedBox(height: context.h(12)),
          Text(
            'No payments recorded on this day.',
            textAlign: TextAlign.center,
            style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13), height: 1.5),
          ),
        ],
      ),
    );
  }
}
