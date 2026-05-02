/// GEMINI: DO NOT change any hardcoded values in this file. 
/// Always use responsive utilities (context.w, context.h, context.sp, context.r) 
/// to ensure the app remains dynamic across all device sizes.
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

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('subscriptions')
          .select('''
            id,
            start_date,
            end_date,
            status,
            user_id,
            profiles:user_id ( full_name, phone ),
            gym_passes:pass_id ( name, duration_days )
          ''')
          .order('end_date', ascending: true);

      if (mounted) {
        setState(() {
          _subscriptions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching subscriptions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await supabase
          .from('subscriptions')
          .update({'status': newStatus})
          .eq('id', id);
      _fetchSubscriptions();
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

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
                  padding: EdgeInsets.fromLTRB(context.w(AppStyles.containerPadding), context.h(16), context.w(AppStyles.containerPadding), context.h(120)),
                  itemCount: _subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = _subscriptions[index];
                    final profile = sub['profiles'] ?? {};
                    final pass = sub['gym_passes'] ?? {};
                    
                    final endDate = DateTime.parse(sub['end_date']);
                    final startDate = DateTime.parse(sub['start_date']);
                    final daysLeft = endDate.difference(DateTime.now()).inDays;
                    final isExpired = daysLeft < 0 || sub['status'] == 'expired';

                    return Container(
                      margin: EdgeInsets.only(bottom: context.h(16)),
                      padding: EdgeInsets.all(context.r(16)),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(context.r(AppStyles.radiusMd)),
                        border: Border.all(
                          color: isExpired ? AppColors.energy.withOpacity(0.5) : context.border,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: context.r(10),
                            offset: Offset(0, context.h(4)),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  profile['full_name'] ?? 'Unknown Member',
                                  style: AppStyles.displayFont.copyWith(
                                    fontSize: context.sp(18),
                                    fontWeight: FontWeight.bold,
                                    color: context.fg,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: context.w(8), vertical: context.h(4)),
                                decoration: BoxDecoration(
                                  color: isExpired ? AppColors.energy.withOpacity(0.1) : AppColors.brand.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(context.r(8)),
                                ),
                                child: Text(
                                  sub['status'].toString().toUpperCase(),
                                  style: AppStyles.eyebrow.copyWith(
                                    color: isExpired ? AppColors.energy : AppColors.brand,
                                    fontSize: context.sp(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.h(4)),
                          Text(
                            profile['phone'] ?? 'No Phone',
                            style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: context.sp(14)),
                          ),
                          SizedBox(height: context.h(16)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PASS TYPE',
                                    style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(10)),
                                  ),
                                  Text(
                                    pass['name'] ?? 'Custom',
                                    style: AppStyles.bodyFont.copyWith(fontWeight: FontWeight.w600, color: context.fg),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'DAYS LEFT',
                                    style: AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: context.sp(10)),
                                  ),
                                  Text(
                                    isExpired ? 'Expired' : '$daysLeft days',
                                    style: AppStyles.bodyFont.copyWith(
                                      fontWeight: FontWeight.bold, 
                                      color: isExpired ? AppColors.energy : context.fg,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: context.h(12)),
                          const Divider(),
                          SizedBox(height: context.h(8)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Started: ${DateFormat('MMM d, yyyy').format(startDate)}',
                                    style: AppStyles.bodyFont.copyWith(fontSize: context.sp(12), color: context.mutedFg),
                                  ),
                                  Text(
                                    'Ends: ${DateFormat('MMM d, yyyy').format(endDate)}',
                                    style: AppStyles.bodyFont.copyWith(fontSize: context.sp(12), color: context.mutedFg),
                                  ),
                                ],
                              ),
                              PopupMenuButton<String>(
                                child: const Icon(Icons.more_vert),
                                onSelected: (val) => _updateStatus(sub['id'], val),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'active', child: Text('Mark Active')),
                                  const PopupMenuItem(value: 'suspended', child: Text('Suspend')),
                                  const PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
