import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ExerciseCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<String> exercises;

  const ExerciseCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.exercises,
  });
}

const List<ExerciseCategory> kExerciseCategories = [
  ExerciseCategory(
    name: 'Chest',
    icon: Icons.fitness_center,
    color: AppColors.energy,
    exercises: [
      'Bench Press',
      'Incline Bench Press',
      'Decline Bench Press',
      'Dumbbell Fly',
      'Incline Dumbbell Fly',
      'Cable Fly',
      'Push Up',
      'Dip',
      'Chest Press Machine',
      'Pec Deck',
      'Close Grip Bench Press',
    ],
  ),
  ExerciseCategory(
    name: 'Back',
    icon: Icons.accessibility_new,
    color: AppColors.brand,
    exercises: [
      'Pull Up',
      'Chin Up',
      'Lat Pulldown',
      'Seated Cable Row',
      'Bent Over Barbell Row',
      'Dumbbell Row',
      'T-Bar Row',
      'Deadlift',
      'Romanian Deadlift',
      'Face Pull',
      'Straight Arm Pulldown',
      'Hyperextension',
    ],
  ),
  ExerciseCategory(
    name: 'Shoulders',
    icon: Icons.sports_gymnastics,
    color: AppColors.aqua,
    exercises: [
      'Overhead Press',
      'Dumbbell Shoulder Press',
      'Arnold Press',
      'Lateral Raise',
      'Front Raise',
      'Rear Delt Fly',
      'Upright Row',
      'Shrug',
      'Cable Lateral Raise',
      'Machine Shoulder Press',
    ],
  ),
  ExerciseCategory(
    name: 'Arms',
    icon: Icons.sports_martial_arts,
    color: AppColors.pulse,
    exercises: [
      'Barbell Curl',
      'Dumbbell Curl',
      'Hammer Curl',
      'Preacher Curl',
      'Concentration Curl',
      'Cable Curl',
      'Tricep Pushdown',
      'Skull Crusher',
      'Overhead Tricep Extension',
      'Tricep Dip',
      'Close Grip Pushup',
      'Diamond Pushup',
    ],
  ),
  ExerciseCategory(
    name: 'Legs',
    icon: Icons.directions_run,
    color: AppColors.sun,
    exercises: [
      'Squat',
      'Front Squat',
      'Leg Press',
      'Hack Squat',
      'Lunge',
      'Bulgarian Split Squat',
      'Leg Extension',
      'Leg Curl',
      'Romanian Deadlift',
      'Sumo Deadlift',
      'Calf Raise',
      'Seated Calf Raise',
      'Hip Thrust',
      'Glute Bridge',
      'Step Up',
    ],
  ),
  ExerciseCategory(
    name: 'Core',
    icon: Icons.self_improvement,
    color: AppColors.brand,
    exercises: [
      'Plank',
      'Side Plank',
      'Crunch',
      'Sit Up',
      'Leg Raise',
      'Hanging Leg Raise',
      'Russian Twist',
      'Cable Crunch',
      'Ab Rollout',
      'Mountain Climber',
      'Bicycle Crunch',
      'Dead Bug',
    ],
  ),
  ExerciseCategory(
    name: 'Cardio',
    icon: Icons.directions_bike,
    color: AppColors.energy,
    exercises: [
      'Running',
      'Treadmill',
      'Cycling',
      'Stationary Bike',
      'Jump Rope',
      'Rowing Machine',
      'Elliptical',
      'Stair Climber',
      'Swimming',
      'Box Jump',
      'Burpee',
      'Jumping Jack',
    ],
  ),
];

List<Map<String, String>> get kAllExercises => kExerciseCategories
    .expand((cat) =>
        cat.exercises.map((e) => {'name': e, 'category': cat.name}))
    .toList();
