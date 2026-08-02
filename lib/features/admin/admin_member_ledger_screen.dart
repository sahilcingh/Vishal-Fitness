// GEMINI: DO NOT change any hardcoded values in this file.
// Always use responsive utilities (context.w, context.h, context.sp, context.r)
// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';

enum _Category { joined, membership, payment, visit, change }

class _Entry {
  final String id;
  final DateTime date;
  final _Category category;
  final String title;
  final String? subtitle;
  _Entry({required this.id, required this.date, required this.category, required this.title, this.subtitle});
}

/// Full chronological timeline for a single member - joined, subscribed,
/// paid, checked in, edited. Mirrors member-ledger.tsx + the website's
/// /admin/members/[id] page.
class AdminMemberLedgerScreen extends StatefulWidget {
  final String userId;
  const AdminMemberLedgerScreen({super.key, required this.userId});

  @override
  State<AdminMemberLedgerScreen> createState() => _AdminMemberLedgerScreenState();
}

class _AdminMemberLedgerScreenState extends State<AdminMemberLedgerScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  List<_Entry> _entries = [];
  double _totalPaid = 0;
  int _totalVisits = 0;
  String _currentStatus = 'No subscription';

  _Category? _filter; // null = All
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _membershipNo(String userId) =>
      'MBR-${userId.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        supabase.from('profiles').select('id, full_name, phone, photo_url, created_at').eq('id', widget.userId).maybeSingle(),
        supabase
            .from('subscriptions')
            .select('id, pass_id, start_date, end_date, status, discount_amount, created_at, gym_passes:pass_id(name, price, duration_days)')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: true),
        supabase
            .from('payments')
            .select('id, amount, payment_method, payment_date, subscription_id')
            .eq('user_id', widget.userId)
            .order('payment_date', ascending: true),
        supabase.from('check_ins').select('id, checked_in_at').eq('user_id', widget.userId).order('checked_in_at', ascending: true),
        supabase
            .from('member_events')
            .select('id, event_type, description, created_at')
            .eq('user_id', widget.userId)
            .order('created_at', ascending: true),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final subscriptions = List<Map<String, dynamic>>.from(results[1] as List);
      final payments = List<Map<String, dynamic>>.from(results[2] as List);
      final checkIns = List<Map<String, dynamic>>.from(results[3] as List);
      final events = List<Map<String, dynamic>>.from(results[4] as List);

      final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
      final passNameBySub = {
        for (final s in subscriptions) s['id'] as String: (s['gym_passes'] as Map<String, dynamic>?)?['name'] as String? ?? 'Pass',
      };

      final entries = <_Entry>[];
      if (profile != null) {
        entries.add(_Entry(
          id: 'joined',
          date: DateTime.parse(profile['created_at'] as String),
          category: _Category.joined,
          title: 'Joined Vishal Fitness',
        ));
      }
      for (var i = 0; i < subscriptions.length; i++) {
        final s = subscriptions[i];
        final pass = s['gym_passes'] as Map<String, dynamic>?;
        final discount = (s['discount_amount'] as num?)?.toDouble() ?? 0;
        entries.add(_Entry(
          id: 'sub-${s['id']}',
          date: DateTime.parse(s['created_at'] as String),
          category: _Category.membership,
          title: '${i == 0 ? "Subscribed to" : "Renewed to"} ${pass?['name'] ?? "a pass"}',
          subtitle:
              '${pass?['duration_days'] ?? "-"} days · ${currency.format(pass?['price'] ?? 0)}${discount > 0 ? " · ${currency.format(discount)} discount" : ""}',
        ));
      }
      for (final p in payments) {
        final subId = p['subscription_id'] as String?;
        entries.add(_Entry(
          id: 'pay-${p['id']}',
          date: DateTime.parse(p['payment_date'] as String),
          category: _Category.payment,
          title: 'Paid ${currency.format(p['amount'])}',
          subtitle: [
            (p['payment_method'] as String?)?.toUpperCase(),
            if (subId != null) passNameBySub[subId],
          ].where((e) => e != null && e.isNotEmpty).join(' · '),
        ));
      }
      for (final c in checkIns) {
        entries.add(_Entry(
          id: 'visit-${c['id']}',
          date: DateTime.parse(c['checked_in_at'] as String),
          category: _Category.visit,
          title: 'Checked in',
        ));
      }
      for (final e in events) {
        entries.add(_Entry(
          id: 'event-${e['id']}',
          date: DateTime.parse(e['created_at'] as String),
          category: _Category.change,
          title: e['description'] as String? ?? 'Updated',
        ));
      }
      entries.sort((a, b) => b.date.compareTo(a.date));

      final totalPaid = payments.fold<double>(0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));
      final latestSub = subscriptions.isEmpty
          ? null
          : (List<Map<String, dynamic>>.from(subscriptions)
            ..sort((a, b) => DateTime.parse(b['created_at'] as String).compareTo(DateTime.parse(a['created_at'] as String))))
              .first;
      final status = latestSub == null
          ? 'No subscription'
          : ((latestSub['status'] as String).isEmpty
              ? '-'
              : (latestSub['status'] as String)[0].toUpperCase() + (latestSub['status'] as String).substring(1));

      if (mounted) {
        setState(() {
          _profile = profile;
          _entries = entries;
          _totalPaid = totalPaid;
          _totalVisits = checkIns.length;
          _currentStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching member ledger: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<_Category, int> get _counts {
    final m = {for (final c in _Category.values) c: 0};
    for (final e in _entries) {
      m[e.category] = (m[e.category] ?? 0) + 1;
    }
    return m;
  }

  List<_Entry> get _filtered {
    var list = _entries;
    if (_filter != null) {
      list = list.where((e) => e.category == _filter || (_filter == _Category.membership && e.category == _Category.joined)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((e) => e.title.toLowerCase().contains(_searchQuery) || (e.subtitle ?? '').toLowerCase().contains(_searchQuery))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['full_name'] as String? ?? 'Member';
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: AppStyles.displayFont.copyWith(fontSize: context.sp(17), fontWeight: FontWeight.bold, color: context.fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              [
                _membershipNo(widget.userId),
                if ((_profile?['phone'] as String?)?.isNotEmpty ?? false) _profile!['phone'] as String,
              ].join(' · '),
              style: AppStyles.bodyFont.copyWith(fontSize: context.sp(10.5), color: context.mutedFg),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _fetchAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.w(AppStyles.containerPadding),
                  context.h(8),
                  context.w(AppStyles.containerPadding),
                  context.h(40),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatTiles(),
                    SizedBox(height: context.h(20)),
                    if (_entries.isEmpty)
                      _emptyState()
                    else ...[
                      _buildFilterChips(),
                      SizedBox(height: context.h(12)),
                      _buildSearchBar(),
                      SizedBox(height: context.h(16)),
                      _buildEntryList(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatTiles() {
    final memberSince = _profile?['created_at'] != null
        ? DateFormat('d MMM yyyy').format(DateTime.parse(_profile!['created_at'] as String))
        : '—';
    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final tiles = [
      ('MEMBER SINCE', memberSince, context.fg),
      ('TOTAL PAID', currency.format(_totalPaid), AppColors.brand),
      ('VISITS', '$_totalVisits', context.fg),
      ('STATUS', _currentStatus, context.fg),
    ];
    return Row(
      children: tiles
          .map((t) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: t == tiles.last ? 0 : context.w(8)),
                  padding: EdgeInsets.all(context.r(12)),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(context.r(AppStyles.radiusLg)),
                    border: Border.all(color: context.border.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.$1,
                        style: AppStyles.eyebrow.copyWith(fontSize: context.sp(8), color: context.mutedFg),
                      ),
                      SizedBox(height: context.h(6)),
                      FittedBox(
                        child: Text(
                          t.$2,
                          style: AppStyles.displayFont.copyWith(fontSize: context.sp(15), fontWeight: FontWeight.bold, color: t.$3),
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _emptyState() {
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
          Icon(Icons.person_outline, color: context.mutedFg, size: context.r(36)),
          SizedBox(height: context.h(12)),
          Text(
            'No activity recorded for this member yet.',
            style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final c = _counts;
    final chips = [
      (null, 'All', _entries.length),
      (_Category.membership, 'Membership', (c[_Category.membership] ?? 0) + (c[_Category.joined] ?? 0)),
      (_Category.payment, 'Payments', c[_Category.payment] ?? 0),
      (_Category.visit, 'Visits', c[_Category.visit] ?? 0),
      (_Category.change, 'Changes', c[_Category.change] ?? 0),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final isSelected = _filter == chip.$1;
          return Padding(
            padding: EdgeInsets.only(right: context.w(8)),
            child: GestureDetector(
              onTap: () => setState(() => _filter = chip.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: context.w(14), vertical: context.h(8)),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brand : context.card,
                  borderRadius: BorderRadius.circular(context.r(20)),
                  border: Border.all(color: isSelected ? AppColors.brand : context.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chip.$2,
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: context.sp(12),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : context.mutedFg,
                      ),
                    ),
                    SizedBox(width: context.w(6)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: context.w(6), vertical: context.h(2)),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.2) : context.mutedFg.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.r(10)),
                      ),
                      child: Text(
                        '${chip.$3}',
                        style: AppStyles.bodyFont.copyWith(
                          fontSize: context.sp(10),
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : context.mutedFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: AppStyles.bodyFont.copyWith(fontSize: context.sp(14), color: context.fg),
      decoration: InputDecoration(
        hintText: 'Search this ledger...',
        hintStyle: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13)),
        prefixIcon: Icon(Icons.search, color: context.mutedFg, size: context.r(18)),
        filled: true,
        fillColor: context.card,
        contentPadding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(12)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(12)), borderSide: BorderSide(color: context.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(12)),
            borderSide: BorderSide(color: context.border.withValues(alpha: 0.6))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(context.r(12)),
            borderSide: const BorderSide(color: AppColors.brand, width: 1.5)),
      ),
    );
  }

  static const _categoryIcon = {
    _Category.joined: Icons.person_add_alt_1,
    _Category.membership: Icons.autorenew,
    _Category.payment: Icons.payments_outlined,
    _Category.visit: Icons.directions_walk,
    _Category.change: Icons.history,
  };

  Widget _buildEntryList() {
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
        child: Center(
          child: Text('Nothing here yet.', style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(13))),
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
        itemCount: items.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: context.border.withValues(alpha: 0.5)),
        itemBuilder: (_, i) => _buildEntryTile(items[i]),
      ),
    );
  }

  Widget _buildEntryTile(_Entry e) {
    final hasTime = e.category == _Category.visit || e.category == _Category.change || e.category == _Category.joined;
    final dateLabel = hasTime ? DateFormat('d MMM yyyy, h:mm a').format(e.date) : DateFormat('d MMM yyyy').format(e.date);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.w(16), vertical: context.h(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: context.r(34),
            height: context.r(34),
            decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(_categoryIcon[e.category], size: context.r(16), color: AppColors.brand),
          ),
          SizedBox(width: context.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: AppStyles.bodyFont.copyWith(fontWeight: FontWeight.w600, fontSize: context.sp(13.5), color: context.fg)),
                if (e.subtitle != null && e.subtitle!.isNotEmpty) ...[
                  SizedBox(height: context.h(2)),
                  Text(e.subtitle!, style: AppStyles.bodyFont.copyWith(fontSize: context.sp(11.5), color: context.mutedFg)),
                ],
              ],
            ),
          ),
          SizedBox(width: context.w(8)),
          Text(dateLabel, style: AppStyles.bodyFont.copyWith(fontSize: context.sp(10.5), color: context.mutedFg)),
        ],
      ),
    );
  }
}
