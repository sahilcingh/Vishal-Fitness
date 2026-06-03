import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../main.dart';
import 'exercises.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _ActiveSet {
  double? weightKg;
  int? reps;
  bool isDone;
  bool isWarmup;

  _ActiveSet({this.weightKg, this.reps, this.isDone = false, this.isWarmup = false});

  _ActiveSet copyWith({double? weightKg, int? reps, bool? isDone, bool? isWarmup}) =>
      _ActiveSet(
        weightKg: weightKg ?? this.weightKg,
        reps: reps ?? this.reps,
        isDone: isDone ?? this.isDone,
        isWarmup: isWarmup ?? this.isWarmup,
      );
}

class _ActiveExercise {
  final String name;
  final String category;
  List<_ActiveSet> sets;
  String? previousBest; // "80kg × 5" style

  _ActiveExercise({
    required this.name,
    required this.category,
    List<_ActiveSet>? sets,
    this.previousBest,
  }) : sets = sets ?? [_ActiveSet()];
}

// ── TrainScreen ───────────────────────────────────────────────────────────────

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  bool _isClassesTab = true;

  // Classes data
  List<Map<String, dynamic>> _classes = [];
  bool _isLoadingClasses = true;

  // Workout tracker state
  bool _isWorkoutActive = false;
  String _workoutName = 'Workout';
  DateTime? _workoutStart;
  final List<_ActiveExercise> _exercises = [];
  Timer? _timer;
  int _elapsedSeconds = 0;

  // Recent sessions
  List<Map<String, dynamic>> _recentSessions = [];
  bool _isLoadingSessions = true;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _fetchRecentSessions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Data fetching ───────────────────────────────────────────────────────────

  Future<void> _fetchClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final now = DateTime.now();
      final response = await supabase
          .from('classes')
          .select('id, title, start_time, duration_min, category, instructor, capacity, intensity')
          .gt('start_time', now.toIso8601String())
          .order('start_time', ascending: true)
          .limit(10);
      if (mounted) {
        setState(() {
          _classes = List<Map<String, dynamic>>.from(response);
          _isLoadingClasses = false;
        });
      }
    } catch (_) {
      try {
        final now = DateTime.now();
        final response = await supabase
            .from('classes')
            .select('id, title, start_time, duration_min, category, instructor, capacity')
            .gt('start_time', now.toIso8601String())
            .order('start_time', ascending: true)
            .limit(10);
        if (mounted) {
          setState(() {
            _classes = List<Map<String, dynamic>>.from(response);
            _isLoadingClasses = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching classes: $e');
        if (mounted) setState(() => _isLoadingClasses = false);
      }
    }
  }

  Future<void> _fetchRecentSessions() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase
          .from('workout_sessions')
          .select('id, name, started_at, finished_at, duration_seconds')
          .eq('user_id', user.id)
          .not('finished_at', 'is', null)
          .order('started_at', ascending: false)
          .limit(5);
      if (mounted) {
        setState(() {
          _recentSessions = List<Map<String, dynamic>>.from(res);
          _isLoadingSessions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  Future<void> _fetchPreviousBest(String exerciseName) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase
          .from('workout_sets')
          .select('weight_kg, reps, workout_sessions!inner(user_id)')
          .eq('exercise_name', exerciseName)
          .eq('workout_sessions.user_id', user.id)
          .eq('is_warmup', false)
          .not('weight_kg', 'is', null)
          .not('reps', 'is', null)
          .order('weight_kg', ascending: false)
          .limit(1);
      if (res.isNotEmpty && mounted) {
        final row = res.first as Map<String, dynamic>;
        final w = row['weight_kg'];
        final r = row['reps'];
        if (w != null && r != null) {
          final best = '${(w as num).toStringAsFixed(w % 1 == 0 ? 0 : 1)} kg × $r';
          setState(() {
            final idx = _exercises.indexWhere((e) => e.name == exerciseName);
            if (idx != -1) _exercises[idx].previousBest = best;
          });
        }
      }
    } catch (_) {}
  }

  // ── Workout control ─────────────────────────────────────────────────────────

  void _startWorkout() {
    setState(() {
      _isWorkoutActive = true;
      _workoutName = 'Workout';
      _workoutStart = DateTime.now();
      _elapsedSeconds = 0;
      _exercises.clear();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _cancelWorkout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Discard Workout?',
            style: AppStyles.displayFont.copyWith(fontSize: 20, color: ctx.fg)),
        content: Text('All progress will be lost.',
            style: AppStyles.bodyFont.copyWith(color: ctx.mutedFg)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Going', style: TextStyle(color: AppColors.brand)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _timer?.cancel();
              setState(() {
                _isWorkoutActive = false;
                _exercises.clear();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishWorkout() async {
    final doneSets = _exercises
        .expand((e) => e.sets)
        .where((s) => s.isDone)
        .length;

    if (doneSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mark at least one set as done before finishing.'),
          backgroundColor: AppColors.energy,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _timer?.cancel();

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final duration = now.difference(_workoutStart!).inSeconds;

    try {
      // Save session
      final sessionRes = await supabase.from('workout_sessions').insert({
        'user_id': user.id,
        'name': _workoutName,
        'started_at': _workoutStart!.toIso8601String(),
        'finished_at': now.toIso8601String(),
        'duration_seconds': duration,
      }).select('id').single();

      final sessionId = sessionRes['id'] as String;

      // Save all done sets
      final setsToInsert = <Map<String, dynamic>>[];
      for (final exercise in _exercises) {
        for (final set in exercise.sets.where((s) => s.isDone)) {
          setsToInsert.add({
            'session_id': sessionId,
            'exercise_name': exercise.name,
            'set_number': exercise.sets.indexOf(set) + 1,
            'weight_kg': set.weightKg,
            'reps': set.reps,
            'is_warmup': set.isWarmup,
          });
        }
      }
      if (setsToInsert.isNotEmpty) {
        await supabase.from('workout_sets').insert(setsToInsert);
      }

      // Also update workout_logs for backward compatibility with Progress screen
      final totalVolume = setsToInsert.fold<double>(
        0,
        (sum, s) =>
            sum + ((s['weight_kg'] as num? ?? 0) * (s['reps'] as int? ?? 0)),
      );
      await supabase.from('workout_logs').insert({
        'user_id': user.id,
        'name': _workoutName,
        'performed_at': _workoutStart!.toIso8601String(),
        'volume_kg': totalVolume,
        'duration_min': (duration / 60).round(),
      });

      if (mounted) {
        setState(() {
          _isWorkoutActive = false;
          _exercises.clear();
        });
        await _fetchRecentSessions();

        _showWorkoutSummary(
          name: _workoutName,
          duration: duration,
          exerciseCount: _exercises.length,
          setCount: doneSets,
          volume: totalVolume,
        );
      }
    } catch (e) {
      debugPrint('Error saving workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save workout: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showWorkoutSummary({
    required String name,
    required int duration,
    required int exerciseCount,
    required int setCount,
    required double volume,
  }) {
    final mins = duration ~/ 60;
    final secs = duration % 60;
    final fmt = NumberFormat('#,##0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check, color: AppColors.brand),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Workout Done!',
                  style: AppStyles.displayFont
                      .copyWith(fontSize: 20, fontWeight: FontWeight.bold, color: ctx.fg)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name,
                style: AppStyles.bodyFont
                    .copyWith(fontSize: 14, color: ctx.mutedFg)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryStat(ctx, '⏱', '$mins:${secs.toString().padLeft(2, '0')}', 'Duration'),
                _summaryStat(ctx, '🏋️', '$setCount', 'Sets'),
                _summaryStat(ctx, '⚖️', '${fmt.format(volume.round())} kg', 'Volume'),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Nice!'),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(BuildContext context, String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value,
            style: AppStyles.displayFont.copyWith(
                fontSize: 18, fontWeight: FontWeight.bold, color: context.fg)),
        Text(label,
            style:
                AppStyles.eyebrow.copyWith(color: context.mutedFg, fontSize: 9)),
      ],
    );
  }

  // ── Exercise management ─────────────────────────────────────────────────────

  void _showExercisePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExercisePickerSheet(
        onPicked: (name, category) {
          final exercise = _ActiveExercise(name: name, category: category);
          setState(() => _exercises.add(exercise));
          _fetchPreviousBest(name);
        },
      ),
    );
  }

  void _renameWorkout() {
    final ctrl = TextEditingController(text: _workoutName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Workout Name',
            style: AppStyles.displayFont
                .copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: ctx.fg)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppStyles.bodyFont.copyWith(color: ctx.fg),
          decoration: InputDecoration(
            filled: true,
            fillColor: ctx.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.brand),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: ctx.mutedFg))),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _workoutName = ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _formatTimer(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatClassTime(String? isoTime) {
    if (isoTime == null) return '—';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return DateFormat('EEE, d MMM · h:mm a').format(dt);
    } catch (_) {
      return isoTime;
    }
  }

  LinearGradient _categoryGradient(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'chest':
      case 'cardio':
        return AppColors.gradientEnergy;
      case 'back':
      case 'core':
        return AppColors.gradientBrand;
      case 'shoulders':
      case 'arms':
        return AppColors.gradientCool;
      default:
        return AppColors.gradientSunrise;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Tab toggle — always visible
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppStyles.containerPadding, 16, AppStyles.containerPadding, 0),
            child: _buildTabToggle(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isClassesTab
                  ? _buildClassesContent()
                  : _buildWorkoutsContent(),
            ),
          ),
        ],
      ),
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
          Expanded(child: _buildTab('Classes', true)),
          Expanded(child: _buildTab('Workouts', false)),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isClasses) {
    final isActive = _isClassesTab == isClasses;
    return GestureDetector(
      onTap: () => setState(() => _isClassesTab = isClasses),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.gradientBrand : null,
          borderRadius: BorderRadius.circular(AppStyles.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppStyles.bodyFont.copyWith(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? context.primaryFg : context.mutedFg,
          ),
        ),
      ),
    );
  }

  // ── Classes tab ─────────────────────────────────────────────────────────────

  Widget _buildClassesContent() {
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _fetchClasses,
      child: SingleChildScrollView(
        key: const ValueKey('classes'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppStyles.containerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingClasses)
              _buildSkeleton()
            else if (_classes.isEmpty)
              _buildEmptyState(
                icon: Icons.event_available_outlined,
                title: 'No upcoming classes',
                subtitle:
                    'Check back later. New classes are added by the gym admin regularly.',
                color: AppColors.energy,
              )
            else ...[
              Text('UPCOMING',
                  style: AppStyles.eyebrow.copyWith(color: context.mutedFg)),
              const SizedBox(height: 16),
              ..._classes.asMap().entries.map(
                    (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildClassCard(entry.value)
                      .animate(delay: (entry.key * 60).ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, duration: 300.ms),
                ),
              ),
            ],
            const SizedBox(height: 48),
            _buildFooter(context),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: ShimmerBox(height: 100, radius: 16),
        ),
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls) {
    final title = cls['title'] as String? ?? 'Class';
    final category = cls['category'] as String? ?? '';
    final instructor = cls['instructor'] as String?;
    final durationMin = cls['duration_min'] as int? ?? 0;
    final capacity = cls['capacity'] as int?;
    final intensity = cls['intensity'] as String?;
    final startTime = cls['start_time'] as String?;
    final gradient = _categoryGradient(category);

    String timeLabel = '—';
    if (startTime != null) {
      try {
        timeLabel =
            DateFormat('h:mm').format(DateTime.parse(startTime).toLocal());
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _showReserveDialog(cls),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppStyles.radiusLg),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppStyles.radiusLg)),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(timeLabel,
                        style: AppStyles.displayFont.copyWith(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('${durationMin}MIN',
                        style: AppStyles.eyebrow
                            .copyWith(color: context.mutedFg, fontSize: 10)),
                  ],
                ),
              ),
              Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  color: context.border.withValues(alpha: 0.6)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: AppStyles.bodyFont.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (category.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  gradient: gradient,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(category.toUpperCase(),
                                  style: AppStyles.eyebrow.copyWith(
                                      color: Colors.white, fontSize: 8)),
                            ),
                          ],
                        ],
                      ),
                      if (instructor != null && instructor.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(instructor,
                            style: AppStyles.bodyFont.copyWith(
                                color: context.mutedFg, fontSize: 12)),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (capacity != null) ...[
                                  Icon(Icons.people_outline,
                                      size: 13, color: context.mutedFg),
                                  const SizedBox(width: 4),
                                  Text('$capacity spots',
                                      style: AppStyles.bodyFont.copyWith(
                                          color: context.mutedFg,
                                          fontSize: 12)),
                                  const SizedBox(width: 10),
                                ],
                                if (intensity != null &&
                                    intensity.isNotEmpty) ...[
                                  Icon(Icons.bolt,
                                      size: 13, color: context.mutedFg),
                                  const SizedBox(width: 3),
                                  Text(intensity,
                                      style: AppStyles.bodyFont.copyWith(
                                          color: context.mutedFg,
                                          fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showReserveDialog(cls),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                  gradient: gradient,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add,
                                      size: 13, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('Reserve',
                                      style: AppStyles.bodyFont.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white)),
                                ],
                              ),
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
      ),
    );
  }

  void _showReserveDialog(Map<String, dynamic> cls) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reserve a Spot',
            style: AppStyles.displayFont
                .copyWith(fontSize: 20, fontWeight: FontWeight.bold, color: ctx.fg)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cls['title'] as String? ?? 'Class',
                style: AppStyles.bodyFont.copyWith(
                    fontSize: 15, fontWeight: FontWeight.w700, color: ctx.fg)),
            const SizedBox(height: 4),
            Text(_formatClassTime(cls['start_time'] as String?),
                style:
                    AppStyles.bodyFont.copyWith(color: ctx.mutedFg, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.brand, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Visit the front desk or contact staff to reserve your spot.',
                      style: AppStyles.bodyFont.copyWith(
                          color: AppColors.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: TextStyle(color: ctx.mutedFg))),
        ],
      ),
    );
  }

  // ── Workouts tab ────────────────────────────────────────────────────────────

  Widget _buildWorkoutsContent() {
    return _isWorkoutActive
        ? _buildActiveWorkout()
        : _buildWorkoutHome();
  }

  Widget _buildWorkoutHome() {
    return SingleChildScrollView(
      key: const ValueKey('workout_home'),
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Start workout CTA
          GestureDetector(
            onTap: _startWorkout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.gradientBrand,
                borderRadius: BorderRadius.circular(AppStyles.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text('Start Workout',
                      style: AppStyles.displayFont.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Tap to begin logging your session',
                      style: AppStyles.bodyFont.copyWith(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Recent workouts
          Text('RECENT WORKOUTS',
              style: AppStyles.eyebrow.copyWith(color: context.mutedFg)),
          const SizedBox(height: 12),

          if (_isLoadingSessions)
            ...List.generate(
                3,
                (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: ShimmerBox(height: 72, radius: 14)))
          else if (_recentSessions.isEmpty)
            _buildEmptyState(
              icon: Icons.history_outlined,
              title: 'No workouts yet',
              subtitle: 'Your completed workouts will appear here.',
              color: AppColors.brand,
            )
          else
            ..._recentSessions.asMap().entries.map(
                  (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSessionCard(e.value)
                    .animate(delay: (e.key * 50).ms)
                    .fadeIn(duration: 250.ms),
              ),
            ),
          const SizedBox(height: 48),
          _buildFooter(context),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final name = session['name'] as String? ?? 'Workout';
    final startedAt = session['started_at'] as String?;
    final durationSec = session['duration_seconds'] as int? ?? 0;
    final mins = durationSec ~/ 60;
    DateTime? dt;
    if (startedAt != null) dt = DateTime.tryParse(startedAt)?.toLocal();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusMd),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center, color: AppColors.brand, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppStyles.bodyFont.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.fg)),
                const SizedBox(height: 2),
                Text(
                  dt != null
                      ? DateFormat('EEE, d MMM').format(dt)
                      : '—',
                  style: AppStyles.bodyFont
                      .copyWith(color: context.mutedFg, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            mins > 0 ? '${mins}m' : '—',
            style: AppStyles.numTabular.copyWith(
                color: context.mutedFg,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Active workout ──────────────────────────────────────────────────────────

  Widget _buildActiveWorkout() {
    return Column(
      key: const ValueKey('active_workout'),
      children: [
        // Header bar
        _buildWorkoutHeader(),
        // Exercise list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppStyles.containerPadding),
            children: [
              const SizedBox(height: 12),
              ..._exercises.asMap().entries.map(
                    (entry) => _buildExerciseCard(entry.key, entry.value),
              ),
              const SizedBox(height: 16),
              // Add exercise button
              GestureDetector(
                onTap: _showExercisePicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius:
                        BorderRadius.circular(AppStyles.radiusMd),
                    border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: AppColors.brand, size: 18),
                      const SizedBox(width: 8),
                      Text('Add Exercise',
                          style: AppStyles.bodyFont.copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
        // Finish button
        _buildFinishBar(),
      ],
    );
  }

  Widget _buildWorkoutHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppStyles.containerPadding, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(bottom: BorderSide(color: context.border.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _renameWorkout,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _workoutName,
                    style: AppStyles.displayFont.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit_outlined, size: 14, color: context.mutedFg),
              ],
            ),
          ),
          const Spacer(),
          // Timer
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 14, color: AppColors.brand),
                const SizedBox(width: 4),
                Text(
                  _formatTimer(_elapsedSeconds),
                  style: AppStyles.numTabular.copyWith(
                      color: AppColors.brand,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _cancelWorkout,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.border)),
              child:
                  Icon(Icons.close, size: 16, color: context.mutedFg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(int exerciseIdx, _ActiveExercise exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercise header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: _categoryGradient(exercise.category),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name,
                          style: AppStyles.bodyFont.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: context.fg)),
                      if (exercise.previousBest != null)
                        Text('Previous best: ${exercise.previousBest}',
                            style: AppStyles.eyebrow.copyWith(
                                color: AppColors.brand, fontSize: 9)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _exercises.removeAt(exerciseIdx)),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: context.mutedFg),
                ),
              ],
            ),
          ),

          // Set header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                    width: 30,
                    child: Text('SET',
                        style: AppStyles.eyebrow
                            .copyWith(color: context.mutedFg, fontSize: 9))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('KG',
                        style: AppStyles.eyebrow.copyWith(
                            color: context.mutedFg, fontSize: 9))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('REPS',
                        style: AppStyles.eyebrow.copyWith(
                            color: context.mutedFg, fontSize: 9))),
                const SizedBox(width: 8),
                const SizedBox(width: 36),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Sets
          ...exercise.sets.asMap().entries.map(
                (e) => _buildSetRow(exerciseIdx, e.key, e.value),
          ),

          // Add set
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // Pre-fill with last set's values
                  final last = exercise.sets.isNotEmpty
                      ? exercise.sets.last
                      : null;
                  exercise.sets.add(_ActiveSet(
                      weightKg: last?.weightKg, reps: last?.reps));
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.add, size: 14, color: AppColors.brand),
                  const SizedBox(width: 4),
                  Text('Add Set',
                      style: AppStyles.bodyFont.copyWith(
                          color: AppColors.brand,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(int exerciseIdx, int setIdx, _ActiveSet set) {
    final exercise = _exercises[exerciseIdx];
    final isDone = set.isDone;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isDone
            ? AppColors.brand.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Set number / warmup badge
          GestureDetector(
            onTap: () => setState(() =>
                exercise.sets[setIdx] =
                    set.copyWith(isWarmup: !set.isWarmup)),
            child: SizedBox(
              width: 30,
              child: Center(
                child: set.isWarmup
                    ? Text('W',
                        style: AppStyles.eyebrow.copyWith(
                            color: AppColors.aqua, fontWeight: FontWeight.w900))
                    : Text('${setIdx + 1}',
                        style: AppStyles.numTabular.copyWith(
                            color: context.mutedFg,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Weight input
          Expanded(
            child: _setInput(
              hint: '0',
              value: set.weightKg?.toString() ?? '',
              onChanged: (v) {
                final d = double.tryParse(v);
                setState(() =>
                    exercise.sets[setIdx] = set.copyWith(weightKg: d));
              },
              isDone: isDone,
            ),
          ),
          const SizedBox(width: 8),

          // Reps input
          Expanded(
            child: _setInput(
              hint: '0',
              value: set.reps?.toString() ?? '',
              onChanged: (v) {
                final i = int.tryParse(v);
                setState(
                    () => exercise.sets[setIdx] = set.copyWith(reps: i));
              },
              isDone: isDone,
              isInteger: true,
            ),
          ),
          const SizedBox(width: 8),

          // Done checkbox
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() =>
                  exercise.sets[setIdx] = set.copyWith(isDone: !isDone));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone ? AppColors.brand : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDone ? AppColors.brand : context.border,
                    width: 1.5),
              ),
              child: isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _setInput({
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    required bool isDone,
    bool isInteger = false,
  }) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDone ? AppColors.brand.withValues(alpha: 0.10) : context.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDone
                ? AppColors.brand.withValues(alpha: 0.3)
                : context.border.withValues(alpha: 0.6)),
      ),
      child: TextField(
        controller: TextEditingController(text: value)
          ..selection =
              TextSelection.collapsed(offset: value.length),
        keyboardType: isInteger
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          if (isInteger) FilteringTextInputFormatter.digitsOnly
          else FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        onChanged: onChanged,
        textAlign: TextAlign.center,
        style: AppStyles.numTabular.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDone ? AppColors.brand : context.fg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppStyles.numTabular.copyWith(color: context.mutedFg, fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildFinishBar() {
    final doneSets =
        _exercises.expand((e) => e.sets).where((s) => s.isDone).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppStyles.containerPadding, 12, AppStyles.containerPadding, 24),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(top: BorderSide(color: context.border.withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$doneSets set${doneSets == 1 ? '' : 's'} done',
                  style: AppStyles.bodyFont.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.fg),
                ),
                Text(
                  _formatTimer(_elapsedSeconds),
                  style: AppStyles.numTabular.copyWith(
                      color: AppColors.brand,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _finishWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppStyles.radiusMd)),
                elevation: 0,
              ),
              child: Text('Finish Workout',
                  style: AppStyles.bodyFont.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared ──────────────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppStyles.radiusLg),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: AppStyles.bodyFont.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.fg)),
          const SizedBox(height: 6),
          Text(subtitle,
              style:
                  AppStyles.bodyFont.copyWith(fontSize: 13, color: context.mutedFg),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () async {
          final Uri url = Uri.parse('https://qyroxis.com');
          if (!await launchUrl(url)) debugPrint('Could not launch $url');
        },
        child: RichText(
          text: TextSpan(
            style: AppStyles.eyebrow.copyWith(
              color: context.fg.withValues(alpha: 0.5),
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
            children: const [
              TextSpan(text: 'APP MADE BY '),
              TextSpan(
                text: 'QYROXIS',
                style: TextStyle(
                    color: AppColors.brand,
                    decoration: TextDecoration.underline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Exercise Picker Sheet ─────────────────────────────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  final void Function(String name, String category) onPicked;
  const _ExercisePickerSheet({required this.onPicked});

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filtered {
    final all = _selectedCategory != null
        ? kExerciseCategories
            .firstWhere((c) => c.name == _selectedCategory)
            .exercises
            .map((e) => {'name': e, 'category': _selectedCategory!})
            .toList()
        : kAllExercises;

    if (_query.isEmpty) return all;
    return all
        .where((e) =>
            e['name']!.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Title + search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Exercise',
                    style: AppStyles.displayFont.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.fg)),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppStyles.bodyFont.copyWith(color: context.fg),
                  decoration: InputDecoration(
                    hintText: 'Search exercises…',
                    hintStyle:
                        AppStyles.bodyFont.copyWith(color: context.mutedFg),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.brand),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.brand)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category chips
          if (_query.isEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _categoryChip('All', null),
                  ...kExerciseCategories.map((c) =>
                      _categoryChip(c.name, c.name)),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Exercise list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: _filtered.length,
              separatorBuilder: (_, i) =>
                  Divider(height: 1, color: context.border.withValues(alpha: 0.3)),
              itemBuilder: (_, i) {
                final ex = _filtered[i];
                final name = ex['name']!;
                final cat = ex['category']!;
                final catData = kExerciseCategories
                    .firstWhere((c) => c.name == cat,
                        orElse: () => kExerciseCategories.first);
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: catData.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(catData.icon,
                        color: catData.color, size: 16),
                  ),
                  title: Text(name,
                      style: AppStyles.bodyFont.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.fg)),
                  subtitle: Text(cat,
                      style: AppStyles.eyebrow.copyWith(
                          color: context.mutedFg, fontSize: 9)),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: AppColors.brand, size: 20),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onPicked(name, cat);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppColors.brand : context.border),
        ),
        child: Text(label,
            style: AppStyles.bodyFont.copyWith(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.black : context.fg)),
      ),
    );
  }
}
