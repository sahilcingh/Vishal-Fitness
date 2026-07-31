// Ported from APP/lib/features/train/exercises.dart — same category list,
// same exercise names, so previous-best lookups and logged rows stay
// consistent with data already recorded by the mobile app.

export type ExerciseCategoryName = "Chest" | "Back" | "Shoulders" | "Arms" | "Legs" | "Core" | "Cardio";

export type ExerciseCategoryDef = {
  name: ExerciseCategoryName;
  // Tailwind color token suffix — used as `text-${color}`, `bg-${color}`, etc.
  color: "energy" | "brand" | "aqua" | "pulse" | "sun";
  exercises: string[];
};

export const EXERCISE_CATEGORIES: ExerciseCategoryDef[] = [
  {
    name: "Chest",
    color: "energy",
    exercises: [
      "Bench Press",
      "Incline Bench Press",
      "Decline Bench Press",
      "Dumbbell Fly",
      "Incline Dumbbell Fly",
      "Cable Fly",
      "Push Up",
      "Dip",
      "Chest Press Machine",
      "Pec Deck",
      "Close Grip Bench Press",
    ],
  },
  {
    name: "Back",
    color: "brand",
    exercises: [
      "Pull Up",
      "Chin Up",
      "Lat Pulldown",
      "Seated Cable Row",
      "Bent Over Barbell Row",
      "Dumbbell Row",
      "T-Bar Row",
      "Deadlift",
      "Romanian Deadlift",
      "Face Pull",
      "Straight Arm Pulldown",
      "Hyperextension",
    ],
  },
  {
    name: "Shoulders",
    color: "aqua",
    exercises: [
      "Overhead Press",
      "Dumbbell Shoulder Press",
      "Arnold Press",
      "Lateral Raise",
      "Front Raise",
      "Rear Delt Fly",
      "Upright Row",
      "Shrug",
      "Cable Lateral Raise",
      "Machine Shoulder Press",
    ],
  },
  {
    name: "Arms",
    color: "pulse",
    exercises: [
      "Barbell Curl",
      "Dumbbell Curl",
      "Hammer Curl",
      "Preacher Curl",
      "Concentration Curl",
      "Cable Curl",
      "Tricep Pushdown",
      "Skull Crusher",
      "Overhead Tricep Extension",
      "Tricep Dip",
      "Close Grip Pushup",
      "Diamond Pushup",
    ],
  },
  {
    name: "Legs",
    color: "sun",
    exercises: [
      "Squat",
      "Front Squat",
      "Leg Press",
      "Hack Squat",
      "Lunge",
      "Bulgarian Split Squat",
      "Leg Extension",
      "Leg Curl",
      "Romanian Deadlift",
      "Sumo Deadlift",
      "Calf Raise",
      "Seated Calf Raise",
      "Hip Thrust",
      "Glute Bridge",
      "Step Up",
    ],
  },
  {
    name: "Core",
    color: "brand",
    exercises: [
      "Plank",
      "Side Plank",
      "Crunch",
      "Sit Up",
      "Leg Raise",
      "Hanging Leg Raise",
      "Russian Twist",
      "Cable Crunch",
      "Ab Rollout",
      "Mountain Climber",
      "Bicycle Crunch",
      "Dead Bug",
    ],
  },
  {
    name: "Cardio",
    color: "energy",
    exercises: [
      "Running",
      "Treadmill",
      "Cycling",
      "Stationary Bike",
      "Jump Rope",
      "Rowing Machine",
      "Elliptical",
      "Stair Climber",
      "Swimming",
      "Box Jump",
      "Burpee",
      "Jumping Jack",
    ],
  },
];

export type ExerciseOption = { name: string; category: ExerciseCategoryName };

export const ALL_EXERCISES: ExerciseOption[] = EXERCISE_CATEGORIES.flatMap((cat) =>
  cat.exercises.map((name) => ({ name, category: cat.name })),
);

export function categoryColor(category: string): ExerciseCategoryDef["color"] {
  return EXERCISE_CATEGORIES.find((c) => c.name === category)?.color ?? "brand";
}

// Mirrors _categoryGradient() in train_screen.dart.
export function categoryGradientClass(category: string | null | undefined): string {
  switch ((category ?? "").toLowerCase()) {
    case "chest":
    case "cardio":
      return "from-energy to-sun";
    case "back":
    case "core":
      return "from-brand to-aqua";
    case "shoulders":
    case "arms":
      return "from-aqua to-pulse";
    default:
      return "from-sun to-energy";
  }
}
