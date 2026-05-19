import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _displayName = '';
  int _streak = 0;
  double _weekVolume = 0;
  int _weekSessions = 0;
  List<Map<String, dynamic>> _upcomingClasses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final sevenDaysAgo =
          now.subtract(const Duration(days: 7)).toIso8601String();
      final sixtyDaysAgo =
          now.subtract(const Duration(days: 60)).toIso8601String();

      final results = await Future.wait([
        supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle(),
        supabase
            .from('check_ins')
            .select('checked_in_at')
            .eq('user_id', user.id)
            .gte('checked_in_at', sixtyDaysAgo)
            .order('checked_in_at', ascending: false),
        supabase
            .from('workout_logs')
            .select('volume_kg')
            .eq('user_id', user.id)
            .gte('performed_at', sevenDaysAgo),
        supabase
            .from('classes')
            .select('title, start_time')
            .gt('start_time', now.toIso8601String())
            .order('start_time', ascending: true)
            .limit(2),
      ]);

      final profileData = results[0] as Map<String, dynamic>?;
      final checkIns =
          List<Map<String, dynamic>>.from(results[1] as List);
      final weekLogs =
          List<Map<String, dynamic>>.from(results[2] as List);
      final classes =
          List<Map<String, dynamic>>.from(results[3] as List);

      final fullName = profileData?['full_name'] as String?;
      String displayName;
      if (fullName != null && fullName.isNotEmpty) {
        displayName = fullName;
      } else {
        final emailPrefix = user.email?.split('@')[0] ?? 'Athlete';
        displayName =
            emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
      }

      final weekVolume = weekLogs.fold(
          0.0, (sum, l) => sum + (l['volume_kg'] as num).toDouble());

      if (mounted) {
        setState(() {
          _displayName = displayName;
          _streak = _computeStreak(checkIns);
          _weekVolume = weekVolume;
          _weekSessions = weekLogs.length;
          _upcomingClasses = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          _displayName = 'Athlete';
          _isLoading = false;
        });
      }
    }
  }

  int _computeStreak(List<Map<String, dynamic>> checkIns) {
    if (checkIns.isEmpty) return 0;
    final Set<String> checkInDates = {};
    for (final ci in checkIns) {
      final dt = DateTime.parse(ci['checked_in_at']).toLocal();
      checkInDates.add(DateFormat('yyyy-MM-dd').format(dt));
    }
    final today = DateTime.now();
    int streak = 0;
    DateTime current = DateTime(today.year, today.month, today.day);
    while (true) {
      final key = DateFormat('yyyy-MM-dd').format(current);
      if (checkInDates.contains(key)) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 'Good morning,';
    if (hour >= 12 && hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.containerPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Date header
          const ShimmerBox(width: 120, height: 12, radius: 6),
          const SizedBox(height: 32),
          // Greeting
          const ShimmerBox(width: 160, height: 20, radius: 6),
          const SizedBox(height: 10),
          const ShimmerBox(width: 220, height: 32, radius: 8),
          const SizedBox(height: 32),
          // Streak card
          const ShimmerBoxDark(height: 180, radius: 20),
          const SizedBox(height: 16),
          // Stat cards
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 110, radius: 20)),
              SizedBox(width: 16),
              Expanded(child: ShimmerBox(height: 110, radius: 20)),
            ],
          ),
          const SizedBox(height: 32),
          // UP NEXT label
          const ShimmerBox(width: 140, height: 12, radius: 6),
          const SizedBox(height: 16),
          // UP NEXT card
          const ShimmerBox(height: 72, radius: 20),
          const SizedBox(height: 32),
          // Leaderboard label
          const ShimmerBox(width: 180, height: 12, radius: 6),
          const SizedBox(height: 16),
          const ShimmerBox(height: 64, radius: 20),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppStyles.containerPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildTopHeader(),
              const SizedBox(height: 24),
              _buildGreeting(),
              const SizedBox(height: 32),
              _buildStreakCard()
                  .animate(
                    key: ValueKey('streak_anim_${DateTime.now().second}'),
                  )
                  .scale(
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                    begin: const Offset(0.8, 0.8),
                  )
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 16),
              _buildStatCards(),
              const SizedBox(height: 32),
              _buildUpNextSection(),
              const SizedBox(height: 32),
              _buildComingSoon(
                'TOP ATHLETES THIS WEEK',
                'Leaderboard launching soon',
                AppColors.sun,
                Icons.emoji_events_outlined,
              ),
              const SizedBox(height: 48),
              _buildFooter(context),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final now = DateTime.now();
    final dateStr = DateFormat('EEE · d MMM').format(now).toUpperCase();

    return Row(
      children: [
        const Icon(Icons.auto_awesome, size: 16, color: AppColors.energy),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              dateStr,
              style: AppStyles.eyebrow
                  .copyWith(color: context.mutedFg, letterSpacing: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTimeBasedGreeting(),
          style: Theme.of(context)
              .textTheme
              .displayLarge
              ?.copyWith(fontSize: 32, height: 1.1),
        ),
        _isLoading
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Container(
                  height: 32,
                  width: 150,
                  decoration: BoxDecoration(
                    color: context.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )
            : ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    AppColors.gradientSunrise.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$_displayName.',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 32, height: 1.1),
                    maxLines: 2,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildStreakCard() {
    final isDark = context.isDark;
    final streakText = _streak == 0
        ? "Start your streak with today's check-in."
        : _streak == 1
            ? 'Great start! Come back tomorrow to keep it going.'
            : 'You\'re on fire! Keep the streak alive.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF222222),
                  const Color(0xFF1A1A1A),
                  const Color(0xFF111111),
                ]
              : [
                  const Color(0xFF0F0F0F),
                  const Color(0xFF252525),
                ],
        ),
        border: isDark
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.pulse.withValues(alpha: 0.15)
                : AppColors.energy.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
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
                child: Row(
                  children: [
                    Icon(Icons.bolt,
                        color: isDark ? AppColors.brand : AppColors.sun,
                        size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CURRENT STREAK',
                          style: AppStyles.eyebrow.copyWith(
                            color: isDark ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isDark
                        ? AppColors.gradientBrand
                        : AppColors.gradientEnergy,
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 20,
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
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    (isDark
                            ? AppColors.gradientBrand
                            : AppColors.gradientEnergy)
                        .createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  '$_streak',
                  style: AppStyles.displayFont.copyWith(
                    fontSize: 56,
                    height: 1.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'days on fire',
                style: AppStyles.bodyFont.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              12,
              (index) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: index < _streak.clamp(0, 12)
                        ? (isDark
                            ? AppColors.brand
                            : Colors.white.withValues(alpha: 0.85))
                        : (isDark
                            ? AppColors.brand.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.15)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            streakText,
            style: AppStyles.bodyFont.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final fmt = NumberFormat('#,##0');
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'WEEK\nVOLUME',
            value: _isLoading ? '—' : '${fmt.format(_weekVolume)} kg',
            icon: Icons.trending_up,
            iconColor: Colors.black,
            iconBgColor: AppColors.aqua,
            tintColor: const Color(0xFFDFF6EF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            label: 'SESSIONS /\n7D',
            value: _isLoading ? '—' : '$_weekSessions',
            icon: Icons.calendar_today,
            iconColor: Colors.black,
            iconBgColor: AppColors.pulse,
            tintColor: const Color(0xFFF1E6FF),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Color tintColor,
  }) {
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : context.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : context.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tintColor
                      .withValues(alpha: isDark ? 0.05 : 0.8),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: AppStyles.eyebrow.copyWith(
                            color: isDark
                                ? Colors.white70
                                : context.mutedFg,
                            height: 1.4,
                            fontWeight: isDark
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? iconBgColor.withValues(alpha: 0.2)
                              : iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon,
                            color: isDark ? iconBgColor : iconColor,
                            size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value,
                    style: AppStyles.displayFont.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black,
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

  Widget _buildUpNextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UP NEXT THIS WEEK',
          style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: context.muted,
              borderRadius: BorderRadius.circular(AppStyles.radiusLg),
            ),
          )
        else if (_upcomingClasses.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppStyles.radiusLg),
              border: Border.all(
                  color: context.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_outlined,
                    color: context.mutedFg, size: 20),
                const SizedBox(width: 12),
                Text(
                  'No classes scheduled yet.',
                  style: AppStyles.bodyFont
                      .copyWith(color: context.mutedFg, fontSize: 14),
                ),
              ],
            ),
          )
        else
          Column(
            children: _upcomingClasses.map((cls) {
              final startTime =
                  DateTime.parse(cls['start_time']).toLocal();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius:
                      BorderRadius.circular(AppStyles.radiusLg),
                  border: Border.all(
                      color: context.border.withValues(alpha: 0.5)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        decoration: const BoxDecoration(
                          gradient: AppColors.gradientBrand,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(AppStyles.radiusLg),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(startTime),
                              style: AppStyles.displayFont.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('EEE d').format(startTime).toUpperCase(),
                              style: AppStyles.eyebrow.copyWith(
                                  color: context.mutedFg, fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        color: context.border.withValues(alpha: 0.6),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Text(
                            cls['title'] ?? 'Class',
                            style: AppStyles.bodyFont.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildComingSoon(
    String title,
    String subtitle,
    Color accentColor,
    IconData icon,
  ) {
    final isDark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppStyles.eyebrow.copyWith(color: context.mutedFg)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : context.card,
            borderRadius: BorderRadius.circular(AppStyles.radiusLg),
            border: Border.all(
                color: context.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coming Soon',
                    style: AppStyles.bodyFont.copyWith(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    style: AppStyles.bodyFont.copyWith(
                        color: context.mutedFg, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
              color: context.fg.withValues(alpha: 0.5),
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
}
