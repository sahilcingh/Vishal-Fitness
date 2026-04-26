import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  bool isClassesTab = true;

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
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildTabToggle(),
              const SizedBox(height: 32),
              _buildTomorrowSection()
                  .animate(key: ValueKey('train_anim_${DateTime.now().second}'))
                  .scale(
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                    begin: const Offset(0.9, 0.9),
                  )
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 48),
              _buildFooter(context),
              const SizedBox(height: 120), // Bottom padding
            ],
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
              Icons.local_fire_department,
              size: 16,
              color: AppColors.energy,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'TOMORROW',
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
        RichText(
          text: TextSpan(
            style: Theme.of(
              context,
            ).textTheme.displayLarge?.copyWith(fontSize: 36, height: 1.1),
            children: const [
              TextSpan(text: 'Discovery'),
              TextSpan(
                text: '.',
                style: TextStyle(color: AppColors.pulse),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabToggle() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: context.muted,
        borderRadius: BorderRadius.circular(AppStyles.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isClassesTab = false),
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  gradient: !isClassesTab ? AppColors.gradientBrand : null,
                  borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Workouts',
                  style: AppStyles.bodyFont.copyWith(
                    fontWeight: !isClassesTab
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: !isClassesTab
                        ? context.primaryFg
                        : context.mutedFg,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isClassesTab = true),
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  gradient: isClassesTab ? AppColors.gradientBrand : null,
                  borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Classes',
                  style: AppStyles.bodyFont.copyWith(
                    fontWeight: isClassesTab
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: isClassesTab
                        ? context.primaryFg
                        : context.mutedFg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTomorrowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'TOMORROW',
            style: AppStyles.eyebrow.copyWith(
              color: context.mutedFg,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 16),
        _buildClassCard(),
      ],
    );
  }

  Widget _buildClassCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        border: Border.all(color: context.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: AppColors.gradientEnergy,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(AppStyles.radiusLg),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 16,
                top: 20,
                bottom: 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '00:06',
                    style: AppStyles.displayFont.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '50MIN',
                    style: AppStyles.eyebrow.copyWith(
                      color: context.mutedFg,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 16),
              color: context.border.withOpacity(0.6),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 20,
                  bottom: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Endurance Run Club',
                              style: AppStyles.bodyFont.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.gradientEnergy,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'CARDIO',
                            style: AppStyles.eyebrow.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mara Voss',
                      style: AppStyles.bodyFont.copyWith(
                        color: context.mutedFg,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 14,
                                  color: context.mutedFg,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '16',
                                  style: AppStyles.bodyFont.copyWith(
                                    color: context.mutedFg,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: context.mutedFg,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'medium',
                                  style: AppStyles.bodyFont.copyWith(
                                    color: context.mutedFg,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.border),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add,
                                size: 14,
                                color: context.fg,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reserve',
                                style: AppStyles.bodyFont.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: context.fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
