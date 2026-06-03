// GEMINI: DO NOT change any hardcoded values in this file. 
// Always use responsive utilities (context.w, context.h, context.sp, context.r) 
// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';
import 'package:intl/intl.dart';
import 'admin_add_member_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onViewReports;
  const AdminDashboardScreen({super.key, required this.onViewReports});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  int _expiredCount = 0;
  int _criticalCount = 0;
  int _expiringCount = 0;
  List<Map<String, dynamic>> _recentActivity = [];
  String _revenueTrend = '';
  bool _isTrendPositive = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  // Runs a query and returns an empty list instead of throwing on failure.
  Future<List> _safe(Future<dynamic> query) async {
    try {
      return List.from(await query);
    } catch (_) {
      return [];
    }
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final lastMonthStart = DateTime(now.year, now.month - 1, 1).toIso8601String();

      // All queries run in parallel; each is individually fault-tolerant.
      final results = await Future.wait([
        _safe(supabase.from('subscriptions').select('id').eq('status', 'active')),
        _safe(supabase.from('payments').select('amount').gte('created_at', monthStart)),
        _safe(supabase.from('payments').select('amount').gte('created_at', lastMonthStart).lt('created_at', monthStart)),
        _safe(supabase.from('subscriptions').select('id').gte('created_at', todayStart)),
        _safe(supabase.from('classes').select('id').gt('start_time', now.toIso8601String())),
        _safe(supabase.from('subscriptions').select('end_date').neq('status', 'cancelled')),
        // Recent activity — included here so a failure above can't block them
        _safe(supabase
            .from('check_ins')
            .select('checked_in_at, profiles(full_name)')
            .order('checked_in_at', ascending: false)
            .limit(10)),
        _safe(supabase
            .from('subscriptions')
            .select('created_at, profiles(full_name), gym_passes(name)')
            .order('created_at', ascending: false)
            .limit(10)),
      ]);

      final activeMembers = (results[0]).length;
      final paymentsThisMonth = results[1];
      final revenueThisMonth = paymentsThisMonth.fold<double>(
        0.0, (sum, p) => sum + (((p as Map)['amount'] as num?)?.toDouble() ?? 0.0),
      );
      final paymentsLastMonth = results[2];
      final revenueLastMonth = paymentsLastMonth.fold<double>(
        0.0, (sum, p) => sum + (((p as Map)['amount'] as num?)?.toDouble() ?? 0.0),
      );
      final newMembersToday = (results[3]).length;
      final upcomingClasses = (results[4]).length;
      final subsList = results[5];
      final recentCheckIns = results[6];
      final recentSubs = results[7];

      // Compute month-over-month trend
      String trendLabel = '';
      bool trendPositive = true;
      if (revenueLastMonth > 0) {
        final pct = ((revenueThisMonth - revenueLastMonth) / revenueLastMonth * 100).round();
        trendPositive = pct >= 0;
        trendLabel = '${trendPositive ? '+' : ''}$pct% vs last month';
      } else if (revenueThisMonth > 0) {
        trendLabel = 'New this month';
      }

      final today = DateTime.now();
      int expired = 0, critical = 0, expiring = 0;
      for (final sub in subsList) {
        final endDateStr = (sub as Map)['end_date'] as String?;
        if (endDateStr == null) continue;
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate == null) continue;
        final days = endDate.difference(today).inDays;
        if (days < 0) {
          expired++;
        } else if (days <= 7) {
          critical++;
        } else if (days <= 30) {
          expiring++;
        }
      }

      final List<Map<String, dynamic>> activity = [];
      for (final raw in recentCheckIns) {
        final ci = raw as Map<String, dynamic>;
        final profile = ci['profiles'] as Map<String, dynamic>?;
        final name = profile?['full_name'] as String? ?? 'A member';
        final createdAt = DateTime.tryParse(ci['checked_in_at'] as String? ?? '');
        if (createdAt == null) continue;
        activity.add({
          'title': '$name checked in',
          'subtitle': 'Gym visit recorded',
          'time': createdAt,
          'icon': Icons.fitness_center,
          'color': AppColors.brand,
        });
      }
      for (final raw in recentSubs) {
        final sub = raw as Map<String, dynamic>;
        final profile = sub['profiles'] as Map<String, dynamic>?;
        final pass = sub['gym_passes'] as Map<String, dynamic>?;
        final name = profile?['full_name'] as String? ?? 'A member';
        final passName = pass?['name'] as String? ?? 'Pass';
        final createdAt = DateTime.tryParse(sub['created_at'] as String? ?? '');
        if (createdAt == null) continue;
        activity.add({
          'title': 'New subscription',
          'subtitle': '$name — $passName',
          'time': createdAt,
          'icon': Icons.card_membership,
          'color': AppColors.aqua,
        });
      }
      activity.sort((a, b) {
        final ta = a['time'] as DateTime;
        final tb = b['time'] as DateTime;
        return tb.compareTo(ta);
      });
      if (activity.length > 10) activity.length = 10;

      if (mounted) {
        setState(() {
          _stats = {
            'total_active_members': activeMembers,
            'revenue_this_month': revenueThisMonth.round(),
            'upcoming_classes': upcomingClasses,
            'new_members_today': newMembersToday,
          };
          _revenueTrend = trendLabel;
          _isTrendPositive = trendPositive;
          _expiredCount = expired;
          _criticalCount = critical;
          _expiringCount = expiring;
          _recentActivity = activity;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
      if (mounted) {
        setState(() {
          _stats = {
            'total_active_members': 0,
            'revenue_this_month': 0,
            'upcoming_classes': 0,
            'new_members_today': 0,
          };
          _isLoading = false;
        });
      }
    }
  }

  void _showManualCheckInDialog(BuildContext context) {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> matches = [];
    bool isSearching = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> search() async {
            final q = searchController.text.trim();
            if (q.isEmpty) {
              setDialogState(() => matches = []);
              return;
            }
            setDialogState(() => isSearching = true);
            try {
              final res = await supabase
                  .from('profiles')
                  .select('id, full_name, phone')
                  .ilike('full_name', '%$q%')
                  .limit(8);
              setDialogState(() {
                matches = List<Map<String, dynamic>>.from(res);
                isSearching = false;
              });
            } catch (_) {
              setDialogState(() => isSearching = false);
            }
          }

          Future<void> checkIn(Map<String, dynamic> member) async {
            setDialogState(() => isSubmitting = true);
            try {
              await supabase.from('check_ins').insert({'user_id': member['id']});
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Checked in ${member['full_name']}!'),
                    backgroundColor: AppColors.brand,
                  ),
                );
                _fetchStats();
              }
            } catch (e) {
              setDialogState(() => isSubmitting = false);
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Check-in failed. Please try again.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          }

          return AlertDialog(
            backgroundColor: context.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Manual Check-In',
              style: AppStyles.displayFont.copyWith(fontSize: 20, color: context.fg),
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (_) => search(),
                    style: AppStyles.bodyFont.copyWith(color: context.fg),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.bg,
                      hintText: 'Search by name…',
                      hintStyle: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                      prefixIcon: isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                              ),
                            )
                          : const Icon(Icons.search, color: AppColors.brand),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.brand),
                      ),
                    ),
                  ),
                  if (matches.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${matches.length} match${matches.length == 1 ? '' : 'es'} — tap to check in',
                      style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: 9),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: matches.length,
                        separatorBuilder: (context, i) => Divider(height: 1, color: context.border),
                        itemBuilder: (_, i) {
                          final m = matches[i];
                          final name = m['full_name'] as String? ?? '—';
                          final phone = m['phone'] as String? ?? '';
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: AppStyles.bodyFont.copyWith(
                                  color: AppColors.brand,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(name, style: AppStyles.bodyFont.copyWith(fontWeight: FontWeight.w600, fontSize: 14, color: context.fg)),
                            subtitle: phone.isNotEmpty
                                ? Text(phone, style: AppStyles.bodyFont.copyWith(fontSize: 12, color: context.mutedFg))
                                : null,
                            trailing: isSubmitting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand))
                                : const Icon(Icons.check_circle_outline, color: AppColors.brand, size: 20),
                            onTap: isSubmitting ? null : () => checkIn(m),
                          );
                        },
                      ),
                    ),
                  ] else if (searchController.text.isNotEmpty && !isSearching) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'No members found.',
                        style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: context.mutedFg)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }

    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    final totalMembers = _stats?['total_active_members'] ?? 0;
    final revenue = _stats?['revenue_this_month'] ?? 0;
    final upcomingClasses = _stats?['upcoming_classes'] ?? 0;
    final newMembers = _stats?['new_members_today'] ?? 0;

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: context.w(AppStyles.containerPadding)),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: context.h(8)),
          _buildHeader(context),
          SizedBox(height: context.h(24)),
          
          Text(
            'BUSINESS OVERVIEW',
            style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
          ),
          SizedBox(height: context.h(16)),
          _buildPrimaryStatCard(
            context,
            title: 'REVENUE THIS MONTH',
            value: currencyFormatter.format(revenue),
            trend: _revenueTrend,
            isPositive: _isTrendPositive,
          ),
          SizedBox(height: context.h(12)),
          Row(
            children: [
              Expanded(
                child: _buildSecondaryStatCard(
                  context,
                  title: 'ACTIVE MEMBERS',
                  value: totalMembers.toString(),
                  subtitle: '+$newMembers today',
                  icon: Icons.people,
                  color: AppColors.pulse,
                ),
              ),
              SizedBox(width: context.w(12)),
              Expanded(
                child: _buildSecondaryStatCard(
                  context,
                  title: 'UPCOMING CLASSES',
                  value: upcomingClasses.toString(),
                  subtitle: 'Next 7 days',
                  icon: Icons.event,
                  color: AppColors.energy,
                ),
              ),
            ],
          ),
          if (_expiredCount > 0 || _criticalCount > 0 || _expiringCount > 0) ...[
            SizedBox(height: context.h(24)),
            Text(
              'EXPIRY ALERTS',
              style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
            ),
            SizedBox(height: context.h(12)),
            _buildExpiryAlertCard(context),
          ],
          SizedBox(height: context.h(32)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUICK ACTIONS',
                style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
              ),
            ],
          ),
          SizedBox(height: context.h(16)),
          _buildQuickActionsRow(context),
          
          SizedBox(height: context.h(32)),
          Text(
            'RECENT ACTIVITY',
            style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
          ),
          SizedBox(height: context.h(16)),
          _buildRecentActivityList(context),

          SizedBox(height: context.h(120)), // Bottom padding for nav bar
        ],
      ),
    ),
    );
  }

  Widget _buildExpiryAlertCard(BuildContext context) {
    return GestureDetector(
      onTap: widget.onViewReports,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.r(20)),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
          border: Border.all(
            color: _expiredCount > 0 || _criticalCount > 0
                ? Colors.redAccent.withValues(alpha: 0.45)
                : AppColors.sun.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(context.r(6)),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: context.r(16)),
                ),
                SizedBox(width: context.w(8)),
                Text(
                  'PASS EXPIRY ALERT',
                  style: AppStyles.eyebrow.copyWith(color: Colors.redAccent),
                ),
                const Spacer(),
                Text(
                  'View Report →',
                  style: AppStyles.bodyFont.copyWith(
                    color: AppColors.brand,
                    fontSize: context.sp(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(16)),
            Row(
              children: [
                if (_expiredCount > 0) ...[
                  _buildAlertChip(context, _expiredCount, 'Expired', Colors.redAccent),
                  SizedBox(width: context.w(8)),
                ],
                if (_criticalCount > 0) ...[
                  _buildAlertChip(context, _criticalCount, '≤ 7 Days', AppColors.energy),
                  SizedBox(width: context.w(8)),
                ],
                if (_expiringCount > 0)
                  _buildAlertChip(context, _expiringCount, '≤ 30 Days', AppColors.sun),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertChip(BuildContext context, int count, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(10)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.r(10)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: AppStyles.displayFont.copyWith(
              fontSize: context.sp(22),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: context.h(2)),
          Text(
            label,
            style: AppStyles.eyebrow.copyWith(
              fontSize: context.sp(9),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(now);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formattedDate.toUpperCase(),
                style: AppStyles.eyebrow.copyWith(
                  color: AppColors.brand,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: context.h(4)),
              Text(
                'Dashboard',
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
          onTap: _fetchStats,
          child: Container(
            padding: EdgeInsets.all(context.r(8)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.border),
            ),
            child: Icon(
              Icons.refresh,
              size: context.r(18),
              color: context.mutedFg,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryStatCard(BuildContext context, {
    required String title,
    required String value,
    required String trend,
    required bool isPositive,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.r(24)),
      decoration: BoxDecoration(
        gradient: AppColors.gradientInk,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.1),
            blurRadius: context.r(20),
            offset: Offset(0, context.h(8)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: AppColors.brand, size: context.r(20)),
                  SizedBox(width: context.w(8)),
                  Text(
                    title,
                    style: AppStyles.eyebrow.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              if (trend.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: context.w(8), vertical: context.h(4)),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.brand : AppColors.energy).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(context.r(12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? AppColors.brand : AppColors.energy,
                      size: context.r(12),
                    ),
                    SizedBox(width: context.w(4)),
                    Text(
                      trend,
                      style: AppStyles.bodyFont.copyWith(
                        color: isPositive ? AppColors.brand : AppColors.energy,
                        fontSize: context.sp(10),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(16)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppStyles.displayFont.copyWith(
                fontSize: context.sp(42),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryStatCard(BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(context.r(20)),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: context.r(10),
            offset: Offset(0, context.h(4)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.r(6)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: context.r(16)),
              ),
            ],
          ),
          SizedBox(height: context.h(16)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppStyles.displayFont.copyWith(
                fontSize: context.sp(28),
                fontWeight: FontWeight.bold,
                color: context.fg,
              ),
            ),
          ),
          SizedBox(height: context.h(4)),
          Text(
            title,
            style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(9)),
          ),
          SizedBox(height: context.h(8)),
          Text(
            subtitle,
            style: AppStyles.bodyFont.copyWith(
              color: color,
              fontSize: context.sp(11),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildActionPill(
            context,
            icon: Icons.person_add,
            label: 'Add Member',
            color: AppColors.aqua,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminAddMemberScreen(),
              ),
            ),
          ),
          SizedBox(width: context.w(12)),
          _buildActionPill(
            context,
            icon: Icons.event_available,
            label: 'Schedule Class',
            color: AppColors.energy,
            onTap: () {},
          ),
          SizedBox(width: context.w(12)),
          _buildActionPill(
            context,
            icon: Icons.campaign,
            label: 'Announce',
            color: AppColors.sun,
            onTap: () {},
          ),
          SizedBox(width: context.w(12)),
          _buildActionPill(
            context,
            icon: Icons.qr_code_scanner,
            label: 'Scan Pass',
            color: AppColors.pulse,
            onTap: () => _showManualCheckInDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(12)),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(context.r(24)),
          border: Border.all(color: context.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: context.r(8),
              offset: Offset(0, context.h(2)),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: context.r(16)),
            SizedBox(width: context.w(8)),
            Text(
              label,
              style: AppStyles.bodyFont.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: context.sp(13),
                color: context.fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }

  Widget _buildRecentActivityList(BuildContext context) {
    if (_recentActivity.isEmpty) {
      return Container(
        padding: EdgeInsets.all(context.r(24)),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(
            'No recent activity',
            style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _recentActivity.length,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, _) => Divider(height: 1, color: context.border.withValues(alpha: 0.3)),
        itemBuilder: (_, index) {
          final item = _recentActivity[index];
          final color = item['color'] as Color;
          final time = item['time'] as DateTime;
          return ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(8)),
            leading: Container(
              padding: EdgeInsets.all(context.r(10)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item['icon'] as IconData, color: color, size: context.r(18)),
            ),
            title: Text(
              item['title'] as String,
              style: AppStyles.bodyFont.copyWith(fontWeight: FontWeight.bold, fontSize: context.sp(14), color: context.fg),
            ),
            subtitle: Text(
              item['subtitle'] as String,
              style: AppStyles.bodyFont.copyWith(fontSize: context.sp(12), color: context.mutedFg),
            ),
            trailing: Text(
              _timeAgo(time),
              style: AppStyles.eyebrow.copyWith(fontSize: context.sp(9), color: context.mutedFg),
            ),
          );
        },
      ),
    );
  }
}
