/// GEMINI: DO NOT change any hardcoded values in this file. 
/// Always use responsive utilities (context.w, context.h, context.sp, context.r) 
/// to ensure the app remains dynamic across all device sizes.
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/utils/responsive_utils.dart';
import '../../main.dart'; // Contains supabase client and AuthGate
import 'admin_dashboard_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_classes_screen.dart';
import 'admin_passes_screen.dart';
import 'admin_announcements_screen.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBranding(),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      AdminDashboardScreen(
                        key: ValueKey('admin_tab_0_active_${_currentIndex == 0}'),
                      ),
                      AdminSubscriptionsScreen(
                        key: ValueKey('admin_tab_1_active_${_currentIndex == 1}'),
                      ),
                      AdminClassesScreen(
                        key: ValueKey('admin_tab_2_active_${_currentIndex == 2}'),
                      ),
                      AdminPassesScreen(
                        key: ValueKey('admin_tab_3_active_${_currentIndex == 3}'),
                      ),
                      AdminAnnouncementsScreen(
                        key: ValueKey('admin_tab_4_active_${_currentIndex == 4}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // The Persistent Floating Nav Bar
            Positioned(
              bottom: context.h(24),
              left: context.w(AppStyles.containerPadding),
              right: context.w(AppStyles.containerPadding),
              child: _buildFloatingNavBar(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBranding() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.w(AppStyles.containerPadding), vertical: context.h(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: context.r(32),
                height: context.r(32),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brand,
                ),
                child: Icon(Icons.shield, color: Colors.white, size: context.r(16)),
              ),
              SizedBox(width: context.w(12)),
              Text(
                'ADMIN PORTAL',
                style: AppStyles.displayFont.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: context.sp(20),
                  letterSpacing: -0.5,
                  color: context.fg,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              padding: EdgeInsets.all(context.r(8)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.border),
              ),
              child: Icon(Icons.logout, color: AppColors.energy, size: context.r(18)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(bool isDark) {
    return Container(
      height: context.h(72),
      decoration: BoxDecoration(
        color: context.card.withOpacity(0.95),
        borderRadius: BorderRadius.circular(context.r(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: context.r(20),
            offset: Offset(0, context.h(10)),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.bar_chart, 'Stats'),
          _buildNavItem(1, Icons.people, 'Subs'),
          _buildNavItem(2, Icons.event, 'Classes'),
          _buildNavItem(3, Icons.local_activity, 'Passes'),
          _buildNavItem(4, Icons.campaign, 'Alerts'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    final color = isActive ? AppColors.brand : context.mutedFg;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(horizontal: context.w(12), vertical: context.h(8)),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(context.r(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: context.r(24)),
            if (isActive) ...[
              SizedBox(height: context.h(2)),
              Text(
                label,
                style: TextStyle(color: color, fontSize: context.sp(10), fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.r(20))),
        title: Text(
          'Sign Out',
          style: AppStyles.displayFont.copyWith(
            fontSize: context.sp(20),
            fontWeight: FontWeight.bold,
            color: context.fg,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of the Admin Portal?',
          style: AppStyles.bodyFont.copyWith(fontSize: context.sp(14), color: context.fg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: context.mutedFg)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.energy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.r(12)),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.auth.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }
}