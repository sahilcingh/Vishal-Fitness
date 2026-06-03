import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../main.dart';
import 'registration_details_screen.dart';
import 'package:intl/intl.dart';

class ProgramsScreen extends StatefulWidget {
  final String? prefillName;
  final String? prefillPhone;
  final String? prefillEmail;
  final String? prefillPassword;

  const ProgramsScreen({
    super.key,
    this.prefillName,
    this.prefillPhone,
    this.prefillEmail,
    this.prefillPassword,
  });

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedPassIndex = 0;
  List<Map<String, dynamic>> _activePasses = [];
  bool _isLoading = true;
  late AnimationController _animController;

  final List<LinearGradient> _passGradients = [
    AppColors.gradientBrand,
    AppColors.gradientEnergy,
    AppColors.gradientCool,
    AppColors.gradientSunrise,
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _fetchPasses();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchPasses() async {
    try {
      final response = await supabase
          .from('gym_passes')
          .select()
          .eq('is_active', true)
          .order('duration_days', ascending: true);

      if (mounted) {
        setState(() {
          _activePasses = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching active passes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: context.bg,
      body: Stack(
        children: [
          // Subtle animated orbs background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) => CustomPaint(
                painter: _ProgramsOrbsPainter(
                  t: _animController.value,
                  isDark: context.isDark,
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  )
                : _activePasses.isEmpty
                    ? _buildEmptyState(context)
                    : isWide
                        ? _buildWideLayout(context)
                        : _buildNarrowLayout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        _buildDurationSelector(context),
        Expanded(
          child: _buildPassDetails(_activePasses[_selectedPassIndex]),
        ),
        _buildStickyFooter(),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final pass = _activePasses[_selectedPassIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 80),
          child: _buildHeader(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 80),
          child: _buildDurationSelector(context),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: pass card + gym highlights
                Expanded(
                  flex: 55,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 8, right: 16, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPassGradientCard(pass),
                        const SizedBox(height: 16),
                        _buildGymHighlightsCards(context),
                      ],
                    ),
                  ),
                ),
                // Right: features section
                Expanded(
                  flex: 45,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 8, left: 16, bottom: 16),
                    child: _buildFeaturesSection(context, pass),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildStickyFooter(),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Center(
            child: Text(
              'No passes currently available.',
              style: AppStyles.bodyFont.copyWith(color: context.mutedFg),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppStyles.containerPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.card.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: context.border),
              ),
              child: Icon(Icons.arrow_back, size: 20, color: context.fg),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Your Pass',
                style: AppStyles.displayFont.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: context.fg,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.containerPadding,
      ),
      child: Row(
        children: List.generate(_activePasses.length, (index) {
          final isSelected = _selectedPassIndex == index;
          final pass = _activePasses[index];
          final Color passColor =
              _passGradients[index % _passGradients.length].colors[0];
          final NumberFormat fmt = NumberFormat('#,##0');
          final String price = fmt.format(pass['price']);

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPassIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                  right: index == _activePasses.length - 1 ? 0 : 8,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? passColor.withValues(alpha: 0.12)
                      : context.card.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                  border: Border.all(
                    color: isSelected ? passColor : context.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pass['name'].toString(),
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? passColor
                            : context.fg.withValues(alpha: 0.75),
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₹$price',
                        style: AppStyles.numTabular.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? passColor : context.mutedFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPassDetails(Map<String, dynamic> pass) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppStyles.containerPadding,
        0,
        AppStyles.containerPadding,
        AppStyles.containerPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPassGradientCard(pass),
          const SizedBox(height: 28),
          _buildFeaturesSection(context, pass),
        ],
      ),
    );
  }

  Widget _buildPassGradientCard(Map<String, dynamic> pass) {
    final NumberFormat fmt = NumberFormat('#,##0');
    final String price = fmt.format(pass['price']);
    final int durationDays = (pass['duration_days'] as int?) ?? 30;
    final double perMonthRaw = durationDays > 0
        ? (pass['price'] as num) / (durationDays / 30)
        : (pass['price'] as num).toDouble();
    final String perMonth = fmt.format(perMonthRaw.round());
    final bool isBestValue =
        _selectedPassIndex == _activePasses.length - 1 &&
        _activePasses.length > 1;
    final LinearGradient gradient =
        _passGradients[_selectedPassIndex % _passGradients.length];
    final Color shadowColor = gradient.colors[0];

    String? savingsLabel;
    if (_activePasses.isNotEmpty && _selectedPassIndex > 0) {
      final first = _activePasses[0];
      final firstDays = (first['duration_days'] as int?) ?? 30;
      final firstMonthly = firstDays > 0
          ? (first['price'] as num) / (firstDays / 30)
          : (first['price'] as num).toDouble();
      final thisMonthly = durationDays > 0
          ? (pass['price'] as num) / (durationDays / 30)
          : (pass['price'] as num).toDouble();
      final savings = ((1 - thisMonthly / firstMonthly) * 100).round();
      if (savings > 0) savingsLabel = 'Save $savings%';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'VISHAL FITNESS\n${pass['name'].toString().toUpperCase()}',
                  style: AppStyles.displayFont.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    height: 1.15,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'BEST VALUE',
                        style: AppStyles.eyebrow.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  if (savingsLabel != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        savingsLabel,
                        style: AppStyles.eyebrow.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Premium Gym Experience in Unnao',
            style: AppStyles.bodyFont.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$price',
                style: AppStyles.displayFont.copyWith(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ $durationDays days',
                  style: AppStyles.bodyFont.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹$perMonth',
                      style: AppStyles.numTabular.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'per month',
                      style: AppStyles.bodyFont.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(BuildContext context, Map<String, dynamic> pass) {
    final List<dynamic> features = pass['features'] ?? [];
    final Color accentColor =
        _passGradients[_selectedPassIndex % _passGradients.length].colors[0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "WHAT'S INCLUDED",
              style: AppStyles.eyebrow.copyWith(
                color: context.fg,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${features.length} benefits',
              style: AppStyles.eyebrow.copyWith(
                color: context.mutedFg,
                fontSize: 9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...List.generate((features.length / 2).ceil(), (rowIndex) {
          final li = rowIndex * 2;
          final ri = li + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildFeatureItem(context, features[li].toString(), accentColor),
                ),
                const SizedBox(width: 10),
                ri < features.length
                    ? Expanded(
                        child: _buildFeatureItem(context, features[ri].toString(), accentColor),
                      )
                    : const Expanded(child: SizedBox()),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGymHighlightsCards(BuildContext context) {
    final highlights = [
      (Icons.sports_gymnastics, AppColors.brand, 'Expert Trainers',
          'Certified coaches guiding every session.'),
      (Icons.location_on, AppColors.energy, 'Prime Location',
          'Easy access with ample parking in Unnao.'),
      (Icons.star_rounded, AppColors.aqua, 'Top Rated Gym',
          '4.9★ from 200+ happy members.'),
    ];
    return Column(
      children: highlights.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        return Container(
          margin: EdgeInsets.only(bottom: i < highlights.length - 1 ? 10 : 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppStyles.radiusMd),
            border: Border.all(color: context.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.$2.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.$1, color: item.$2, size: 18),
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
                    const SizedBox(height: 2),
                    Text(
                      item.$4,
                      style: AppStyles.bodyFont.copyWith(
                        fontSize: 11,
                        color: context.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String feature,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppStyles.radiusMd),
        border: Border.all(color: context.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 11, color: accentColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: AppStyles.bodyFont.copyWith(
                fontSize: 12,
                color: context.fg,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    final pass = _activePasses[_selectedPassIndex];
    final NumberFormat fmt = NumberFormat('#,##0');
    final String priceText = fmt.format(pass['price']);
    final LinearGradient gradient =
        _passGradients[_selectedPassIndex % _passGradients.length];
    final Color shadowColor = gradient.colors[0];

    return Container(
      padding: const EdgeInsets.all(AppStyles.containerPadding),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹$priceText',
                  style: AppStyles.displayFont.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.fg,
                  ),
                ),
                Text(
                  'for ${pass['name']}',
                  style: AppStyles.bodyFont.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.fg.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 2,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegistrationDetailsScreen(
                        durationDays: pass['duration_days'],
                        price: (pass['price'] as num).toDouble(),
                        passName: pass['name'],
                        prefillName: widget.prefillName,
                        prefillPhone: widget.prefillPhone,
                        prefillEmail: widget.prefillEmail,
                        prefillPassword: widget.prefillPassword,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppStyles.radiusMd),
                  ),
                ),
                child: Text(
                  'Buy Pass Now',
                  style: AppStyles.bodyFont.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramsOrbsPainter extends CustomPainter {
  final double t;
  final bool isDark;

  const _ProgramsOrbsPainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color =
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
    );

    final double alpha = isDark ? 0.16 : 0.07;

    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.88 + 0.04 * cos(t * 2 * pi)),
        size.height * (0.10 + 0.04 * sin(t * 2 * pi)),
      ),
      radius: size.width * 0.38,
      color: AppColors.brand.withValues(alpha: alpha),
      blur: 80,
    );

    _drawOrb(
      canvas,
      center: Offset(
        size.width * (0.08 + 0.03 * cos(t * 2 * pi + pi)),
        size.height * (0.88 + 0.03 * sin(t * 2 * pi + pi)),
      ),
      radius: size.width * 0.32,
      color: AppColors.energy.withValues(alpha: alpha * 0.85),
      blur: 70,
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
  bool shouldRepaint(_ProgramsOrbsPainter old) =>
      old.t != t || old.isDark != isDark;
}
