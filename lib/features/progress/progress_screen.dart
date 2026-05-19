import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../main.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Match React: Fetch last 30 days of logs ordered by time
      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();

      final response = await supabase
          .from('workout_logs')
          .select('performed_at, volume_kg, duration_min, name')
          .eq('user_id', user.id)
          .gte('performed_at', thirtyDaysAgo)
          .order('performed_at', ascending: true);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Data Aggregation (Matching your React useMemo) ---
  List<Map<String, dynamic>> get _chartData {
    List<Map<String, dynamic>> days = [];
    final now = DateTime.now();

    // Generate the last 14 days
    for (int i = 13; i >= 0; i--) {
      DateTime d = now.subtract(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(d);
      String shortName = DateFormat(
        'E',
      ).format(d).substring(0, 1); // e.g., "M", "T"

      // Sum volume for this specific day
      double dailyVolume = _logs
          .where((l) {
            DateTime logDate = DateTime.parse(l['performed_at']);
            return DateFormat('yyyy-MM-dd').format(logDate) == dateKey;
          })
          .fold(0.0, (sum, l) => sum + (l['volume_kg'] as num).toDouble());

      days.add({'short': shortName, 'volume': dailyVolume});
    }
    return days;
  }

  double get _totalVolume =>
      _logs.fold(0.0, (sum, l) => sum + (l['volume_kg'] as num).toDouble());
  double get _totalMinutes =>
      _logs.fold(0.0, (sum, l) => sum + (l['duration_min'] as num).toDouble());
  int get _sessions => _logs.length;

  double get _bestDay {
    if (_chartData.isEmpty) return 0;
    return _chartData
        .map((d) => d['volume'] as double)
        .reduce((a, b) => a > b ? a : b);
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
          const ShimmerBox(width: 180, height: 36, radius: 8),
          const SizedBox(height: 24),
          // Chart card
          const ShimmerBox(height: 220, radius: 20),
          const SizedBox(height: 24),
          // Tiles row
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 100, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 100, radius: 20)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 100, radius: 20)),
            ],
          ),
          const SizedBox(height: 32),
          // PRs label + card
          const ShimmerBox(width: 160, height: 12, radius: 6),
          const SizedBox(height: 16),
          const ShimmerBox(height: 64, radius: 20),
          const SizedBox(height: 32),
          // Sessions label
          const ShimmerBox(width: 140, height: 12, radius: 6),
          const SizedBox(height: 16),
          // Session rows
          for (int i = 0; i < 5; i++) ...[
            const ShimmerBox(height: 52, radius: 12),
            const SizedBox(height: 12),
          ],
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
              onRefresh: _fetchLogs,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppStyles.containerPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    _buildMainChartCard()
                        .animate(
                          key: ValueKey('prog_anim_${DateTime.now().second}'),
                        )
                        .scale(
                          duration: 600.ms,
                          curve: Curves.easeOutBack,
                          begin: const Offset(0.9, 0.9),
                        )
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 24),
                    _buildTiles(),
                    const SizedBox(height: 32),
                    _buildPersonalRecords(),
                    const SizedBox(height: 32),
                    _buildRecentSessions(),
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

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.pulse),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'LAST 30 DAYS',
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
              TextSpan(text: 'Progress'),
              TextSpan(
                text: '.',
                style: TextStyle(color: AppColors.aqua),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainChartCard() {
    final NumberFormat formatter = NumberFormat('#,##0');
    final data = _chartData;
    final volumes = data.map((d) => d['volume'] as double).toList();
    final isDark = context.isDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      clipBehavior: Clip.hardEdge,
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
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark 
                    ? AppColors.brand.withOpacity(0.05) 
                    : const Color(0xFFE2F8EB),
              ),
            ),
          ),
          Positioned(
            left: -50,
            bottom: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark 
                    ? AppColors.aqua.withOpacity(0.05)
                    : const Color(0xFFE5F6FF),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL VOLUME',
                style: AppStyles.eyebrow.copyWith(
                  color: context.mutedFg,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatter.format(_totalVolume),
                        style: AppStyles.displayFont.copyWith(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'kg lifted',
                    style: AppStyles.bodyFont.copyWith(
                      fontSize: 16,
                      color: context.mutedFg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Dynamic Area Chart
              SizedBox(
                height: 80,
                width: double.infinity,
                child: CustomPaint(
                  painter: _DynamicAreaChartPainter(
                    volumes: volumes,
                    maxVolume: _bestDay > 0 ? _bestDay : 100, // Fallback if 0
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // X-Axis Labels from dynamic data
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: data
                    .map(
                      (d) => Text(
                        d['short'],
                        style: AppStyles.eyebrow.copyWith(
                          color: context.mutedFg,
                          fontSize: 10,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalRecords() {
    final isDark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERSONAL RECORDS (PRs)',
          style: AppStyles.eyebrow.copyWith(color: context.mutedFg),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : context.card,
            borderRadius: BorderRadius.circular(AppStyles.radiusLg),
            border: Border.all(color: context.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.energy.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_outlined, color: AppColors.energy, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coming Soon',
                    style: AppStyles.bodyFont.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'Track your 1RM and PRs here',
                    style: AppStyles.bodyFont.copyWith(color: context.mutedFg, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTiles() {
    return Row(
      children: [
        Expanded(
          child: _buildTile(
            icon: Icons.show_chart,
            label: 'SESSIONS',
            value: _sessions.toString(),
            accentBg: const Color(0xFFE2F8EB),
            accentIcon: AppColors.brand,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTile(
            icon: Icons.trending_up,
            label: 'MINUTES',
            value: _totalMinutes.toInt().toString(),
            accentBg: const Color(0xFFE8E2FF),
            accentIcon: AppColors.pulse,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTile(
            icon: Icons.emoji_events,
            label: 'BEST DAY',
            value: _bestDay > 0 ? NumberFormat('#,##0').format(_bestDay) : '—',
            accentBg: const Color(0xFFFFF0E5),
            accentIcon: AppColors.energy,
          ),
        ),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accentBg,
    required Color accentIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentBg,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentIcon,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(height: 16),
              Text(
                value,
                style: AppStyles.displayFont.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppStyles.eyebrow.copyWith(
                  color: context.mutedFg,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT SESSIONS',
          style: AppStyles.eyebrow.copyWith(
            color: context.mutedFg,
          ),
        ),
        const SizedBox(height: 16),

        if (_logs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppStyles.radiusLg),
              border: Border.all(color: context.border.withOpacity(0.5)),
            ),
            child: Text(
              'No sessions logged in the last 30 days.',
              textAlign: TextAlign.center,
              style: AppStyles.bodyFont.copyWith(
                color: context.mutedFg,
                fontSize: 13,
              ),
            ),
          )
        else
          Column(
            children: _logs.reversed.take(10).toList().asMap().entries.map((
              entry,
            ) {
              int idx = entry.key;
              var log = entry.value;
              DateTime performedAt = DateTime.parse(log['performed_at']);

              // Cycle through brand colors for the dots
              List<Color> accents = [
                AppColors.brand,
                AppColors.energy,
                AppColors.pulse,
                AppColors.aqua,
                AppColors.sun,
              ];
              Color dotColor = accents[idx % accents.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              log['name'],
                              style: AppStyles.bodyFont.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEE d MMM · HH:mm').format(performedAt),
                            style: AppStyles.bodyFont.copyWith(
                              color: context.mutedFg,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${NumberFormat('#,##0').format(log['volume_kg'])} kg',
                          style: AppStyles.bodyFont.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${log['duration_min']} min',
                          style: AppStyles.bodyFont.copyWith(
                            color: context.mutedFg,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

// Dynamically draws the Area Chart mimicking Recharts
class _DynamicAreaChartPainter extends CustomPainter {
  final List<double> volumes;
  final double maxVolume;

  _DynamicAreaChartPainter({required this.volumes, required this.maxVolume});

  @override
  void paint(Canvas canvas, Size size) {
    if (volumes.isEmpty || maxVolume == 0) return;

    final paint = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.brand.withOpacity(0.6),
          AppColors.aqua.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final stepX = size.width / (volumes.length - 1);

    // Start at the first data point
    path.moveTo(0, size.height - (volumes[0] / maxVolume) * size.height);

    // Draw lines to subsequent data points
    for (int i = 1; i < volumes.length; i++) {
      double x = i * stepX;
      double y = size.height - (volumes[i] / maxVolume) * size.height;
      path.lineTo(x, y);
    }

    // Create a copy of the path to draw the gradient fill underneath
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DynamicAreaChartPainter oldDelegate) {
    return oldDelegate.volumes != volumes || oldDelegate.maxVolume != maxVolume;
  }
}
