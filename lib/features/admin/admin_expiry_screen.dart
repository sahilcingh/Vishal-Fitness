import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/csv_export.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';

enum _Filter { all, expired, critical, expiring, healthy }

class AdminExpiryScreen extends StatefulWidget {
  const AdminExpiryScreen({super.key});

  @override
  State<AdminExpiryScreen> createState() => _AdminExpiryScreenState();
}

class _AdminExpiryScreenState extends State<AdminExpiryScreen> {
  List<Map<String, dynamic>> _subs = [];
  bool _isLoading = true;
  bool _isExporting = false;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('subscriptions')
          .select(
              'id, status, start_date, end_date, profiles(full_name, phone), gym_passes(name, price)')
          .order('end_date', ascending: true);

      if (mounted) {
        setState(() {
          _subs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching expiry data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _daysLeft(String endDate) {
    final end = DateTime.parse(endDate);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final endDate0 = DateTime(end.year, end.month, end.day);
    return endDate0.difference(todayDate).inDays;
  }

  _Filter _categoryOf(Map<String, dynamic> sub) {
    final d = _daysLeft(sub['end_date'] as String);
    if (d < 0) return _Filter.expired;
    if (d <= 7) return _Filter.critical;
    if (d <= 30) return _Filter.expiring;
    return _Filter.healthy;
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == _Filter.all ? _subs : _subs.where((s) => _categoryOf(s) == _filter).toList();

  Map<_Filter, int> get _counts {
    final m = {_Filter.expired: 0, _Filter.critical: 0, _Filter.expiring: 0, _Filter.healthy: 0};
    for (final s in _subs) {
      final c = _categoryOf(s);
      m[c] = (m[c] ?? 0) + 1;
    }
    return m;
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      final buf = StringBuffer();
      buf.writeln('Name,Phone,Pass,Status,Start Date,Expiry Date,Days Remaining');

      for (final sub in _subs) {
        final profile = sub['profiles'] as Map<String, dynamic>?;
        final pass = sub['gym_passes'] as Map<String, dynamic>?;
        final days = _daysLeft(sub['end_date'] as String);
        final statusLabel = days < 0
            ? 'Expired'
            : days <= 7
                ? 'Critical'
                : days <= 30
                    ? 'Expiring'
                    : 'Active';
        final daysLabel = days < 0 ? 'Expired ${-days}d ago' : '$days days left';

        buf.writeln([
          '"${(profile?['full_name'] as String? ?? '').replaceAll('"', '""')}"',
          '"${profile?['phone'] ?? ''}"',
          '"${(pass?['name'] as String? ?? '').replaceAll('"', '""')}"',
          '"$statusLabel"',
          '"${sub['start_date'] ?? ''}"',
          '"${sub['end_date'] ?? ''}"',
          '"$daysLabel"',
        ].join(','));
      }

      final filename =
          'member_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      await exportCsv(buf.toString(), filename);
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.energy,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(AppStyles.containerPadding)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: context.h(16)),
                    _buildHeader(),
                    SizedBox(height: context.h(24)),
                    _buildSummaryRow(),
                    SizedBox(height: context.h(24)),
                    _buildFilterChips(),
                    SizedBox(height: context.h(16)),
                    _buildList(),
                    SizedBox(height: context.h(120)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEMBER REPORTS',
                style: AppStyles.eyebrow
                    .copyWith(color: AppColors.brand, letterSpacing: 2),
              ),
              SizedBox(height: context.h(4)),
              Text(
                'Expiry Tracker',
                style: AppStyles.displayFont.copyWith(
                  fontSize: context.sp(32),
                  fontWeight: FontWeight.bold,
                  color: context.fg,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _isExporting ? null : _exportCsv,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
                horizontal: context.w(14), vertical: context.h(10)),
            decoration: BoxDecoration(
              gradient: _isExporting ? null : AppColors.gradientBrand,
              color: _isExporting ? context.muted : null,
              borderRadius: BorderRadius.circular(context.r(14)),
            ),
            child: _isExporting
                ? SizedBox(
                    width: context.r(16),
                    height: context.r(16),
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_outlined,
                          size: context.r(15), color: Colors.black),
                      SizedBox(width: context.w(6)),
                      Text(
                        'Export CSV',
                        style: AppStyles.bodyFont.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: context.sp(12),
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow() {
    final c = _counts;
    return Row(
      children: [
        _summaryChip(c[_Filter.expired] ?? 0, 'Expired', Colors.redAccent),
        SizedBox(width: context.w(8)),
        _summaryChip(c[_Filter.critical] ?? 0, '≤ 7 days', AppColors.energy),
        SizedBox(width: context.w(8)),
        _summaryChip(c[_Filter.expiring] ?? 0, '≤ 30 days', AppColors.sun),
        SizedBox(width: context.w(8)),
        _summaryChip(c[_Filter.healthy] ?? 0, 'Active', AppColors.brand),
      ],
    );
  }

  Widget _summaryChip(int count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.h(12)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(context.r(12)),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AppStyles.displayFont.copyWith(
                fontSize: context.sp(22),
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: context.h(2)),
            FittedBox(
              child: Text(
                label,
                style: AppStyles.eyebrow
                    .copyWith(fontSize: context.sp(8), color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const chips = [
      (_Filter.all, 'All'),
      (_Filter.expired, 'Expired'),
      (_Filter.critical, 'Critical'),
      (_Filter.expiring, 'Expiring'),
      (_Filter.healthy, 'Active'),
    ];
    final chipColors = {
      _Filter.all: context.mutedFg,
      _Filter.expired: Colors.redAccent,
      _Filter.critical: AppColors.energy,
      _Filter.expiring: AppColors.sun,
      _Filter.healthy: AppColors.brand,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final isSelected = _filter == chip.$1;
          final color = chipColors[chip.$1]!;
          return Padding(
            padding: EdgeInsets.only(right: context.w(8)),
            child: GestureDetector(
              onTap: () => setState(() => _filter = chip.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(16), vertical: context.h(8)),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : context.card,
                  borderRadius: BorderRadius.circular(context.r(20)),
                  border: Border.all(
                    color: isSelected ? color : context.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  chip.$2,
                  style: AppStyles.bodyFont.copyWith(
                    fontSize: context.sp(12),
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? color : context.mutedFg,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.r(32)),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppColors.brand, size: context.r(40)),
            SizedBox(height: context.h(12)),
            Text(
              'All clear!',
              style: AppStyles.displayFont.copyWith(
                  fontSize: context.sp(18), fontWeight: FontWeight.bold),
            ),
            SizedBox(height: context.h(4)),
            Text(
              'No members in this category.',
              style: AppStyles.bodyFont.copyWith(
                  color: context.mutedFg, fontSize: context.sp(13)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => SizedBox(height: context.h(8)),
      itemBuilder: (_, i) => _buildMemberCard(items[i]),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> sub) {
    final profile = sub['profiles'] as Map<String, dynamic>?;
    final pass = sub['gym_passes'] as Map<String, dynamic>?;
    final name = profile?['full_name'] as String? ?? 'Unknown';
    final phone = profile?['phone'] as String? ?? '—';
    final passName = pass?['name'] as String? ?? '—';
    final passPrice = pass?['price'];
    final endStr = sub['end_date'] as String? ?? '';
    final days = endStr.isNotEmpty ? _daysLeft(endStr) : 0;
    final formattedEnd = endStr.isNotEmpty
        ? DateFormat('d MMM yyyy').format(DateTime.parse(endStr))
        : '—';

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;
    if (days < 0) {
      statusColor = Colors.redAccent;
      statusLabel = '${-days}d overdue';
      statusIcon = Icons.warning_rounded;
    } else if (days <= 7) {
      statusColor = AppColors.energy;
      statusLabel = '$days days left';
      statusIcon = Icons.timer_outlined;
    } else if (days <= 30) {
      statusColor = AppColors.sun;
      statusLabel = '$days days left';
      statusIcon = Icons.schedule_outlined;
    } else {
      statusColor = AppColors.brand;
      statusLabel = '$days days left';
      statusIcon = Icons.check_circle_outline;
    }

    final avatarColors = [
      AppColors.aqua,
      AppColors.pulse,
      AppColors.brand,
      AppColors.energy,
      AppColors.sun
    ];
    final avatarColor = avatarColors[name.length % avatarColors.length];
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      padding: EdgeInsets.all(context.r(16)),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
        border: Border.all(
          color: days < 0
              ? Colors.redAccent.withValues(alpha: 0.25)
              : context.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Avatar with initials
          Container(
            width: context.r(44),
            height: context.r(44),
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border:
                  Border.all(color: avatarColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                initials,
                style: AppStyles.displayFont.copyWith(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.bold,
                  color: avatarColor,
                ),
              ),
            ),
          ),
          SizedBox(width: context.w(12)),

          // Name, pass, phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppStyles.bodyFont.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: context.sp(14),
                    color: context.fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.h(2)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        passName,
                        style: AppStyles.bodyFont.copyWith(
                          fontSize: context.sp(11),
                          color: context.mutedFg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (passPrice != null) ...[
                      Text(
                        ' · ₹${NumberFormat('#,##0').format(passPrice)}',
                        style: AppStyles.bodyFont.copyWith(
                          fontSize: context.sp(11),
                          color: context.mutedFg,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: context.h(2)),
                Text(
                  phone,
                  style: AppStyles.bodyFont.copyWith(
                    fontSize: context.sp(11),
                    color: context.mutedFg,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.w(8)),

          // Status badge + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(8), vertical: context.h(4)),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(context.r(8)),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon,
                        size: context.r(10), color: statusColor),
                    SizedBox(width: context.w(4)),
                    Text(
                      statusLabel,
                      style: AppStyles.eyebrow.copyWith(
                        fontSize: context.sp(9),
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(4)),
              Text(
                formattedEnd,
                style: AppStyles.bodyFont.copyWith(
                  fontSize: context.sp(11),
                  color: context.mutedFg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
