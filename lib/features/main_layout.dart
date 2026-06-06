import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_styles.dart';
import '../core/services/notification_service.dart';
import '../core/services/update_service.dart';
import '../core/services/version_tracking_service.dart';
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
    _checkVersionUpdate();
  }

  Future<void> _registerNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await NotificationService.initialize(userId);
  }

  Future<void> _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final updateInfo = await updateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      UpdateDialog.show(context, updateInfo);
    }
  }

  Future<void> _checkVersionUpdate() async {
    final wasUpdated = await versionTrackingService.checkAndShowUpdateSuccess();
    if (wasUpdated && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('App updated successfully! Enjoy the new features.'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
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
                      style: TextStyle(
                        fontFamily: 'Anton',
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditProfileSheet(
        onSaved: () {
          if (mounted) setState(() => _profileVersion++);
        },
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 56,
          decoration: BoxDecoration(
            gradient: isActive ? activeGradient : null,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Center(
            child: FittedBox(
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
                    size: 20,
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

// ── Edit Profile Bottom Sheet ────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _EditProfileSheet({required this.onSaved});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  String? _currentEmail;
  String? _avatarUrl;
  Uint8List? _pendingImageBytes;
  bool _isSaving = false;
  bool _otpStep = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (mounted) setState(() {});
    });
    // Populate email immediately from auth — no DB call needed
    final user = supabase.auth.currentUser;
    _currentEmail = user?.email ?? '';
    _emailController.text = user?.email ?? '';
    // Load name/phone/avatar asynchronously
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await supabase
          .from('profiles')
          .select('full_name, phone, photo_url')
          .eq('id', user.id)
          .maybeSingle();
      if (mounted) {
        setState(() {
          final name = data?['full_name'] as String?;
          final phone = data?['phone'] as String?;
          if (name != null && name.isNotEmpty) _nameController.text = name;
          if (phone != null && phone.isNotEmpty) _phoneController.text = phone;
          _avatarUrl = data?['photo_url'] as String?;
        });
      }
    } catch (_) {
      // Fallback: try with just full_name if extra columns don't exist
      try {
        final data = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) {
          final name = data?['full_name'] as String?;
          if (name != null && name.isNotEmpty) {
            setState(() => _nameController.text = name);
          }
        }
      } catch (e) {
        debugPrint('Profile load error: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ctx.card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.brand),
              title: Text('Take Photo',
                  style: AppStyles.bodyFont.copyWith(color: ctx.fg)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.aqua),
              title: Text('Choose from Library',
                  style: AppStyles.bodyFont.copyWith(color: ctx.fg)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (mounted) setState(() => _pendingImageBytes = bytes);
  }

  Future<String?> _uploadAvatar() async {
    if (_pendingImageBytes == null) return _avatarUrl;
    final user = supabase.auth.currentUser!;
    // Use same bucket + column as AdminEditMemberScreen so photo shows in admin portal
    final path = '${user.id}/avatar.jpg';
    try {
      await supabase.storage.from('member-photos').uploadBinary(
        path,
        _pendingImageBytes!,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return supabase.storage.from('member-photos').getPublicUrl(path);
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
      return _avatarUrl;
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Name cannot be empty.');
      return;
    }
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty &&
        phone.replaceAll(RegExp(r'[^0-9]'), '').length != 10) {
      _showError('Mobile number must be exactly 10 digits.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = supabase.auth.currentUser!;
      final avatarUrl = await _uploadAvatar();

      // Attempt 1: full upsert with all available fields
      bool saved = false;
      try {
        final payload = <String, dynamic>{
          'id': user.id,
          'full_name': name,
        };
        if (phone.isNotEmpty) payload['phone'] = phone;
        if (avatarUrl != null) payload['photo_url'] = avatarUrl;
        await supabase.from('profiles').upsert(payload);
        saved = true;
      } catch (e) {
        debugPrint('Full upsert failed, trying name-only fallback: $e');
      }

      // Attempt 2: name-only fallback (in case phone/avatar columns are absent)
      if (!saved) {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': name,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated!'),
            backgroundColor: AppColors.brand,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      _showError('Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendEmailOtp() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty) {
      _showError('Please enter a valid email address.');
      return;
    }
    if (newEmail == _currentEmail) {
      _showError('This is already your current email.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await supabase.auth.updateUser(UserAttributes(email: newEmail));
      if (mounted) setState(() => _otpStep = true);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Could not send verification code. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _verifyEmailOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _showError('Enter the 6-digit code sent to your new email.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await supabase.auth.verifyOTP(
        email: _emailController.text.trim(),
        token: otp,
        type: OtpType.emailChange,
      );
      if (mounted) {
        setState(() {
          _currentEmail = _emailController.text.trim();
          _otpStep = false;
          _otpController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email updated successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Invalid or expired code.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.energy),
            const SizedBox(width: 8),
            Text('Notice',
                style: AppStyles.displayFont
                    .copyWith(fontSize: 18, color: ctx.fg)),
          ],
        ),
        content: Text(msg,
            style: AppStyles.bodyFont.copyWith(color: ctx.fg, fontSize: 14)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: _otpStep ? _buildOtpStep() : _buildMainForm(),
    );
  }

  Widget _buildMainForm() {
    final emailChanged =
        _emailController.text.trim() != (_currentEmail ?? '');
    final initials = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : '?';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Edit Profile',
            style: AppStyles.displayFont.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.fg,
            ),
          ),
          const SizedBox(height: 24),

          // Avatar
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                    backgroundImage: _pendingImageBytes != null
                        ? MemoryImage(_pendingImageBytes!) as ImageProvider
                        : (_avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null),
                    child: (_pendingImageBytes == null && _avatarUrl == null)
                        ? Text(
                            initials,
                            style: AppStyles.displayFont.copyWith(
                              fontSize: 32,
                              color: AppColors.brand,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.card, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Name
          _label('FULL NAME'),
          const SizedBox(height: 6),
          _field(
            controller: _nameController,
            hint: 'Your full name',
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 16),

          // Phone
          _label('MOBILE NUMBER'),
          const SizedBox(height: 6),
          _field(
            controller: _phoneController,
            hint: '10-digit mobile number',
            keyboardType: TextInputType.phone,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: 16),

          // Email
          _label('EMAIL ADDRESS'),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  controller: _emailController,
                  hint: 'your@email.com',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving || !emailChanged ? null : _sendEmailOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: emailChanged
                        ? AppColors.brand.withValues(alpha: 0.12)
                        : context.muted.withValues(alpha: 0.2),
                    foregroundColor: AppColors.brand,
                    elevation: 0,
                    disabledBackgroundColor:
                        context.muted.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.brand),
                        )
                      : Text(
                          'Verify',
                          style: AppStyles.bodyFont.copyWith(
                            fontWeight: FontWeight.w700,
                            color: emailChanged
                                ? AppColors.brand
                                : context.mutedFg,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (emailChanged)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 11, color: AppColors.energy),
                  const SizedBox(width: 4),
                  Text(
                    'Tap "Verify" to confirm new email via OTP.',
                    style: AppStyles.eyebrow
                        .copyWith(color: AppColors.energy, fontSize: 9),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      'Save Changes',
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: context.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_read,
                  color: AppColors.brand, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify New Email',
                    style: AppStyles.displayFont.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.fg),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Code sent to ${_emailController.text.trim()}',
                    style: AppStyles.bodyFont
                        .copyWith(fontSize: 12, color: context.mutedFg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _label('6-DIGIT VERIFICATION CODE'),
        const SizedBox(height: 6),
        _field(
          controller: _otpController,
          hint: '000000',
          keyboardType: TextInputType.number,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _verifyEmailOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    'Confirm Email Change',
                    style: AppStyles.bodyFont.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _isSaving ? null : _sendEmailOtp,
              child: Text(
                'Resend code',
                style: AppStyles.bodyFont.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Text('·', style: TextStyle(color: context.mutedFg)),
            TextButton(
              onPressed: () => setState(() {
                _otpStep = false;
                _otpController.clear();
                _emailController.text = _currentEmail ?? '';
              }),
              child: Text(
                'Cancel',
                style: AppStyles.bodyFont.copyWith(
                  color: context.mutedFg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Text(
          text,
          style:
              AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: 10),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        style: AppStyles.bodyFont.copyWith(color: context.fg, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: 14),
          filled: true,
          fillColor: context.muted.withValues(alpha: 0.3),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.brand),
          ),
        ),
      ),
    );
  }
}
