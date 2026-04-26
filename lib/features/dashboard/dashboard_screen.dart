import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../main.dart'; // Import to access the global 'supabase' client

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _displayName = '';
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Query the profiles table for this specific user
      final data = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final fullName = data != null ? data['full_name'] as String? : null;

      if (mounted) {
        setState(() {
          if (fullName != null && fullName.isNotEmpty) {
            _displayName = fullName;
          } else {
            // Smart fallback: If they haven't set a name yet, use their email prefix
            // e.g., 'sahil@gym.com' becomes 'Sahil'
            final emailPrefix = user.email?.split('@')[0] ?? 'Athlete';
            // Capitalize the first letter
            _displayName =
                emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
          }
          _isLoadingName = false;
        });
      }
    } catch (e) {
      // If there's an error fetching, fallback gracefully
      if (mounted) {
        setState(() {
          _displayName = 'Athlete';
          _isLoadingName = false;
        });
      }
    }
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 12) return 'Good morning,';
    if (hour >= 12 && hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Let MainLayout background show through
      body: SingleChildScrollView(
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
                .animate(key: ValueKey('streak_anim_${DateTime.now().second}')) // Dynamic key to trigger animation
                .scale(
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.8, 0.8),
                )
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            _buildStatCards(),
            const SizedBox(height: 32),
            _buildLiveStatus(), // Added to main display list
            const SizedBox(height: 32),
            _buildUpNextSection(),
            const SizedBox(height: 32),
            _buildLeaderboard(), // NEW: Community Leaderboard
            const SizedBox(height: 48),
            _buildFooter(context),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final now = DateTime.now();
    final dateStr = DateFormat('EEE · d MMM').format(now).toUpperCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: AppColors.energy),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dateStr,
                    style: AppStyles.eyebrow.copyWith(
                      color: context.mutedFg,
                      letterSpacing: 1.5,
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

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getTimeBasedGreeting(),
          style: Theme.of(
            context,
          ).textTheme.displayLarge?.copyWith(fontSize: 32, height: 1.1),
        ),
        // Use a loading skeleton or the actual name
        _isLoadingName
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
                    style: Theme.of(
                      context,
                    ).textTheme.displayLarge?.copyWith(fontSize: 32, height: 1.1),
                    maxLines: 2,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildLiveStatus() {
    final isDark = context.isDark;
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
          child: Text.rich(
            TextSpan(
              style: AppStyles.bodyFont.copyWith(
                color: isDark ? Colors.white70 : context.mutedFg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: '147 ',
                  style: AppStyles.numTabular.copyWith(
                    color: isDark ? Colors.white : context.fg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: 'athletes training right now'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF222222), // Lighter surface for dark mode
                  const Color(0xFF1A1A1A),
                  const Color(0xFF111111),
                ]
              : [
                  const Color(0xFF0F0F0F), // Rich black for light mode contrast
                  const Color(0xFF252525),
                ],
        ),
        border: isDark 
            ? Border.all(color: Colors.white.withOpacity(0.1), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? AppColors.pulse.withOpacity(0.15) // Violet glow in dark mode
                : AppColors.energy.withOpacity(0.3), // Orange glow in light mode
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
                    Icon(Icons.bolt, color: isDark ? AppColors.brand : AppColors.sun, size: 16),
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
                  color: Colors.black.withOpacity(0.3),
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isDark ? AppColors.gradientBrand : AppColors.gradientEnergy,
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
                    (isDark ? AppColors.gradientBrand : AppColors.gradientEnergy).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                child: Text(
                  '0',
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
                    color: isDark ? AppColors.brand.withOpacity(0.3) : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Start your streak with today's check-in.",
            style: AppStyles.bodyFont.copyWith(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: 'WEEK\nVOLUME',
            value: '2,113 kg',
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
            value: '1',
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
          color: isDark ? Colors.white.withOpacity(0.05) : context.border.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
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
                  color: tintColor.withOpacity(isDark ? 0.05 : 0.8),
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
                            color: isDark ? Colors.white70 : context.mutedFg,
                            height: 1.4,
                            fontWeight: isDark ? FontWeight.w600 : FontWeight.normal,
                          ),
                          softWrap: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? iconBgColor.withOpacity(0.2) : iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: isDark ? iconBgColor : iconColor, size: 16),
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

  Widget _buildLeaderboard() {
    final isDark = context.isDark;
    final List<Map<String, dynamic>> topAthletes = [
      {'name': 'Sahil R.', 'volume': '12,450', 'streak': 14, 'rank': 1},
      {'name': 'Arjun V.', 'volume': '10,200', 'streak': 8, 'rank': 2},
      {'name': 'Rahul S.', 'volume': '9,800', 'streak': 21, 'rank': 3},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TOP ATHLETES THIS WEEK',
              style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
            ),
            const Icon(Icons.emoji_events_outlined, size: 16, color: AppColors.sun),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(AppStyles.radiusLg),
            border: Border.all(color: context.border.withOpacity(0.5)),
          ),
          child: Column(
            children: topAthletes.map((athlete) {
              final isFirst = athlete['rank'] == 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: athlete['rank'] != 3 
                      ? Border(bottom: BorderSide(color: context.border.withOpacity(0.3)))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isFirst ? AppColors.sun.withOpacity(0.2) : context.muted,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '#${athlete['rank']}',
                        style: AppStyles.bodyFont.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isFirst ? AppColors.sun : context.mutedFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            athlete['name'],
                            style: AppStyles.bodyFont.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${athlete['streak']} day streak',
                            style: AppStyles.bodyFont.copyWith(
                              fontSize: 12,
                              color: context.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${athlete['volume']} kg',
                          style: AppStyles.numTabular.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                          ),
                        ),
                        Text(
                          'total volume',
                          style: AppStyles.bodyFont.copyWith(
                            fontSize: 10,
                            color: context.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUpNextSection() {
    return Text(
      'UP NEXT THIS WEEK',
      style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
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
}

