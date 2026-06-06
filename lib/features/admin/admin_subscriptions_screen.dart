// GEMINI: DO NOT change any hardcoded values in this file.
// Always use responsive utilities (context.w, context.h, context.sp, context.r)
// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart';
import 'package:intl/intl.dart';
import 'admin_edit_member_screen.dart';

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
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedPassType; // null = All
  // Cache: userId → login email
  final Map<String, String?> _memberEmails = {};
  // Cache: userId → reset in-progress
  final Set<String> _resettingPassword = {};

  /// Unique pass type names extracted from loaded subscriptions.
  List<String> get _passTypes {
    final seen = <String>{};
    final types = <String>[];
    for (final sub in _subscriptions) {
      final pass = sub['gym_passes'] as Map<String, dynamic>?;
      final name = pass?['name'] as String?;
      if (name != null && seen.add(name)) types.add(name);
    }
    types.sort();
    return types;
  }

  List<Map<String, dynamic>> get _filteredSubs {
    var list = _subscriptions.where((sub) {
      final profile = sub['profiles'] ?? {};
      final name = (profile['full_name'] as String? ?? '').toLowerCase();
      final phone = (profile['phone'] as String? ?? '').toLowerCase();
      final memberNo = _membershipNo(sub['user_id'] as String).toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          memberNo.contains(_searchQuery);
      if (!matchesSearch) return false;

      // Membership type filter
      if (_selectedPassType != null) {
        final pass = sub['gym_passes'] as Map<String, dynamic>?;
        final passName = pass?['name'] as String?;
        if (passName != _selectedPassType) return false;
      }
      return true;
    }).toList();

    // Sort alphabetically by member name (A → Z)
    list.sort((a, b) {
      final nameA = ((a['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ?? '').toLowerCase();
      final nameB = ((b['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ?? '').toLowerCase();
      return nameA.compareTo(nameB);
    });

    return list;
  }

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  Future<void> _fetchSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final subRes = await supabase
          .from('subscriptions')
          .select('''
            id, start_date, end_date, status, user_id, discount_amount, pass_id,
            profiles:user_id ( full_name, phone, photo_url, time_slot ),
            gym_passes:pass_id ( name, duration_days, price )
          ''')
          .order('end_date', ascending: true);
      await _applyResults(subRes);
    } catch (_) {
      // photo_url / time_slot columns may not exist yet — fall back to basic query
      try {
        final subRes = await supabase
            .from('subscriptions')
            .select('''
              id, start_date, end_date, status, user_id, discount_amount, pass_id,
              profiles:user_id ( full_name, phone ),
              gym_passes:pass_id ( name, duration_days, price )
            ''')
            .order('end_date', ascending: true);
        await _applyResults(subRes);
      } catch (e2) {
        debugPrint('Error fetching subscriptions: $e2');
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyResults(List subRes) async {
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
  }

  Future<void> _fetchMemberEmail(String userId, String? phone) async {
    if (_memberEmails.containsKey(userId)) return; // already cached
    if (phone == null || phone.isEmpty) {
      setState(() => _memberEmails[userId] = null);
      return;
    }
    try {
      final email = await supabase.rpc(
        'get_email_by_phone',
        params: {'phone_input': phone.replaceAll(RegExp(r'[^0-9]'), '')},
      ) as String?;
      if (mounted) setState(() => _memberEmails[userId] = email);
    } catch (_) {
      if (mounted) setState(() => _memberEmails[userId] = null);
    }
  }

  Future<void> _resetMemberPassword(String userId, String memberName) async {
    setState(() => _resettingPassword.add(userId));
    try {
      final res = await supabase.functions.invoke(
        'reset-member-password',
        body: {'user_id': userId},
      );
      final data = res.data as Map<String, dynamic>?;
      if (!mounted) return;
      if (data?['success'] == true) {
        final newPass = data!['temp_password'] as String;
        _showNewCredentialsDialog(memberName,
            _memberEmails[userId] ?? '—', newPass);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data?['error'] as String? ??
                'Reset failed. Deploy the reset-member-password Edge Function first.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Reset failed. Make sure the reset-member-password Edge Function is deployed.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _resettingPassword.remove(userId));
    }
  }

  void _showNewCredentialsDialog(String name, String email, String password) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share these with $name:',
                style: AppStyles.bodyFont
                    .copyWith(color: ctx.mutedFg, fontSize: context.sp(13))),
            const SizedBox(height: 16),
            _credTile(ctx, 'LOGIN EMAIL', email),
            const SizedBox(height: 10),
            _credTile(ctx, 'NEW PASSWORD', password),
            const SizedBox(height: 16),
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
                  const Icon(Icons.info_outline,
                      color: AppColors.sun, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Member must change this password on first login.',
                      style: AppStyles.bodyFont.copyWith(
                          color: AppColors.sun,
                          fontSize: context.sp(11),
                          height: 1.4),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _credTile(BuildContext context, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.w(12), vertical: context.h(10)),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(context.r(10)),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppStyles.eyebrow.copyWith(
                        color: context.mutedFg, fontSize: context.sp(9))),
                const SizedBox(height: 3),
                Text(value,
                    style: AppStyles.bodyFont.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: context.sp(13),
                        color: context.fg)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Icon(Icons.copy_outlined,
                size: context.r(16), color: context.mutedFg),
          ),
        ],
      ),
    );
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
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
                final val = double.tryParse(controller.text.trim());
                String? discountError;
                if (val == null || val < 0) {
                  discountError = 'Please enter a valid discount value.';
                } else if (isPercent && val > 100) {
                  discountError = 'Discount percentage cannot exceed 100%.';
                } else if (!isPercent && val > passPrice) {
                  discountError = 'Discount (₹${val.toStringAsFixed(0)}) cannot exceed the pass price (₹${passPrice.toStringAsFixed(0)}).';
                }
                if (discountError != null) {
                  showDialog(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      backgroundColor: c.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(c.r(16))),
                      title: Row(children: [
                        Icon(Icons.error_outline, color: Colors.redAccent, size: c.r(22)),
                        SizedBox(width: c.w(8)),
                        Text('Invalid Discount',
                            style: AppStyles.displayFont.copyWith(
                                fontSize: c.sp(16), fontWeight: FontWeight.bold, color: c.fg)),
                      ]),
                      content: Text(discountError!,
                          style: AppStyles.bodyFont.copyWith(fontSize: c.sp(13), color: c.fg)),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(c),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
                          child: const Text('OK', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                final discountAmt = isPercent ? (passPrice * val! / 100) : val!;
                _setDiscount(subscriptionId, discountAmt);
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.w(AppStyles.containerPadding),
                    context.h(12),
                    context.w(AppStyles.containerPadding),
                    context.h(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppStyles.bodyFont.copyWith(
                        fontSize: context.sp(14), color: context.fg),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone or MBR...',
                      hintStyle: AppStyles.bodyFont.copyWith(
                          color: context.mutedFg, fontSize: context.sp(13)),
                      prefixIcon:
                          Icon(Icons.search, color: context.mutedFg, size: context.r(18)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: context.mutedFg, size: context.r(18)),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: context.card,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: context.w(16), vertical: context.h(12)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.r(12)),
                          borderSide: BorderSide(color: context.border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.r(12)),
                          borderSide:
                              BorderSide(color: context.border.withValues(alpha: 0.6))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(context.r(12)),
                          borderSide:
                              const BorderSide(color: AppColors.brand, width: 1.5)),
                    ),
                  ),
                ),
                // ── Membership type filter chips ──────────────────────────
                if (_passTypes.isNotEmpty)
                  SizedBox(
                    height: context.h(42),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                          horizontal: context.w(AppStyles.containerPadding),
                          vertical: context.h(4)),
                      children: [
                        // "All" chip
                        _filterChip(
                          context,
                          label: 'All',
                          count: _subscriptions.length,
                          isSelected: _selectedPassType == null,
                          onTap: () => setState(() => _selectedPassType = null),
                        ),
                        ..._passTypes.map((type) {
                          final count = _subscriptions.where((s) {
                            final p = s['gym_passes'] as Map<String, dynamic>?;
                            return p?['name'] == type;
                          }).length;
                          return _filterChip(
                            context,
                            label: type,
                            count: count,
                            isSelected: _selectedPassType == type,
                            onTap: () => setState(() =>
                                _selectedPassType =
                                    _selectedPassType == type ? null : type),
                          );
                        }),
                      ],
                    ),
                  ),
                Expanded(
                  child: _filteredSubs.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty && _selectedPassType == null
                                ? 'No subscriptions found.'
                                : 'No results for "${_selectedPassType ?? _searchQuery}".',
                            style:
                                AppStyles.bodyFont.copyWith(color: context.mutedFg),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            context.w(AppStyles.containerPadding),
                            context.h(4),
                            context.w(AppStyles.containerPadding),
                            context.h(120),
                          ),
                          itemCount: _filteredSubs.length,
                          itemBuilder: (context, index) {
                            final sub = _filteredSubs[index];
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
                    final photoUrl = profile['photo_url'] as String?;
                    final timeSlot = profile['time_slot'] as String?;
                    final passId = sub['pass_id'] as String?;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedIds.remove(id);
                          } else {
                            _expandedIds.add(id);
                            // Fetch email when expanding for the first time
                            final phone = profile['phone'] as String?;
                            _fetchMemberEmail(sub['user_id'] as String, phone);
                          }
                        });
                      },
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
                              child: Column(
                                children: [
                                  // Row 1: Avatar + Name/Phone + Status/Chevron
                                  Row(
                                    children: [
                                      // Avatar (photo or initials)
                                      Container(
                                        width: context.r(38),
                                        height: context.r(38),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: (isExpired ? AppColors.energy : AppColors.brand)
                                              .withValues(alpha: 0.12),
                                          image: photoUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(photoUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: photoUrl == null
                                            ? Center(
                                                child: Text(
                                                  _initials(name),
                                                  style: AppStyles.displayFont.copyWith(
                                                    fontSize: context.sp(13),
                                                    fontWeight: FontWeight.bold,
                                                    color: isExpired ? AppColors.energy : AppColors.brand,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      SizedBox(width: context.w(10)),
                                      // Name + MBR + phone
                                      Expanded(
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
                                            // Pass type pill
                                            if ((pass['name'] as String?) != null) ...[
                                              SizedBox(height: context.h(4)),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: context.w(6),
                                                  vertical: context.h(2),
                                                ),
                                                decoration: BoxDecoration(
                                                  color: (isExpired
                                                          ? AppColors.energy
                                                          : AppColors.aqua)
                                                      .withValues(alpha: 0.10),
                                                  borderRadius: BorderRadius.circular(context.r(5)),
                                                  border: Border.all(
                                                    color: (isExpired
                                                            ? AppColors.energy
                                                            : AppColors.aqua)
                                                        .withValues(alpha: 0.25),
                                                  ),
                                                ),
                                                child: Text(
                                                  pass['name'] as String,
                                                  style: AppStyles.eyebrow.copyWith(
                                                    fontSize: context.sp(8),
                                                    fontWeight: FontWeight.w800,
                                                    color: isExpired
                                                        ? AppColors.energy
                                                        : AppColors.aqua,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
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
                                  SizedBox(height: context.h(8)),
                                  // Row 2: Full-width financial strip (4 cols)
                                  Container(
                                    padding: EdgeInsets.symmetric(vertical: context.h(6)),
                                    decoration: BoxDecoration(
                                      color: context.bg,
                                      borderRadius: BorderRadius.circular(context.r(8)),
                                    ),
                                    child: Row(
                                      children: [
                                        _miniStat(context, 'TOTAL', '₹${effectivePrice.toStringAsFixed(0)}', context.fg),
                                        _vertDivider(context),
                                        _miniStat(context, 'DISC',
                                            discountAmount > 0 ? '₹${discountAmount.toStringAsFixed(0)}' : '—',
                                            discountAmount > 0 ? AppColors.sun : context.mutedFg),
                                        _vertDivider(context),
                                        _miniStat(context, 'PAID', '₹${paid.toStringAsFixed(0)}', AppColors.brand),
                                        _vertDivider(context),
                                        _miniStat(context, 'BAL', '₹${balance.toStringAsFixed(0)}',
                                            balance > 0 ? AppColors.energy : AppColors.brand),
                                      ],
                                    ),
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
                                              if (timeSlot != null) ...[
                                                SizedBox(height: context.h(12)),
                                                Row(
                                                  children: [
                                                    _detailCell(
                                                      context,
                                                      'TIME SLOT',
                                                      timeSlot,
                                                      AppColors.brand,
                                                    ),
                                                  ],
                                                ),
                                              ],
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
                                              SizedBox(height: context.h(14)),
                                              // ── Login Credentials ──────
                                              Container(
                                                padding: EdgeInsets.all(context.r(12)),
                                                decoration: BoxDecoration(
                                                  color: AppColors.brand.withValues(alpha: 0.04),
                                                  borderRadius: BorderRadius.circular(context.r(12)),
                                                  border: Border.all(
                                                      color: AppColors.brand.withValues(alpha: 0.2)),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(Icons.key_outlined,
                                                            size: context.r(13),
                                                            color: AppColors.brand),
                                                        SizedBox(width: context.w(6)),
                                                        Text('LOGIN CREDENTIALS',
                                                            style: AppStyles.eyebrow.copyWith(
                                                                color: AppColors.brand,
                                                                fontSize: context.sp(9),
                                                                fontWeight: FontWeight.w800)),
                                                      ],
                                                    ),
                                                    SizedBox(height: context.h(10)),
                                                    // Email row
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                            children: [
                                                              Text('EMAIL',
                                                                  style: AppStyles.eyebrow.copyWith(
                                                                      color: context.mutedFg,
                                                                      fontSize: context.sp(8))),
                                                              SizedBox(height: context.h(2)),
                                                              _memberEmails
                                                                      .containsKey(
                                                                          sub['user_id'])
                                                                  ? Text(
                                                                      _memberEmails[
                                                                              sub['user_id']] ??
                                                                          'Not found',
                                                                      style:
                                                                          AppStyles.bodyFont.copyWith(
                                                                        fontSize: context.sp(12),
                                                                        fontWeight: FontWeight.w600,
                                                                        color: context.fg,
                                                                      ),
                                                                    )
                                                                  : Row(
                                                                      children: [
                                                                        SizedBox(
                                                                          width: context.r(12),
                                                                          height: context.r(12),
                                                                          child:
                                                                              CircularProgressIndicator(
                                                                                  strokeWidth: 1.5,
                                                                                  color: AppColors
                                                                                      .brand),
                                                                        ),
                                                                        SizedBox(
                                                                            width: context.w(6)),
                                                                        Text('Loading…',
                                                                            style: AppStyles.bodyFont
                                                                                .copyWith(
                                                                                    color: context
                                                                                        .mutedFg,
                                                                                    fontSize:
                                                                                        context
                                                                                            .sp(12))),
                                                                      ],
                                                                    ),
                                                            ],
                                                          ),
                                                        ),
                                                        if (_memberEmails[sub['user_id']] != null)
                                                          GestureDetector(
                                                            onTap: () {
                                                              Clipboard.setData(ClipboardData(
                                                                  text: _memberEmails[
                                                                          sub['user_id']]!));
                                                              ScaffoldMessenger.of(context)
                                                                  .showSnackBar(const SnackBar(
                                                                content:
                                                                    Text('Email copied'),
                                                                duration: Duration(seconds: 1),
                                                                behavior:
                                                                    SnackBarBehavior.floating,
                                                              ));
                                                            },
                                                            child: Container(
                                                              padding: EdgeInsets.all(
                                                                  context.r(6)),
                                                              decoration: BoxDecoration(
                                                                color: context.card,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                        context.r(6)),
                                                                border: Border.all(
                                                                    color: context.border),
                                                              ),
                                                              child: Icon(
                                                                  Icons.copy_outlined,
                                                                  size: context.r(14),
                                                                  color: context.mutedFg),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    SizedBox(height: context.h(10)),
                                                    // Reset password button
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: OutlinedButton.icon(
                                                        onPressed: _resettingPassword
                                                                .contains(sub['user_id'])
                                                            ? null
                                                            : () => _resetMemberPassword(
                                                                sub['user_id'] as String,
                                                                name),
                                                        icon: _resettingPassword
                                                                .contains(sub['user_id'])
                                                            ? SizedBox(
                                                                width: context.r(13),
                                                                height: context.r(13),
                                                                child:
                                                                    CircularProgressIndicator(
                                                                        strokeWidth: 1.5,
                                                                        color: AppColors.energy),
                                                              )
                                                            : Icon(Icons.lock_reset_outlined,
                                                                size: context.r(14)),
                                                        label: Text(
                                                          _resettingPassword
                                                                  .contains(sub['user_id'])
                                                              ? 'Resetting…'
                                                              : 'Reset Password',
                                                          style: TextStyle(
                                                              fontSize: context.sp(12)),
                                                        ),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: AppColors.energy,
                                                          side: BorderSide(
                                                              color: AppColors.energy
                                                                  .withValues(alpha: 0.5)),
                                                          padding: EdgeInsets.symmetric(
                                                              vertical: context.h(8)),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                      context.r(8))),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: context.h(10)),
                                              // Actions: Edit Member + Change Status
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  OutlinedButton.icon(
                                                    onPressed: () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => AdminEditMemberScreen(
                                                          userId: sub['user_id'] as String,
                                                          subscriptionId: id,
                                                          initialPassId: passId,
                                                          initialStartDate: startDate,
                                                          onSaved: _fetchSubscriptions,
                                                        ),
                                                      ),
                                                    ),
                                                    icon: Icon(Icons.edit_outlined, size: context.r(14)),
                                                    label: Text('Edit Member',
                                                        style: TextStyle(fontSize: context.sp(12))),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: context.fg,
                                                      side: BorderSide(color: context.border),
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: context.w(10),
                                                        vertical: context.h(7),
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(context.r(8)),
                                                      ),
                                                    ),
                                                  ),
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
                  ),
                ],
              ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(right: context.w(8)),
        padding: EdgeInsets.symmetric(
            horizontal: context.w(12), vertical: context.h(5)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand
              : context.card,
          borderRadius: BorderRadius.circular(context.r(20)),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : context.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppStyles.bodyFont.copyWith(
                fontSize: context.sp(11),
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.black : context.fg,
              ),
            ),
            SizedBox(width: context.w(5)),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: context.w(5), vertical: context.h(1)),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black.withValues(alpha: 0.15)
                    : AppColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.r(10)),
              ),
              child: Text(
                '$count',
                style: AppStyles.numTabular.copyWith(
                  fontSize: context.sp(9),
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.black : AppColors.brand,
                ),
              ),
            ),
          ],
        ),
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
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.r(16))),
          title: Row(children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: ctx.r(22)),
            SizedBox(width: ctx.w(8)),
            Text('Invalid Amount',
                style: AppStyles.displayFont.copyWith(
                    fontSize: ctx.sp(16), fontWeight: FontWeight.bold, color: ctx.fg)),
          ]),
          content: Text('Please enter a payment amount greater than ₹0.',
              style: AppStyles.bodyFont.copyWith(fontSize: ctx.sp(13), color: ctx.fg)),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final pass = widget.subscription['gym_passes'] ?? {};
    final passPrice = (pass['price'] as num?)?.toDouble() ?? 0.0;
    final totalFee = (passPrice - widget.discountAmount).clamp(0.0, double.infinity);
    final alreadyPaid = _payments.fold(0.0, (sum, p) => sum + (p['amount'] as num).toDouble());
    final remainingBalance = totalFee - alreadyPaid;

    if (amount > remainingBalance) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ctx.r(16))),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.energy, size: ctx.r(22)),
              SizedBox(width: ctx.w(8)),
              Text('Amount Exceeds Balance',
                  style: AppStyles.displayFont.copyWith(fontSize: ctx.sp(16), fontWeight: FontWeight.bold, color: ctx.fg)),
            ],
          ),
          content: Text(
            'Payment of ₹${amount.toStringAsFixed(0)} exceeds the remaining balance of ₹${remainingBalance.toStringAsFixed(0)}. Please enter a valid amount.',
            style: AppStyles.bodyFont.copyWith(fontSize: ctx.sp(13), color: ctx.fg),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

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
      if (mounted) {
        setState(() => _isSaving = false);
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
                    'Payment Failed',
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
              'Could not record the payment. Please try again.',
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
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
