import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../main.dart';

class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _subscription;
  List<Map<String, dynamic>> _checks = [];
  bool _isLoading = true;
  bool _isCheckingIn = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final results = await Future.wait([
        supabase
            .from('profiles')
            .select('full_name, created_at')
            .eq('id', user.id)
            .maybeSingle(),
        supabase
            .from('check_ins')
            .select('id, checked_in_at')
            .eq('user_id', user.id)
            .order('checked_in_at', ascending: false)
            .limit(8),
        supabase
            .from('subscriptions')
            .select('status, end_date, gym_passes(name)')
            .eq('user_id', user.id)
            .order('end_date', ascending: false)
            .limit(1)
            .maybeSingle(),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _checks = List<Map<String, dynamic>>.from(results[1] as List);
          _subscription = results[2] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching pass data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckIn() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isCheckingIn = true);
    HapticFeedback.mediumImpact();

    try {
      await supabase.from('check_ins').insert({'user_id': user.id});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Checked in. Have a great session.'),
            backgroundColor: AppColors.brand,
          ),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check in: $e'),
            backgroundColor: AppColors.energy,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.containerPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Header
          const ShimmerBox(width: 100, height: 12, radius: 6),
          const SizedBox(height: 10),
          const ShimmerBox(width: 160, height: 28, radius: 8),
          const SizedBox(height: 24),
          // Pass card (dark)
          const ShimmerBoxDark(height: 420, radius: 24),
          const SizedBox(height: 24),
          // Check-in button
          const ShimmerBox(height: 52, radius: 16),
          const SizedBox(height: 32),
          // Recent visits label
          const ShimmerBox(width: 120, height: 12, radius: 6),
          const SizedBox(height: 16),
          // Visit rows
          for (int i = 0; i < 5; i++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBox(width: 160, height: 16, radius: 6),
                ShimmerBox(width: 48, height: 16, radius: 6),
              ],
            ),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final memberId = user?.id.substring(0, 8).toUpperCase() ?? "—";

    final qrPayload = jsonEncode({
      'uid': user?.id,
      'email': user?.email,
      'name': _profile?['full_name'] ?? 'Member',
      'joined': _profile?['created_at'] ?? '',
      'status': 'ACTIVE',
      'plan': 'Premium Pass',
      't': DateTime.now().millisecondsSinceEpoch,
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppStyles.containerPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildDigitalPassCard(memberId, qrPayload)
                        .animate(
                          key: ValueKey('pass_anim_${DateTime.now().second}'),
                        )
                        .scale(
                          duration: 600.ms,
                          curve: Curves.easeOutBack,
                          begin: const Offset(0.9, 0.9),
                        )
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 24),
                    _buildManualCheckInBtn(),
                    const SizedBox(height: 32),
                    _buildRecentVisits(),
                    const SizedBox(height: 48),
                    _buildFooter(context),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () async {
          final Uri url = Uri.parse('https://qyroxis.com');
          if (!await launchUrl(url)) {
            debugPrint('Could not launch $url');
          }
        },
        child: RichText(
          text: TextSpan(
            style: AppStyles.eyebrow.copyWith(
              color: context.fg.withOpacity(0.5),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
            children: [
              const TextSpan(text: 'APP MADE BY '),
              const TextSpan(
                text: 'QYROXIS',
                style: TextStyle(
                  color: AppColors.brand,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 14,
              color: AppColors.sun,
            ), // Sparkles icon
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'MEMBERSHIP',
                  style: AppStyles.eyebrow.copyWith(
                    color: context.mutedFg,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Your pass',
              style: Theme.of(
                context,
              ).textTheme.displayLarge?.copyWith(fontSize: 28, height: 1.1),
            ),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) =>
                  AppColors.gradientSunrise.createShader(bounds),
              child: Text(
                '.',
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontSize: 28, height: 1.1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDigitalPassCard(String memberId, String qrPayload) {
    final endDate = _subscription?['end_date'] as String?;
    final formattedExpiry = endDate != null
        ? DateFormat("d MMM yy").format(DateTime.parse(endDate))
        : "—";

    String displayName = _profile?['full_name'] ?? "—";
    if (displayName.contains(' ')) {
      displayName = displayName.split(' ')[0];
    }

    final passName =
        (_subscription?['gym_passes'] as Map<String, dynamic>?)?['name']
            as String? ??
        'Standard';
    final statusRaw =
        (_subscription?['status'] as String?)?.toUpperCase() ?? 'INACTIVE';
    final isActive = statusRaw == 'ACTIVE';
    final statusColor = isActive ? AppColors.brand : AppColors.energy;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // THE FIX: The dark base color MUST be here in the main decoration!
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // THE BLOBS: Positioned.fill ensures the blur applies beautifully over the dark background
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Stack(
                  children: [
                    Positioned(
                      top: -64,
                      right: -48,
                      child: Container(
                        width: 176,
                        height: 176,
                        decoration: const BoxDecoration(
                          color: Color(0xFF9182F9),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -56,
                      left: -40,
                      child: Container(
                        width: 144,
                        height: 144,
                        decoration: const BoxDecoration(
                          color: Color(0xFF26B6E8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 100,
                      left: 120,
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB03A),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // THE CONTENT LAYER
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: AppColors.gradientSunrise,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.ssid_chart,
                                color: Color(0xFF131316),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) =>
                                    AppColors.gradientSunrise.createShader(bounds),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Vishal Fitness',
                                    style: AppStyles.displayFont.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusRaw,
                              style: AppStyles.eyebrow.copyWith(
                                color: statusColor,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'MEMBER',
                        style: AppStyles.eyebrow.copyWith(
                          color: Colors.white54,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: AppStyles.displayFont.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _buildDetailColumn('PLAN', passName)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildDetailColumn('ID', memberId)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildDetailColumn('EXPIRES', formattedExpiry)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Real Perforation
                const SizedBox(height: 24),
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 24,
                        decoration: BoxDecoration(
                          color: context.bg,
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final boxWidth = constraints.constrainWidth();
                            const dashWidth = 5.0;
                            const dashHeight = 1.0;
                            final dashCount = (boxWidth / (2 * dashWidth))
                                .floor();
                            return Flex(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              direction: Axis.horizontal,
                              children: List.generate(
                                dashCount,
                                (_) => SizedBox(
                                  width: dashWidth,
                                  height: dashHeight,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 12,
                        height: 24,
                        decoration: BoxDecoration(
                          color: context.bg,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 160.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F0F0F),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F0F0F),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scan at the gym entry',
                  style: AppStyles.bodyFont.copyWith(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Ensure this helper stays in place
  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppStyles.eyebrow.copyWith(
            color: Colors.white54,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppStyles.bodyFont.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildManualCheckInBtn() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        // THE FIX: Changed from Cyan to match the React button's vibrant gradient
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB03A), Color(0xFFFF4B8C)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isCheckingIn ? null : _handleCheckIn,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isCheckingIn)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFF131316),
                    strokeWidth: 2,
                  ),
                )
              else ...[
                const Icon(
                  Icons.qr_code_scanner,
                  color: Color(0xFF131316),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Manual check-in',
                  style: AppStyles.bodyFont.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF131316),
                    fontSize: 15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentVisits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'RECENT VISITS',
            style: AppStyles.eyebrow.copyWith(
              color: context.mutedFg,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 16),

        if (_checks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppStyles.radiusLg),
              border: Border.all(color: context.border.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                'No visits yet. Check in to start your streak.',
                style: AppStyles.bodyFont.copyWith(
                  color: context.mutedFg,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          Column(
            children: _checks.asMap().entries.map((entry) {
              int idx = entry.key;
              var check = entry.value;
              DateTime checkedInAt = DateTime.parse(
                check['checked_in_at'],
              ).toLocal();

              List<Color> accents = [
                AppColors.brand,
                AppColors.energy,
                AppColors.pulse,
                AppColors.aqua,
                AppColors.sun,
              ];
              Color dotColor = accents[idx % accents.length];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12), // py-3
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                DateFormat('EEE d MMM').format(checkedInAt),
                                style: AppStyles.bodyFont.copyWith(
                                  fontSize: 14,
                                  color: context.fg,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(checkedInAt),
                      style: AppStyles.bodyFont.copyWith(
                        color: context.mutedFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
