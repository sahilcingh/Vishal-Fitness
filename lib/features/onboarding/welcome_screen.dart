import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../auth/sign_in_screen.dart';
import '../../main.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _liveCount = 0;
  List<Map<String, dynamic>> _passes = [];

  static const List<LinearGradient> _passGradients = [
    AppColors.gradientBrand,
    AppColors.gradientEnergy,
    AppColors.gradientCool,
    AppColors.gradientSunrise,
  ];

  // Gym open hours: Mon–Sat 6 AM – 10 PM
  bool get _isGymOpen {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon … 7=Sun
    if (weekday == DateTime.sunday) return false;
    final hour = now.hour;
    return hour >= 6 && hour < 22;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _fetchLiveCount();
    _fetchPasses();
  }

  Future<void> _fetchPasses() async {
    try {
      final res = await supabase
          .from('gym_passes')
          .select()
          .eq('is_active', true)
          .order('duration_days', ascending: true);
      debugPrint('🎟️ Active passes fetched (${(res as List).length}): '
          '${res.map((p) => p['name']).join(', ')}');
      if (mounted) {
        setState(() => _passes = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      debugPrint('❌ _fetchPasses error: $e');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveCount() async {
    try {
      final twoHoursAgo = DateTime.now()
          .subtract(const Duration(hours: 2))
          .toIso8601String();
      final res = await supabase
          .from('check_ins')
          .select('id')
          .gte('checked_in_at', twoHoursAgo);
      if (mounted) {
        setState(() => _liveCount = (res as List).length);
      }
    } catch (_) {
      // Non-critical — leave count at 0
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: context.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) => CustomPaint(
                painter: _OrbsPainter(
                  t: _animController.value,
                  isDark: context.isDark,
                ),
              ),
            ),
          ),
          SafeArea(
            child: isWide
                ? _buildWideContent(context)
                : _buildNarrowContent(context),
          ),
        ],
      ),
    );
  }

  // ── Narrow (mobile) ───────────────────────────────────────────────────────
  Widget _buildNarrowContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.containerPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildTopBar(context),
          const SizedBox(height: 16),
          _buildHeroSection(context),
          const SizedBox(height: 32),
          _buildFeaturePills(context),
          const SizedBox(height: 12),
          _buildStatCards(context),
          const SizedBox(height: 32),
          _buildLiveStatus(context),
          const SizedBox(height: 40),
          _buildMembershipsSection(context),
          const SizedBox(height: 32),
          _buildFooter(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Wide (web / tablet) ───────────────────────────────────────────────────
  Widget _buildWideContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildTopBar(context),
          const SizedBox(height: 52),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left — hero copy + feature badges
              Expanded(
                flex: 55,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(context),
                    const SizedBox(height: 28),
                    _buildLiveStatus(context),
                    const SizedBox(height: 28),
                    _buildFeatureBadges(context),
                  ],
                ),
              ),
              const SizedBox(width: 72),
              // Right — cards + stats + hours
              Expanded(
                flex: 45,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFeaturePills(context),
                    const SizedBox(height: 12),
                    _buildStatCards(context),
                    const SizedBox(height: 12),
                    _buildGymHoursCard(context),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildWideHighlightsStrip(context),
          const SizedBox(height: 40),
          _buildMembershipsSection(context, isWide: true),
          const SizedBox(height: 40),
          _buildFooter(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureBadges(BuildContext context) {
    final badges = [
      (Icons.event_available, 'Book Classes'),
      (Icons.qr_code_scanner, 'Digital Pass'),
      (Icons.trending_up, 'Track Progress'),
      (Icons.people, 'Community'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: badges.map((b) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(b.$1, size: 14, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                b.$2,
                style: AppStyles.bodyFont.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.fg,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWideHighlightsStrip(BuildContext context) {
    final items = [
      (
        Icons.sports_gymnastics,
        AppColors.brand,
        'Expert Trainers',
        'Certified professionals guiding every step of your fitness journey.',
        () => _showWorkoutsDialog(context),
        'View facilities',
      ),
      (
        Icons.location_on,
        AppColors.energy,
        'Prime Location',
        'Conveniently located in Unnao with easy access and ample parking.',
        () async {
          final Uri url = Uri.parse(
            'https://maps.google.com/?q=Vishal+Fitness+Unnao',
          );
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            debugPrint('Could not launch maps');
          }
        },
        'Open Maps',
      ),
      (
        Icons.star_rounded,
        AppColors.aqua,
        'Top Rated',
        '4.9 stars from 200+ members — Unnao\'s most loved fitness centre.',
        () async {
          final Uri url = Uri.parse(
            'https://www.instagram.com/vishal.fitness.unnao',
          );
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            debugPrint('Could not launch instagram');
          }
        },
        'Follow us',
      ),
    ];
    return Row(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final color = item.$2;
        return Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: item.$5,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: EdgeInsets.only(right: i < items.length - 1 ? 12 : 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppStyles.radiusLg),
                  border: Border.all(color: context.border.withValues(alpha: 0.7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.$1, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$3,
                            style: AppStyles.bodyFont.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.fg,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$4,
                            style: AppStyles.bodyFont.copyWith(
                              fontSize: 11,
                              color: context.mutedFg,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                item.$6,
                                style: AppStyles.bodyFont.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.arrow_forward, size: 10, color: color),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGymHoursCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        border: Border.all(color: context.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.schedule, color: AppColors.brand, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GYM HOURS',
                  style: AppStyles.eyebrow.copyWith(
                    color: AppColors.brand,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mon – Sat  ·  6:00 AM – 10:00 PM',
                  style: AppStyles.bodyFont.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.fg,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_isGymOpen ? AppColors.brand : AppColors.energy)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isGymOpen ? 'OPEN' : 'CLOSED',
              style: AppStyles.eyebrow.copyWith(
                color: _isGymOpen ? AppColors.brand : AppColors.energy,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignInScreen()),
            );
          },
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: context.fg.withValues(alpha: 0.8)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          child: Text(
            'Sign in',
            style: AppStyles.bodyFont.copyWith(
              color: context.fg,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 14, color: AppColors.pulse),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'YOUR FITNESS OUR COMMITMENT 💪',
                  style: AppStyles.eyebrow.copyWith(color: context.fg),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              height: 1.05,
              fontSize: 46,
            ),
            children: const [
              TextSpan(text: 'One pass.\n'),
              TextSpan(text: 'Every '),
              TextSpan(
                text: 'workout.\n',
                style: TextStyle(color: AppColors.pulse),
              ),
            ],
          ),
        ),

        Text(
          'Zero friction.',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            height: 1.05,
            fontSize: 46,
            color: context.fg,
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'A vibrant operating system for the modern gym — book classes, track lifts, log progress, and walk in with a single QR.',
          style: AppStyles.bodyFont.copyWith(
            fontSize: 15,
            height: 1.5,
            color: context.fg,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),

        Container(
          decoration: BoxDecoration(
            gradient: AppColors.gradientBrand,
            borderRadius: BorderRadius.circular(30),
          ),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignInScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Member Login',
                  style: AppStyles.bodyFont.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.primaryColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18, color: context.primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturePills(BuildContext context) {
    return Column(
      children: [
        _buildInstaPromo(context),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildIconCard(
              context,
              Icons.fitness_center,
              AppColors.brand,
              'Workouts',
              subtitle: '50+ machines & free weights',
              onTap: () => _showWorkoutsDialog(context),
            ),
            _buildIconCard(
              context,
              Icons.female,
              AppColors.energy,
              'Ladies Hours',
              subtitle: '4:00–5:30 PM · Mon–Sat',
              onTap: () => _showLadiesTimingsDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstaPromo(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final Uri url = Uri.parse('https://www.instagram.com/vishal.fitness.unnao');
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          debugPrint('Could not launch $url');
        }
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFF56040)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFD1D1D).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Follow @vishal.fitness.unnao',
                    style: AppStyles.bodyFont.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Watch our latest reels & workout tips! 🚀',
                    style: AppStyles.bodyFont.copyWith(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Follow',
                style: AppStyles.bodyFont.copyWith(
                  color: const Color(0xFFE1306C),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconCard(
    BuildContext context,
    IconData icon,
    Color iconColor,
    String label, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppStyles.radiusLg),
            border: Border.all(color: context.border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: AppStyles.bodyFont.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.fg,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppStyles.bodyFont.copyWith(
                    fontSize: 11,
                    color: context.mutedFg,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard(context, '200+', 'ATHLETES', AppColors.brand),
        _buildStatCard(context, '100', 'CLASSES/WK', AppColors.energy),
        _buildStatCard(context, '4.9', 'RATING', AppColors.aqua),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    Color valueColor,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          border: Border.all(color: context.border.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppStyles.displayFont.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: valueColor,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: AppStyles.eyebrow.copyWith(
                  color: context.fg,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatus(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppStyles.bodyFont.copyWith(
                color: context.fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: _liveCount > 0 ? '$_liveCount ' : '',
                  style: AppStyles.numTabular.copyWith(
                    color: context.fg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: _liveCount > 0
                      ? 'athletes checked in today'
                      : 'Be the first to check in today!',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Membership Plans ─────────────────────────────────────────────────────

  Widget _buildMembershipsSection(BuildContext context, {bool isWide = false}) {
    if (_passes.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat('#,##0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.card_membership, color: AppColors.brand, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MEMBERSHIP PLANS',
                  style: AppStyles.eyebrow.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pick the plan that fits your goals',
                  style: AppStyles.bodyFont.copyWith(
                    color: context.mutedFg,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Pass cards
        if (isWide)
          _buildWidePassGrid(context, fmt)
        else
          _buildNarrowPassScroll(context, fmt),

        const SizedBox(height: 24),

        // Contact CTA
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppStyles.radiusLg),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientBrand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to join?',
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Visit us at the gym or contact staff to get registered.',
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 12,
                        color: context.mutedFg,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('https://www.instagram.com/vishal.fitness.unnao');
                  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                    debugPrint('Could not open Instagram');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientBrand,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Contact',
                    style: AppStyles.bodyFont.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWidePassGrid(BuildContext context, NumberFormat fmt) {
    // Use LayoutBuilder so all passes always fit the available width exactly
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _passes.length;
        final totalGaps = (count - 1) * 16.0;
        final cardWidth = (constraints.maxWidth - totalGaps) / count;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _passes.asMap().entries.map((entry) {
            final i = entry.key;
            return SizedBox(
              width: cardWidth,
              child: Padding(
                padding: EdgeInsets.only(right: i < count - 1 ? 16 : 0),
                child: _buildPassCard(context, _passes[i], i, fmt),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNarrowPassScroll(BuildContext context, NumberFormat fmt) {
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: _passes.length,
        separatorBuilder: (_, i) => const SizedBox(width: 14),
        itemBuilder: (_, i) => SizedBox(
          width: 240,
          child: _buildPassCard(context, _passes[i], i, fmt),
        ),
      ),
    );
  }

  Widget _buildPassCard(
    BuildContext context,
    Map<String, dynamic> pass,
    int index,
    NumberFormat fmt,
  ) {
    final gradient = _passGradients[index % _passGradients.length];
    final shadowColor = gradient.colors.first;
    final price = (pass['price'] as num?) ?? 0;
    final durationDays = (pass['duration_days'] as int?) ?? 30;
    final name = pass['name'] as String? ?? 'Pass';
    final features = (pass['features'] as List?)?.cast<String>() ?? [];
    final perMonth = durationDays > 0
        ? (price / (durationDays / 30)).round()
        : price;

    // Savings vs 1-month prorated
    String? savingsLabel;
    if (_passes.isNotEmpty && index > 0) {
      final first = _passes[0];
      final firstDays = (first['duration_days'] as int?) ?? 30;
      if (firstDays > 0) {
        final firstMonthly = (first['price'] as num) / (firstDays / 30);
        final thisMonthly = price / (durationDays / 30);
        final pct = ((1 - thisMonthly / firstMonthly) * 100).round();
        if (pct > 0) savingsLabel = 'Save $pct%';
      }
    }
    final isBest = index == _passes.length - 1 && _passes.length > 1;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row — name + badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: AppStyles.displayFont.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$durationDays days',
                      style: AppStyles.bodyFont.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isBest)
                    _passBadge('BEST VALUE'),
                  if (savingsLabel != null) ...[
                    if (isBest) const SizedBox(height: 4),
                    _passBadge(savingsLabel),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fmt.format(price)}',
                  style: AppStyles.displayFont.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/ $durationDays days',
                    style: AppStyles.bodyFont.copyWith(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Per-month pill
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '₹${fmt.format(perMonth)} / mo',
              style: AppStyles.numTabular.copyWith(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          if (features.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Divider
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.20),
            ),
            const SizedBox(height: 12),

            // Top 3 features
            ...features.take(3).map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: AppStyles.bodyFont.copyWith(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.90),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (features.length > 3)
              Text(
                '+${features.length - 3} more benefits',
                style: AppStyles.eyebrow.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 9,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _passBadge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppStyles.eyebrow.copyWith(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

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
              color: context.fg.withValues(alpha: 0.8),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
            children: const [
              TextSpan(text: 'APP MADE BY '),
              TextSpan(
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

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showWorkoutsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: AppColors.brand,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Facilities',
                          style: AppStyles.displayFont.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.fg,
                          ),
                        ),
                        Text(
                          'Everything you need to crush your goals.',
                          style: AppStyles.bodyFont.copyWith(
                            fontSize: 14,
                            color: context.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'WHAT WE OFFER',
                style: AppStyles.eyebrow.copyWith(color: AppColors.brand),
              ),
              const SizedBox(height: 16),
              _buildTimingDetailRow(
                context,
                icon: Icons.directions_run,
                title: 'Cardio & Strength',
                subtitle: 'State-of-the-art equipment & free weights',
              ),
              const SizedBox(height: 16),
              _buildTimingDetailRow(
                context,
                icon: Icons.sports_martial_arts,
                title: 'Yoga & Zumba',
                subtitle: 'Group classes for flexibility & rhythm',
              ),
              const SizedBox(height: 16),
              _buildTimingDetailRow(
                context,
                icon: Icons.local_fire_department,
                title: 'CrossFit & HIIT',
                subtitle: 'High-intensity functional training zones',
              ),
              const SizedBox(height: 28),
              Text(
                'PASS OPTIONS',
                style: AppStyles.eyebrow.copyWith(color: AppColors.brand),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: supabase
                    .from('gym_passes')
                    .select()
                    .eq('is_active', true)
                    .order('duration_days', ascending: true)
                    .then((value) => List<Map<String, dynamic>>.from(value)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(color: AppColors.brand),
                      ),
                    );
                  }
                  final passes = snapshot.data ?? [];
                  if (passes.isEmpty) {
                    return Text(
                      'No passes available right now.',
                      style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
                    );
                  }
                  final fmt = NumberFormat('#,##0');
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: passes.map((pass) {
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 60) / 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(AppStyles.radiusSm),
                            border: Border.all(color: context.border.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  pass['name'] as String? ?? '—',
                                  style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${fmt.format(pass['price'])}',
                                style: AppStyles.displayFont.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: context.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: AppStyles.bodyFont.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
              ),         // Column
            ),           // SingleChildScrollView
          ),             // Container
        );               // ConstrainedBox
      },
    );
  }

  void _showLadiesTimingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
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
                    color: context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.energy.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.female, color: AppColors.energy, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exclusive Ladies Hours',
                          style: AppStyles.displayFont.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.fg,
                          ),
                        ),
                        Text(
                          'Safe, comfortable, and empowering.',
                          style: AppStyles.bodyFont.copyWith(
                            fontSize: 14,
                            color: context.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildTimingDetailRow(
                context,
                icon: Icons.schedule,
                title: '4:00 PM - 5:30 PM',
                subtitle: 'Everyday from Monday to Saturday',
              ),
              const SizedBox(height: 20),
              _buildTimingDetailRow(
                context,
                icon: Icons.sports_gymnastics,
                title: 'Female Trainer Available',
                subtitle: 'Expert guidance for your fitness goals',
              ),
              const SizedBox(height: 20),
              _buildTimingDetailRow(
                context,
                icon: Icons.privacy_tip_outlined,
                title: '100% Privacy Assured',
                subtitle: 'Gym closed to men during these hours',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.energy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: AppStyles.bodyFont.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimingDetailRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.energy, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppStyles.bodyFont.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: context.fg,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppStyles.bodyFont.copyWith(
                  fontSize: 14,
                  color: context.mutedFg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _OrbsPainter extends CustomPainter {
  final double t;
  final bool isDark;

  const _OrbsPainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = isDark ? AppColors.darkBackground : AppColors.lightBackground,
    );

    // Softer in dark mode so content stays readable
    final double alpha = isDark ? 0.20 : 0.10;

    // Brand green — top-left, slow drift
    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.05 + 0.06 * cos(t * 2 * pi)),
        size.height * (0.15 + 0.05 * sin(t * 2 * pi)),
      ),
      radius: size.width * 0.42,
      color: AppColors.brand.withValues(alpha: alpha),
      blur: 100,
    );

    // Energy orange — bottom-right, opposite phase
    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.95 + 0.04 * cos(t * 2 * pi + pi)),
        size.height * (0.85 + 0.03 * sin(t * 2 * pi + pi)),
      ),
      radius: size.width * 0.38,
      color: AppColors.energy.withValues(alpha: alpha * 0.8),
      blur: 90,
    );

    // Pulse violet — mid-right, slow vertical bob
    _drawOrb(
      canvas,
      center: Offset(
        size.width * 0.90,
        size.height * (0.40 + 0.07 * sin(t * 2 * pi + pi / 3)),
      ),
      radius: size.width * 0.26,
      color: AppColors.pulse.withValues(alpha: alpha * 0.6),
      blur: 80,
    );
  }

  void _drawOrb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double blur,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  @override
  bool shouldRepaint(_OrbsPainter old) =>
      old.t != t || old.isDark != isDark;
}
