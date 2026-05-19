import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_styles.dart';
import '../core/services/notification_service.dart';
import '../core/services/update_service.dart';
import '../core/utils/responsive_utils.dart';
import '../core/widgets/update_dialog.dart';
import '../main.dart';
import 'dashboard/dashboard_screen.dart';
import 'train/train_screen.dart';
import 'progress/progress_screen.dart';
import 'pass/pass_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  int _profileVersion = 0;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
    _registerNotifications();
  }

  Future<void> _registerNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await NotificationService.initialize(userId);
  }

  Future<void> _checkForUpdates() async {
    // Delay slightly to ensure context is ready if needed, 
    // though UpdateDialog.show uses showDialog which needs context.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final updateInfo = await updateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      UpdateDialog.show(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final isDark = context.isDark;
    final isWide = Responsive.isWide(context);
    return isWide
        ? _buildWideLayout(context, isDark)
        : _buildNarrowLayout(context, isDark);
  }

  List<Widget> _buildScreens() {
    return [
      DashboardScreen(key: ValueKey('dashboard_v$_profileVersion')),
      TrainScreen(key: ValueKey('tab_1_active_${_currentIndex == 1}')),
      ProgressScreen(key: ValueKey('tab_2_active_${_currentIndex == 2}')),
      PassScreen(key: ValueKey('tab_3_active_${_currentIndex == 3}')),
    ];
  }

  // Narrow layout (mobile): floating bottom nav bar
  Widget _buildNarrowLayout(BuildContext context, bool isDark) {
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
                    children: _buildScreens(),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 24,
              left: AppStyles.containerPadding,
              right: AppStyles.containerPadding,
              child: _buildFloatingNavBar(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // Wide layout (tablet/desktop): sidebar rail + centered content
  Widget _buildWideLayout(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Row(
          children: [
            _buildSideRail(isDark),
            Container(width: 1, color: context.border.withValues(alpha: 0.4)),
            Expanded(
              child: Column(
                children: [
                  _buildTopBranding(),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: Responsive.contentMaxWidth,
                        ),
                        child: IndexedStack(
                          index: _currentIndex,
                          children: _buildScreens(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideRail(bool isDark) {
    final railBg = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final inactiveColor = isDark ? Colors.black38 : Colors.white38;

    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: railBg,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildRailItem(0, Icons.home_outlined, Icons.home, 'Today',
              AppColors.gradientBrand, isDark, inactiveColor),
          _buildRailItem(1, Icons.fitness_center_outlined, Icons.fitness_center,
              'Train', AppColors.gradientEnergy, isDark, inactiveColor),
          _buildRailItem(
              2,
              Icons.bar_chart_outlined,
              Icons.bar_chart,
              'Progress',
              const LinearGradient(
                  colors: [Color(0xFF26B6E8), Color(0xFF9182F9)]),
              isDark,
              inactiveColor),
          _buildRailItem(
              3,
              Icons.qr_code_scanner_outlined,
              Icons.qr_code_scanner,
              'Pass',
              const LinearGradient(
                  colors: [Color(0xFFFFB03A), Color(0xFFFF4B8C)]),
              isDark,
              inactiveColor),
          const Spacer(),
          GestureDetector(
            onTap: () => _showSettingsDialog(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(Icons.settings_outlined,
                  size: 20, color: inactiveColor),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRailItem(
    int index,
    IconData outlineIcon,
    IconData solidIcon,
    String label,
    LinearGradient activeGradient,
    bool isDark,
    Color inactiveColor,
  ) {
    final isActive = _currentIndex == index;
    final activeIconColor = isDark ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isActive ? activeGradient : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? solidIcon : outlineIcon,
              size: 20,
              color: isActive ? activeIconColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppStyles.bodyFont.copyWith(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? activeIconColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle Logout with confirmation
  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: AppStyles.displayFont.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: AppStyles.bodyFont.copyWith(fontSize: 14),
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
                borderRadius: BorderRadius.circular(12),
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
          MaterialPageRoute(builder: (context) => AuthGate()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  Widget _buildTopBranding() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.containerPadding,
        vertical: 16,
      ),
      child: Row(
        children: [
          // Wrapped branding in Expanded to prevent pushing logout button off-screen
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          size: 24,
                          color: AppColors.brand,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'VISHAL FITNESS',
                      style: GoogleFonts.anton(
                        color: context.isDark ? Colors.white : Colors.black,
                        fontSize: 28,
                        letterSpacing: 2.0,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showSettingsDialog(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.border),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 18,
                color: context.mutedFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final user = supabase.auth.currentUser;
    final controller = TextEditingController();

    // Pre-populate with current name as soon as it loads
    supabase
        .from('profiles')
        .select('full_name')
        .eq('id', user!.id)
        .maybeSingle()
        .then((data) {
      final name = data?['full_name'] as String?;
      if (name != null && name.isNotEmpty) controller.text = name;
    });

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Profile',
          style: AppStyles.displayFont.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FULL NAME',
              style: AppStyles.eyebrow.copyWith(
                fontSize: 10,
                color: dialogContext.mutedFg,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: AppStyles.bodyFont.copyWith(color: dialogContext.fg),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: TextStyle(color: dialogContext.mutedFg),
                filled: true,
                fillColor: dialogContext.muted.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: TextStyle(color: dialogContext.mutedFg)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await supabase.from('profiles').upsert({
                  'id': user.id,
                  'full_name': controller.text.trim(),
                  'updated_at': DateTime.now().toIso8601String(),
                });
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                // Increment version to force DashboardScreen to rebuild
                if (mounted) {
                  setState(() => _profileVersion++);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated!')),
                  );
                }
              } catch (e) {
                debugPrint('Error updating profile: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: sheetCtx.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetCtx.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Settings & Account',
                style: AppStyles.displayFont.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildDialogItem(sheetCtx, Icons.person_outline, 'Edit Profile',
                  () {
                Navigator.pop(sheetCtx);
                _showEditProfileDialog(context);
              }),
              _buildDialogItem(
                sheetCtx,
                Icons.privacy_tip_outlined,
                'Privacy Policy',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
              ),
              _buildDialogItem(
                sheetCtx,
                Icons.description_outlined,
                'Terms of Service',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen(),
                  ),
                ),
              ),
              const Divider(height: 24),
              _buildDialogItem(
                sheetCtx,
                Icons.delete_forever_outlined,
                'Delete Account',
                () {
                  Navigator.pop(sheetCtx);
                  _confirmAccountDeletion(context);
                },
                isDestructive: true,
              ),
              _buildDialogItem(
                sheetCtx,
                Icons.exit_to_app_outlined,
                'Sign Out',
                () {
                  Navigator.pop(sheetCtx);
                  _handleLogout();
                },
                isDestructive: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : context.fg,
        size: 20,
      ),
      title: Text(
        label,
        style: AppStyles.bodyFont.copyWith(
          color: isDestructive ? Colors.redAccent : context.fg,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _confirmAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account?',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This action is permanent and will delete all your workout data and profile information. This cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: context.mutedFg)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Call the custom RPC function to delete the user
                // Make sure you have run the setup_delete_user.sql in Supabase SQL editor!
                await supabase.rpc('delete_user_account');
                
                // Sign out just to be sure local state is cleared
                await supabase.auth.signOut();
                
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthGate()),
                    (Route<dynamic> route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close the dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting account: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                debugPrint('Error deleting account: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(bool isDark) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        // INVERTED: White bar in Dark theme, Dark bar in Light theme
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: isDark
              ? Colors.black.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        // Use mainAxisSize max and Expanded children for perfect responsive distribution
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildNavItem(
              0,
              Icons.home_outlined,
              Icons.home,
              'Today',
              AppColors.gradientBrand,
              isDark,
            ),
          ),
          Expanded(
            child: _buildNavItem(
              1,
              Icons.fitness_center_outlined,
              Icons.fitness_center,
              'Train',
              AppColors.gradientEnergy,
              isDark,
            ),
          ),
          Expanded(
            child: _buildNavItem(
              2,
              Icons.bar_chart_outlined,
              Icons.bar_chart,
              'Progress',
              const LinearGradient(
                colors: [Color(0xFF26B6E8), Color(0xFF9182F9)],
              ),
              isDark,
            ),
          ),
          Expanded(
            child: _buildNavItem(
              3,
              Icons.qr_code_scanner_outlined,
              Icons.qr_code_scanner,
              'Pass',
              const LinearGradient(
                colors: [Color(0xFFFFB03A), Color(0xFFFF4B8C)],
              ),
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData outlineIcon,
    IconData solidIcon,
    String label,
    LinearGradient activeGradient,
    bool isDark,
  ) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          // Removed fixed vertical padding to allow MainAxisAlignment.center to work freely
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 56, // Fixed internal height for the active pill
          decoration: BoxDecoration(
            gradient: isActive ? activeGradient : null,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: FittedBox(
              // SAFETY: Automatically scales down if it doesn't fit
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive ? solidIcon : outlineIcon,
                    color: isActive
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.black45 : Colors.white54),
                    size:
                        20, // Slightly reduced icon size for better vertical fit
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: AppStyles.bodyFont.copyWith(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                      color: isActive
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.black45 : Colors.white54),
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
