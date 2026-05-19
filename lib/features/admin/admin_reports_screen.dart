import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../core/utils/csv_export.dart';
import '../../main.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final Set<String> _loading = {};
  final Set<int> _expanded = {0};

  String _stamp() => DateFormat('yyyyMMdd').format(DateTime.now());

  // Escapes a value for CSV output
  String _v(dynamic val) {
    final s = (val ?? '').toString();
    return '"${s.replaceAll('"', '""')}"';
  }

  String _fmt(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    return dt != null ? DateFormat('dd/MM/yyyy').format(dt.toLocal()) : '';
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    return dt != null ? DateFormat('hh:mm a').format(dt.toLocal()) : '';
  }

  Future<void> _run(String id, Future<String> Function() fn, String file) async {
    setState(() => _loading.add(id));
    try {
      final csv = await fn();
      await exportCsv(csv, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading.remove(id));
    }
  }

  // Parses a single CSV row, respecting double-quoted fields
  List<String> _parseRow(String row) {
    final result = <String>[];
    bool inQuotes = false;
    final buf = StringBuffer();
    for (int i = 0; i < row.length; i++) {
      final c = row[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }

  Future<void> _viewReport(String id, String title, Future<String> Function() fn) async {
    setState(() => _loading.add('view_$id'));
    String csv;
    try {
      csv = await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
      if (mounted) setState(() => _loading.remove('view_$id'));
      return;
    }
    if (mounted) setState(() => _loading.remove('view_$id'));
    if (!mounted) return;

    final lines = csv
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available.')),
      );
      return;
    }

    final headers = _parseRow(lines[0]);
    // Skip summary/total lines (they start with commas or known keywords)
    final rows = lines
        .skip(1)
        .where((l) => !l.startsWith(',') && !RegExp(r'^[A-Za-z ]+:').hasMatch(l))
        .map(_parseRow)
        .where((r) => r.length == headers.length)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: ctx.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppStyles.displayFont.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ctx.fg,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${rows.length} records',
                        style: AppStyles.eyebrow.copyWith(
                          color: AppColors.brand,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: ctx.border),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, size: 40, color: ctx.mutedFg),
                            const SizedBox(height: 12),
                            Text(
                              'No records found.',
                              style: AppStyles.bodyFont.copyWith(color: ctx.mutedFg),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final row = rows[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ctx.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ctx.border.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (row.isNotEmpty)
                                  Text(
                                    row[0].isEmpty ? '—' : row[0],
                                    style: AppStyles.bodyFont.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: ctx.fg,
                                    ),
                                  ),
                                if (headers.length > 1) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      for (int j = 1; j < headers.length && j < row.length; j++)
                                        _buildKv(ctx, headers[j], row[j].isEmpty ? '—' : row[j]),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKv(BuildContext context, String key, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key.toUpperCase(),
          style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: 9),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppStyles.bodyFont.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.fg,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────
  // 1. MEMBERSHIP REPORTS
  // ──────────────────────────────────────────────────────

  Future<String> _activeMembers() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await supabase
        .from('subscriptions')
        .select('created_at, end_date, profiles(full_name, phone), gym_passes(name, price)')
        .gte('end_date', today)
        .neq('status', 'cancelled')
        .order('end_date') as List;

    final now = DateTime.now();
    final buf = StringBuffer('Member Name,Phone,Pass Type,Price (₹),Joined,Expiry,Days Left\n');
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      final end = DateTime.tryParse(r['end_date'] ?? '');
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']), _v(g?['name']),
        g?['price']?.toString() ?? '0',
        _fmt(r['created_at']),
        _fmt(r['end_date']),
        end != null ? end.difference(now).inDays.toString() : '',
      ].join(','));
    }
    return buf.toString();
  }

  Future<String> _expiredMembers() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await supabase
        .from('subscriptions')
        .select('end_date, profiles(full_name, phone), gym_passes(name, price)')
        .lt('end_date', today)
        .order('end_date', ascending: false) as List;

    final now = DateTime.now();
    final buf = StringBuffer('Member Name,Phone,Pass Type,Price (₹),Expired On,Days Since Expiry\n');
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      final end = DateTime.tryParse(r['end_date'] ?? '');
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']), _v(g?['name']),
        g?['price']?.toString() ?? '0',
        _fmt(r['end_date']),
        end != null ? now.difference(end).inDays.toString() : '',
      ].join(','));
    }
    return buf.toString();
  }

  Future<String> _upcomingExpiry() async {
    final today = DateTime.now();
    final in30 = today.add(const Duration(days: 30));
    final rows = await supabase
        .from('subscriptions')
        .select('end_date, profiles(full_name, phone), gym_passes(name)')
        .gte('end_date', today.toIso8601String().substring(0, 10))
        .lte('end_date', in30.toIso8601String().substring(0, 10))
        .neq('status', 'cancelled')
        .order('end_date') as List;

    final buf = StringBuffer('Member Name,Phone,Pass Type,Expiry Date,Days Left\n');
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      final end = DateTime.tryParse(r['end_date'] ?? '');
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']), _v(g?['name']),
        _fmt(r['end_date']),
        end != null ? end.difference(today).inDays.toString() : '',
      ].join(','));
    }
    return buf.toString();
  }

  Future<String> _newAdmissions() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final rows = await supabase
        .from('subscriptions')
        .select('created_at, end_date, profiles(full_name, phone), gym_passes(name, price)')
        .gte('created_at', monthStart)
        .order('created_at', ascending: false) as List;

    final buf = StringBuffer('Member Name,Phone,Pass Type,Price (₹),Join Date,Expiry Date\n');
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']), _v(g?['name']),
        g?['price']?.toString() ?? '0',
        _fmt(r['created_at']), _fmt(r['end_date']),
      ].join(','));
    }
    return buf.toString();
  }

  Future<String> _typeWise() async {
    final today = DateTime.now();
    final rows = await supabase
        .from('subscriptions')
        .select('end_date, status, gym_passes(name, price)') as List;

    final Map<String, Map<String, dynamic>> grouped = {};
    for (final r in rows) {
      final g = r['gym_passes'] as Map?;
      final name = g?['name'] as String? ?? 'Unknown';
      final end = DateTime.tryParse(r['end_date'] ?? '');
      final active = end != null && end.isAfter(today) && r['status'] != 'cancelled';
      grouped.putIfAbsent(name, () => {'price': g?['price'] ?? 0, 'active': 0, 'expired': 0});
      if (active) {
        grouped[name]!['active'] = (grouped[name]!['active'] as int) + 1;
      } else {
        grouped[name]!['expired'] = (grouped[name]!['expired'] as int) + 1;
      }
    }

    final buf = StringBuffer('Pass Type,Price (₹),Active,Expired,Total\n');
    for (final e in grouped.entries) {
      final a = e.value['active'] as int;
      final x = e.value['expired'] as int;
      buf.writeln([_v(e.key), e.value['price'].toString(), a, x, a + x].join(','));
    }
    return buf.toString();
  }

  Future<String> _genderWise() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await supabase
        .from('subscriptions')
        .select('profiles(full_name, phone, gender), gym_passes(name)')
        .gte('end_date', today)
        .neq('status', 'cancelled') as List;

    final buf = StringBuffer('Member Name,Phone,Gender,Pass Type\n');
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']),
        _v(p?['gender'] ?? 'Not specified'), _v(g?['name']),
      ].join(','));
    }
    return buf.toString();
  }

  // ──────────────────────────────────────────────────────
  // 2. PAYMENT & FINANCE REPORTS
  // ──────────────────────────────────────────────────────

  Future<String> _monthlyCollection() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final monthStartDate = DateTime(now.year, now.month, 1)
        .toIso8601String()
        .substring(0, 10);

    final subRows = await supabase
        .from('subscriptions')
        .select('created_at, profiles(full_name, phone), gym_passes(name, price)')
        .gte('created_at', monthStart)
        .order('created_at', ascending: false) as List;

    final payRows = await supabase
        .from('payments')
        .select('''
          amount,
          subscriptions:subscription_id (
            profiles:user_id ( full_name, phone ),
            gym_passes:pass_id ( name )
          )
        ''')
        .gte('payment_date', monthStartDate) as List;

    final Map<String, _UserCollection> grouped = {};

    for (final r in subRows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      final phone = p?['phone'] as String? ?? '';
      grouped.putIfAbsent(phone, () => _UserCollection(p?['full_name'] ?? '', phone, g?['name'] ?? ''));
      grouped[phone]!.newSub += (g?['price'] as num?)?.toDouble() ?? 0;
    }

    for (final r in payRows) {
      final sub = r['subscriptions'] as Map?;
      final p = sub?['profiles'] as Map?;
      final g = sub?['gym_passes'] as Map?;
      final phone = p?['phone'] as String? ?? '';
      grouped.putIfAbsent(phone, () => _UserCollection(p?['full_name'] ?? '', phone, g?['name'] ?? ''));
      grouped[phone]!.installments += (r['amount'] as num).toDouble();
    }

    double grandTotal = 0;
    final buf = StringBuffer('Member Name,Phone,Pass Type,New Sub (₹),Installments (₹),Total (₹)\n');
    for (final u in grouped.values) {
      final total = u.newSub + u.installments;
      grandTotal += total;
      buf.writeln([
        _v(u.name), _v(u.phone), _v(u.passType),
        u.newSub.toStringAsFixed(0),
        u.installments.toStringAsFixed(0),
        total.toStringAsFixed(0),
      ].join(','));
    }
    buf.writeln();
    buf.writeln(',,,,,GRAND TOTAL (₹),${grandTotal.toStringAsFixed(0)}');
    return buf.toString();
  }

  Future<String> _dailyCollection() async {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    final subRows = await supabase
        .from('subscriptions')
        .select('created_at, profiles(full_name, phone), gym_passes(name, price)')
        .gte('created_at', '${todayStr}T00:00:00')
        .lte('created_at', '${todayStr}T23:59:59')
        .order('created_at') as List;

    final payRows = await supabase
        .from('payments')
        .select('''
          amount,
          subscriptions:subscription_id (
            profiles:user_id ( full_name, phone ),
            gym_passes:pass_id ( name )
          )
        ''')
        .eq('payment_date', todayStr) as List;

    final Map<String, _UserCollection> grouped = {};

    for (final r in subRows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      final phone = p?['phone'] as String? ?? '';
      grouped.putIfAbsent(phone, () => _UserCollection(p?['full_name'] ?? '', phone, g?['name'] ?? ''));
      grouped[phone]!.newSub += (g?['price'] as num?)?.toDouble() ?? 0;
    }

    for (final r in payRows) {
      final sub = r['subscriptions'] as Map?;
      final p = sub?['profiles'] as Map?;
      final g = sub?['gym_passes'] as Map?;
      final phone = p?['phone'] as String? ?? '';
      grouped.putIfAbsent(phone, () => _UserCollection(p?['full_name'] ?? '', phone, g?['name'] ?? ''));
      grouped[phone]!.installments += (r['amount'] as num).toDouble();
    }

    double grandTotal = 0;
    final buf = StringBuffer('Member Name,Phone,Pass Type,New Sub (₹),Installments (₹),Total (₹)\n');
    for (final u in grouped.values) {
      final total = u.newSub + u.installments;
      grandTotal += total;
      buf.writeln([
        _v(u.name), _v(u.phone), _v(u.passType),
        u.newSub.toStringAsFixed(0),
        u.installments.toStringAsFixed(0),
        total.toStringAsFixed(0),
      ].join(','));
    }
    buf.writeln();
    buf.writeln(',,,,,GRAND TOTAL (₹),${grandTotal.toStringAsFixed(0)}');
    return buf.toString();
  }

  Future<String> _pendingRenewals() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await supabase
        .from('subscriptions')
        .select('end_date, profiles(full_name, phone), gym_passes(name, price)')
        .lt('end_date', today)
        .order('end_date', ascending: false) as List;

    final now = DateTime.now();
    final buf = StringBuffer('Member Name,Phone,Last Pass,Last Price (₹),Expired On,Days Overdue\n');
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      final end = DateTime.tryParse(r['end_date'] ?? '');
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']), _v(g?['name']),
        g?['price']?.toString() ?? '0',
        _fmt(r['end_date']),
        end != null ? now.difference(end).inDays.toString() : '',
      ].join(','));
    }
    return buf.toString();
  }

  Future<String> _revenueByPass() async {
    final rows = await supabase
        .from('subscriptions')
        .select('gym_passes(name, price)') as List;

    final Map<String, _PassRevenue> totals = {};
    for (final r in rows) {
      final g = r['gym_passes'] as Map?;
      final name = g?['name'] as String? ?? 'Unknown';
      final price = (g?['price'] as num?)?.toDouble() ?? 0;
      totals.putIfAbsent(name, () => _PassRevenue(price));
      totals[name]!.count++;
      totals[name]!.total += price;
    }

    final buf = StringBuffer('Pass Type,Price (₹),Subscriptions,Total Revenue (₹)\n');
    double grand = 0;
    for (final e in totals.entries) {
      grand += e.value.total;
      buf.writeln([
        _v(e.key), e.value.price.toStringAsFixed(0),
        e.value.count.toString(), e.value.total.toStringAsFixed(0),
      ].join(','));
    }
    buf.writeln();
    buf.writeln(',,GRAND TOTAL (₹),${grand.toStringAsFixed(0)}');
    return buf.toString();
  }

  // ──────────────────────────────────────────────────────
  // 3. ATTENDANCE REPORTS
  // ──────────────────────────────────────────────────────

  Future<String> _dailyAttendance() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final rows = await supabase
        .from('check_ins')
        .select('checked_in_at, profiles(full_name, phone)')
        .gte('checked_in_at', '${today}T00:00:00')
        .lte('checked_in_at', '${today}T23:59:59')
        .order('checked_in_at') as List;

    final buf = StringBuffer('Member Name,Phone,Check-in Time\n');
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      buf.writeln([_v(p?['full_name']), _v(p?['phone']), _fmtTime(r['checked_in_at'])].join(','));
    }
    buf.writeln();
    buf.writeln('Total Check-ins: ${rows.length}');
    return buf.toString();
  }

  Future<String> _monthlyAttendance() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final rows = await supabase
        .from('check_ins')
        .select('checked_in_at, profiles(full_name, phone)')
        .gte('checked_in_at', monthStart)
        .order('checked_in_at') as List;

    final buf = StringBuffer('Member Name,Phone,Date,Time\n');
    for (final r in rows) {
      final p = r['profiles'] as Map?;
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']),
        _fmt(r['checked_in_at']), _fmtTime(r['checked_in_at']),
      ].join(','));
    }
    buf.writeln();
    buf.writeln('Total Check-ins This Month: ${rows.length}');
    return buf.toString();
  }

  Future<String> _visitFrequency() async {
    final rows = await supabase
        .from('check_ins')
        .select('user_id, checked_in_at, profiles(full_name, phone)') as List;

    final Map<String, _VisitData> freq = {};
    for (final r in rows) {
      final uid = r['user_id'] as String? ?? '';
      final p = r['profiles'] as Map?;
      freq.putIfAbsent(uid, () => _VisitData(p?['full_name'] ?? uid, p?['phone'] ?? ''));
      freq[uid]!.count++;
      final t = r['checked_in_at'] as String? ?? '';
      if (t.compareTo(freq[uid]!.last) > 0) freq[uid]!.last = t;
    }

    final sorted = freq.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final buf = StringBuffer('Member Name,Phone,Total Visits,Last Visit\n');
    for (final m in sorted) {
      buf.writeln([_v(m.name), _v(m.phone), m.count.toString(), _fmt(m.last.isEmpty ? null : m.last)].join(','));
    }
    return buf.toString();
  }

  Future<String> _inactiveMembers() async {
    final today = DateTime.now();
    final cutoff = today.subtract(const Duration(days: 30));
    final todayStr = today.toIso8601String().substring(0, 10);

    final subs = await supabase
        .from('subscriptions')
        .select('user_id, profiles(full_name, phone), gym_passes(name)')
        .gte('end_date', todayStr)
        .neq('status', 'cancelled') as List;

    final recentCheckIns = await supabase
        .from('check_ins')
        .select('user_id')
        .gte('checked_in_at', cutoff.toIso8601String()) as List;

    final active = <String>{for (final c in recentCheckIns) c['user_id'] as String? ?? ''};

    final buf = StringBuffer('Member Name,Phone,Pass Type,Status\n');
    int count = 0;
    for (final r in subs) {
      final uid = r['user_id'] as String? ?? '';
      if (!active.contains(uid)) {
        final p = r['profiles'] as Map?;
        final g = r['gym_passes'] as Map?;
        buf.writeln([_v(p?['full_name']), _v(p?['phone']), _v(g?['name']), 'No visit in 30+ days'].join(','));
        count++;
      }
    }
    buf.writeln();
    buf.writeln('Total Inactive: $count');
    return buf.toString();
  }

  // ──────────────────────────────────────────────────────
  // 2b. INSTALLMENT / PAYMENT TRACKING REPORTS
  // ──────────────────────────────────────────────────────

  Future<String> _allInstallments() async {
    final rows = await supabase
        .from('payments')
        .select('''
          amount, payment_date, payment_method, notes,
          subscriptions:subscription_id (
            profiles:user_id ( full_name, phone ),
            gym_passes:pass_id ( name )
          )
        ''')
        .order('payment_date', ascending: false) as List;

    final buf = StringBuffer('Member Name,Phone,Pass Type,Amount (₹),Method,Date,Note\n');
    for (final r in rows) {
      final sub = r['subscriptions'] as Map?;
      final p = sub?['profiles'] as Map?;
      final g = sub?['gym_passes'] as Map?;
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']), _v(g?['name']),
        (r['amount'] as num).toStringAsFixed(0),
        _v(r['payment_method']),
        _fmt(r['payment_date']),
        _v(r['notes'] ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  Future<String> _outstandingBalances() async {
    final subs = await supabase
        .from('subscriptions')
        .select('''
          id,
          profiles:user_id ( full_name, phone ),
          gym_passes:pass_id ( name, price )
        ''')
        .neq('status', 'cancelled') as List;

    final payments = await supabase
        .from('payments')
        .select('subscription_id, amount') as List;

    final Map<String, double> paidMap = {};
    for (final p in List<Map<String, dynamic>>.from(payments)) {
      final sid = p['subscription_id'] as String;
      paidMap[sid] = (paidMap[sid] ?? 0) + (p['amount'] as num).toDouble();
    }

    final buf = StringBuffer('Member Name,Phone,Pass Type,Total Fee (₹),Paid (₹),Balance (₹)\n');
    double totalBalance = 0;
    for (final r in subs) {
      final id = r['id'] as String;
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      final fee = (g?['price'] as num?)?.toDouble() ?? 0;
      final paid = paidMap[id] ?? 0;
      final balance = fee - paid;
      if (balance > 0) {
        totalBalance += balance;
        buf.writeln([
          _v(p?['full_name']), _v(p?['phone']), _v(g?['name']),
          fee.toStringAsFixed(0), paid.toStringAsFixed(0), balance.toStringAsFixed(0),
        ].join(','));
      }
    }
    buf.writeln();
    buf.writeln(',,,,,TOTAL OUTSTANDING (₹),${totalBalance.toStringAsFixed(0)}');
    return buf.toString();
  }

  Future<String> _monthlyActualCollection() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1)
        .toIso8601String()
        .substring(0, 10);

    final rows = await supabase
        .from('payments')
        .select('''
          amount, payment_date, payment_method,
          subscriptions:subscription_id (
            profiles:user_id ( full_name, phone ),
            gym_passes:pass_id ( name )
          )
        ''')
        .gte('payment_date', monthStart)
        .order('payment_date', ascending: false) as List;

    double total = 0;
    final buf = StringBuffer('Member Name,Phone,Pass Type,Amount (₹),Method,Date\n');
    for (final r in rows) {
      final sub = r['subscriptions'] as Map?;
      final p = sub?['profiles'] as Map?;
      final g = sub?['gym_passes'] as Map?;
      final amount = (r['amount'] as num).toDouble();
      total += amount;
      buf.writeln([
        _v(p?['full_name']), _v(p?['phone']), _v(g?['name']),
        amount.toStringAsFixed(0),
        _v(r['payment_method']),
        _fmt(r['payment_date']),
      ].join(','));
    }
    buf.writeln();
    buf.writeln(',,,TOTAL COLLECTED (₹),${total.toStringAsFixed(0)}');
    return buf.toString();
  }

  // ──────────────────────────────────────────────────────
  // 4. LEAD & INQUIRY — coming soon (no table yet)
  // ──────────────────────────────────────────────────────

  // ──────────────────────────────────────────────────────
  // Grouped collection viewer (user → transactions)
  // ──────────────────────────────────────────────────────

  Future<void> _showCollectionSheet(String title, bool isToday) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1)
        .toIso8601String()
        .substring(0, 10);

    final subRows = await supabase
        .from('subscriptions')
        .select('created_at, profiles(full_name, phone), gym_passes(name, price)')
        .gte('created_at', isToday ? '${todayStr}T00:00:00' : '${monthStart}T00:00:00')
        .lte('created_at', isToday ? '${todayStr}T23:59:59' : '${todayStr}T23:59:59')
        .order('created_at') as List;

    final payRows = await supabase
        .from('payments')
        .select('''
          amount, payment_date, payment_method,
          subscriptions:subscription_id (
            profiles:user_id ( full_name, phone ),
            gym_passes:pass_id ( name )
          )
        ''')
        .gte('payment_date', isToday ? todayStr : monthStart)
        .lte('payment_date', todayStr)
        .order('payment_date') as List;

    // Group by phone
    final Map<String, _UserGroup> grouped = {};

    for (final r in subRows) {
      final p = r['profiles'] as Map?;
      final g = r['gym_passes'] as Map?;
      final phone = p?['phone'] as String? ?? '';
      grouped.putIfAbsent(phone, () => _UserGroup(p?['full_name'] ?? '', phone, g?['name'] ?? ''));
      grouped[phone]!.txns.add(_UserTxn(
        'New Subscription',
        (g?['price'] as num?)?.toDouble() ?? 0,
        _fmt(r['created_at']),
      ));
    }

    for (final r in payRows) {
      final sub = r['subscriptions'] as Map?;
      final p = sub?['profiles'] as Map?;
      final g = sub?['gym_passes'] as Map?;
      final phone = p?['phone'] as String? ?? '';
      grouped.putIfAbsent(phone, () => _UserGroup(p?['full_name'] ?? '', phone, g?['name'] ?? ''));
      grouped[phone]!.txns.add(_UserTxn(
        'Installment',
        (r['amount'] as num).toDouble(),
        _fmt(r['payment_date']),
        method: r['payment_method'] as String?,
      ));
    }

    if (!mounted) return;

    final groups = grouped.values.toList();
    final grandTotal = groups.fold(0.0, (s, g) => s + (g.total));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: ctx.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: ctx.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                        style: AppStyles.displayFont.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: ctx.fg)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${groups.length} members',
                        style: AppStyles.eyebrow.copyWith(color: AppColors.brand, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: ctx.border),
              Expanded(
                child: groups.isEmpty
                    ? Center(child: Text('No records found.', style: AppStyles.bodyFont.copyWith(color: ctx.mutedFg)))
                    : ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: groups.length + 1,
                        itemBuilder: (_, i) {
                          if (i == groups.length) {
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('GRAND TOTAL',
                                    style: AppStyles.eyebrow.copyWith(color: AppColors.brand, fontSize: 11)),
                                  Text('₹${grandTotal.toStringAsFixed(0)}',
                                    style: AppStyles.displayFont.copyWith(
                                      fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.brand)),
                                ],
                              ),
                            );
                          }
                          final g = groups[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: ctx.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ctx.border.withValues(alpha: 0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User header
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(g.name,
                                            style: AppStyles.bodyFont.copyWith(
                                              fontSize: 14, fontWeight: FontWeight.bold, color: ctx.fg)),
                                          Text('${g.phone}  ·  ${g.passType}',
                                            style: AppStyles.bodyFont.copyWith(fontSize: 11, color: ctx.mutedFg)),
                                        ],
                                      ),
                                      Text('₹${g.total.toStringAsFixed(0)}',
                                        style: AppStyles.displayFont.copyWith(
                                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.brand)),
                                    ],
                                  ),
                                ),
                                Divider(height: 1, color: ctx.border.withValues(alpha: 0.5)),
                                // Transactions
                                ...g.txns.map((t) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (t.type == 'New Subscription'
                                              ? AppColors.brand : AppColors.energy).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(t.type,
                                          style: AppStyles.eyebrow.copyWith(
                                            fontSize: 9,
                                            color: t.type == 'New Subscription' ? AppColors.brand : AppColors.energy)),
                                      ),
                                      if (t.method != null) ...[
                                        const SizedBox(width: 6),
                                        Text(t.method!.toUpperCase(),
                                          style: AppStyles.eyebrow.copyWith(fontSize: 9, color: ctx.mutedFg)),
                                      ],
                                      const Spacer(),
                                      Text('₹${t.amount.toStringAsFixed(0)}',
                                        style: AppStyles.bodyFont.copyWith(
                                          fontSize: 13, fontWeight: FontWeight.w600, color: ctx.fg)),
                                      const SizedBox(width: 12),
                                      Text(t.date,
                                        style: AppStyles.bodyFont.copyWith(fontSize: 11, color: ctx.mutedFg)),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.w(AppStyles.containerPadding),
          context.h(16),
          context.w(AppStyles.containerPadding),
          context.h(120),
        ),
        children: [
          _category(
            index: 0,
            title: 'Membership Reports',
            icon: Icons.people_alt_outlined,
            color: AppColors.brand,
            items: [
              _item('active_mem',     'Active Members',             'All currently active subscriptions',       _activeMembers,    'active_members'),
              _item('expired_mem',    'Expired Members',            'Members with lapsed subscriptions',        _expiredMembers,   'expired_members'),
              _item('upcoming_exp',   'Upcoming Expiry (30 Days)',  'Members expiring within 30 days',          _upcomingExpiry,   'upcoming_expiry'),
              _item('new_adm',        'New Admissions This Month',  'Members who joined this month',            _newAdmissions,    'new_admissions'),
              _item('type_wise',      'Membership Type Wise',       'Active vs expired count per pass type',    _typeWise,         'type_wise'),
              _item('gender_wise',    'Gender Wise Members',        'Active members grouped by gender',         _genderWise,       'gender_wise'),
            ],
          ),
          SizedBox(height: context.h(12)),
          _category(
            index: 1,
            title: 'Payment & Finance Reports',
            icon: Icons.currency_rupee_outlined,
            color: AppColors.energy,
            items: [
              _item('daily_col',   "Today's Collection",   'All payments received today',         _dailyCollection,   'daily_collection',   onView: () => _showCollectionSheet("Today's Collection",   true)),
              _item('monthly_col', 'Monthly Collection',   'All payments received this month',    _monthlyCollection, 'monthly_collection', onView: () => _showCollectionSheet('Monthly Collection',    false)),
              _item('pending_ren',    'Pending Renewals / Dues',    'Expired members who have not renewed',     _pendingRenewals,       'pending_renewals'),
              _item('rev_pass',       'Revenue by Pass Type',       'Total revenue breakdown per pass',         _revenueByPass,         'revenue_by_pass'),
              _item('installments',   'Installment Payment Log',    'Every individual payment entry recorded',  _allInstallments,       'installment_log'),
              _item('outstanding',    'Outstanding Balances',       'Members who still have a pending balance', _outstandingBalances,   'outstanding_balances'),
              _item('actual_col',     'Actual Monthly Collections', 'Real cash received this month via payments table', _monthlyActualCollection, 'actual_monthly_collection'),
            ],
          ),
          SizedBox(height: context.h(12)),
          _category(
            index: 2,
            title: 'Attendance Reports',
            icon: Icons.how_to_reg_outlined,
            color: AppColors.aqua,
            items: [
              _item('daily_att',      "Today's Attendance",         'All check-ins logged today',               _dailyAttendance,  'daily_attendance'),
              _item('monthly_att',    'Monthly Attendance',         'Every check-in this month',                _monthlyAttendance,'monthly_attendance'),
              _item('visit_freq',     'Member Visit Frequency',     'Total all-time visits per member',         _visitFrequency,   'visit_frequency'),
              _item('inactive',       'Inactive Members (30 Days)', 'Active members with no visit in 30 days',  _inactiveMembers,  'inactive_members'),
            ],
          ),
          SizedBox(height: context.h(12)),
          _category(
            index: 3,
            title: 'Lead & Inquiry Reports',
            icon: Icons.person_search_outlined,
            color: AppColors.pulse,
            items: [],
            comingSoon: true,
          ),
        ],
      ),
    );
  }

  Widget _category({
    required int index,
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> items,
    bool comingSoon = false,
  }) {
    final open = _expanded.contains(index);
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => open ? _expanded.remove(index) : _expanded.add(index)),
            borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
            child: Padding(
              padding: EdgeInsets.all(context.r(16)),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.r(8)),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(context.r(8)),
                    ),
                    child: Icon(icon, color: color, size: context.r(20)),
                  ),
                  SizedBox(width: context.w(12)),
                  Expanded(
                    child: Text(
                      title,
                      style: AppStyles.displayFont.copyWith(
                        fontSize: context.sp(15),
                        fontWeight: FontWeight.bold,
                        color: context.fg,
                      ),
                    ),
                  ),
                  if (comingSoon)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: context.w(8), vertical: context.h(3)),
                      decoration: BoxDecoration(
                        color: AppColors.pulse.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.r(20)),
                      ),
                      child: Text('Soon', style: TextStyle(fontSize: context.sp(10), color: AppColors.pulse, fontWeight: FontWeight.bold)),
                    ),
                  SizedBox(width: context.w(6)),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: context.mutedFg, size: context.r(20)),
                ],
              ),
            ),
          ),
          if (open) ...[
            Divider(height: 1, color: context.border),
            if (comingSoon)
              Padding(
                padding: EdgeInsets.all(context.r(24)),
                child: Column(
                  children: [
                    Icon(Icons.construction_outlined, color: context.mutedFg, size: context.r(36)),
                    SizedBox(height: context.h(12)),
                    Text(
                      'Lead & Inquiry tracking is coming soon.\nThis will include new inquiries, follow-ups,\ntrial members and conversion rates.',
                      textAlign: TextAlign.center,
                      style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13), height: 1.5),
                    ),
                  ],
                ),
              )
            else
              ...items.map((item) => Column(children: [item, Divider(height: 1, color: context.border.withValues(alpha: 0.5))])).toList()
              ..removeLast(),
            SizedBox(height: context.h(4)),
          ],
        ],
      ),
    );
  }

  Widget _item(String id, String title, String subtitle, Future<String> Function() fn, String prefix, {VoidCallback? onView}) {
    final busy = _loading.contains(id);
    final viewing = _loading.contains('view_$id');
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppStyles.bodyFont.copyWith(fontSize: context.sp(13), fontWeight: FontWeight.w600, color: context.fg)),
                SizedBox(height: context.h(2)),
                Text(subtitle, style: AppStyles.bodyFont.copyWith(fontSize: context.sp(11), color: context.mutedFg)),
              ],
            ),
          ),
          SizedBox(width: context.w(8)),
          // View button
          SizedBox(
            height: context.h(34),
            child: ElevatedButton.icon(
              onPressed: onView ?? (viewing ? null : () => _viewReport(id, title, fn)),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.card,
                foregroundColor: context.fg,
                disabledBackgroundColor: context.card.withValues(alpha: 0.5),
                padding: EdgeInsets.symmetric(horizontal: context.w(10)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.r(8)),
                  side: BorderSide(color: context.border),
                ),
                elevation: 0,
              ),
              icon: viewing
                  ? SizedBox(width: context.r(12), height: context.r(12), child: CircularProgressIndicator(color: context.fg, strokeWidth: 2))
                  : Icon(Icons.visibility_outlined, size: context.r(14)),
              label: Text(
                viewing ? 'Loading…' : 'View',
                style: TextStyle(fontSize: context.sp(12), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: context.w(6)),
          // CSV download button
          SizedBox(
            height: context.h(34),
            child: ElevatedButton.icon(
              onPressed: busy ? null : () => _run(id, fn, '${prefix}_${_stamp()}.csv'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.5),
                padding: EdgeInsets.symmetric(horizontal: context.w(10)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.r(8))),
                elevation: 0,
              ),
              icon: busy
                  ? SizedBox(width: context.r(12), height: context.r(12), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(Icons.download_outlined, size: context.r(14)),
              label: Text(
                busy ? 'Wait…' : 'CSV',
                style: TextStyle(fontSize: context.sp(12), fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTxn {
  final String type;
  final double amount;
  final String date;
  final String? method;
  _UserTxn(this.type, this.amount, this.date, {this.method});
}

class _UserGroup {
  final String name;
  final String phone;
  final String passType;
  final List<_UserTxn> txns = [];
  double get total => txns.fold(0.0, (s, t) => s + t.amount);
  _UserGroup(this.name, this.phone, this.passType);
}

class _UserCollection {
  final String name;
  final String phone;
  final String passType;
  double newSub = 0;
  double installments = 0;
  _UserCollection(this.name, this.phone, this.passType);
}

class _PassRevenue {
  final double price;
  int count = 0;
  double total = 0;
  _PassRevenue(this.price);
}

class _VisitData {
  final String name;
  final String phone;
  int count = 0;
  String last = '';
  _VisitData(this.name, this.phone);
}
