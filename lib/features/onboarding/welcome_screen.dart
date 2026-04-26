import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../auth/sign_in_screen.dart';
import 'programs_screen.dart';

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
                  ? Colors.black.withOpacity(0.6)
                  : Colors.white.withOpacity(0.4),
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
                        color: AppColors.brand.withOpacity(0.15),
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
              side: BorderSide(color: context.fg.withOpacity(0.8)),
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
            ),
            _buildIconCard(
              context,
              Icons.qr_code_scanner,
              AppColors.aqua,
              'QR pass',
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
              color: const Color(0xFFFD1D1D).withOpacity(0.3),
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
                color: Colors.white.withOpacity(0.2),
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
                      color: Colors.white.withOpacity(0.9),
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
                    color: Colors.black.withOpacity(0.1),
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
    String label,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.card.withOpacity(0.9), // Added slight opacity
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          border: Border.all(color: context.border.withOpacity(0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                color: iconColor.withOpacity(0.15),
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
          color: context.card.withOpacity(0.9), // Added slight opacity
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          border: Border.all(color: context.border.withOpacity(0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
              color: context.fg.withOpacity(
                0.8,
              ), // Darkened from lightMutedForeground
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
}
