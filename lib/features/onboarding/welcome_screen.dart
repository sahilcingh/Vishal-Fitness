import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../auth/sign_in_screen.dart';
import 'programs_screen.dart';
import '../../main.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/vishal/gym_bg.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              context.isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.4),
              context.isDark ? BlendMode.darken : BlendMode.lighten,
            ),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
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
                const SizedBox(height: 32),
                _buildFooter(context),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
                  style: AppStyles.eyebrow.copyWith(
                    color: context.fg, // Darkened from lightMutedForeground
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(height: 1.05, fontSize: 46),
            children: const [
              TextSpan(text: 'One pass.\n'),
              TextSpan(text: 'Every '),
              TextSpan(
                text: 'workout.\n',
                style: TextStyle(color: AppColors.pulse), // Darkened from aqua
              ),
            ],
          ),
        ),

        Text(
          'Zero friction.',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            height: 1.05,
            fontSize: 46,
            color: context.fg, // Removed ShaderMask for solid dark text
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'A vibrant operating system for the modern gym — book classes, track lifts, log progress, and walk in with a single QR.',
          style: AppStyles.bodyFont.copyWith(
            fontSize: 15,
            height: 1.5,
            color: context.fg, // Darkened from lightMutedForeground
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
                MaterialPageRoute(builder: (context) => const ProgramsScreen()),
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
                  'Get your pass',
                  style: AppStyles.bodyFont.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.primaryColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: context.primaryColor,
                ),
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
              onTap: () => _showWorkoutsDialog(context),
            ),
            _buildIconCard(
              context,
              Icons.female,
              AppColors.energy,
              'Ladies Hours',
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
        final Uri url = Uri.parse(
          'https://www.instagram.com/vishal.fitness.unnao',
        ); // Replace with actual username if different
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
              // Using a standard camera icon as the logo
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
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.9), // Added slight opacity
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
                  fontSize: 11,
                  fontWeight: FontWeight.w600, // Made bolder
                  color: context.fg, // Darkened from lightMutedForeground
                ),
              ),
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
          color: context.card.withValues(alpha: 0.9), // Added slight opacity
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
                  color: context.fg, // Darkened from lightMutedForeground
                  fontSize: 9,
                  fontWeight: FontWeight.w700, // Made bolder
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
                color: context.fg, // Darkened from lightMutedForeground
                fontSize: 13,
                fontWeight: FontWeight.w500, // Added weight
              ),
              children: [
                TextSpan(
                  text: '147 ',
                  style: AppStyles.numTabular.copyWith(
                    color: context.fg,
                    fontWeight: FontWeight.bold, // Added weight
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
              color: context.fg.withValues(alpha: 0.8), // Darkened from lightMutedForeground
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700, // Added weight
            ),
            children: [
              const TextSpan(text: 'APP MADE BY '),
              const TextSpan(
                text: 'QYROXIS',
                style: TextStyle(
                  color: AppColors.brand, // Highlighted with the brand color
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWorkoutsDialog(BuildContext context) {
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
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: passes.map((pass) {
                      final NumberFormat formatter = NumberFormat('#,##0');
                      return SizedBox(
                        width: (MediaQuery.of(context).size.width - 60) / 2,
                        child: _buildPassCard(
                          context,
                          pass['name'],
                          '₹${formatter.format(pass['price'])}',
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
          ),
        );
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

  Widget _buildPassCard(BuildContext context, String duration, String price) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              duration,
              style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            price,
            style: AppStyles.displayFont.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.fg,
            ),
          ),
        ],
      ),
    );
  }
}
