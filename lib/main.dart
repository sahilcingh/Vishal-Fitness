import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/main_layout.dart';
import 'core/widgets/connectivity_overlay.dart';

final supabase = Supabase.instance.client;

// Global theme notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://inimbyivkmwgqnsbkmqg.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImluaW1ieWl2a213Z3Fuc2JrbXFnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwMTU4MTksImV4cCI6MjA5MjU5MTgxOX0.R6TpilbhIVir7fD7hF39SR317NG9B_7SumGVpr0ezps',
  );

  runApp(const PulseGymApp());
}

class PulseGymApp extends StatelessWidget {
  const PulseGymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Vishal Fitness',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return ConnectivityOverlay(
              child: Stack(
                children: [
                  if (child != null) child,
                  const GlobalThemeButton(),
                ],
              ),
            );
          },
          home: const AuthGate(),
        );
      },
    );
  }
}

/// A global floating button that acts like Assistive Touch
class GlobalThemeButton extends StatefulWidget {
  const GlobalThemeButton({super.key});

  @override
  State<GlobalThemeButton> createState() => _GlobalThemeButtonState();
}

class _GlobalThemeButtonState extends State<GlobalThemeButton> {
  Offset? position;
  double? lastWidth;

  @override
  Widget build(BuildContext context) {
    // If MediaQuery is not yet available with a valid size, don't build the button
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null || size.width == 0) return const SizedBox.shrink();

    // Initialize to right edge on first valid build (added 16px padding)
    if (position == null) {
      position = Offset(size.width - 16.0 - 48.0, size.height - 120.0);
      lastWidth = size.width;
    }

    // If screen width changed (due to font/display scaling or rotation), re-snap to the edge
    if (lastWidth != null && lastWidth != size.width) {
      double dx = position!.dx < lastWidth! / 2 ? 16.0 : size.width - 16.0 - 48.0;
      position = Offset(dx, position!.dy);
      lastWidth = size.width;
    }

    // Safeguard: clamp position to prevent it from getting stuck off-screen
    double clampedX = position!.dx.clamp(16.0, size.width - 16.0 - 48.0);
    double clampedY = position!.dy.clamp(16.0, size.height - 16.0 - 48.0);
    position = Offset(clampedX, clampedY);

    return Positioned(
      left: position!.dx,
      top: position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // Apply delta freely in all directions
            position = position! + details.delta;
          });
        },
        onPanEnd: (_) {
          setState(() {
            // Snap to the nearest edge (left or right)
            double dx = position!.dx < size.width / 2 ? 16.0 : size.width - 16.0 - 48.0;
            position = Offset(dx, position!.dy);
          });
        },
        onTap: () {
          final isDark = themeNotifier.value == ThemeMode.dark;
          themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
        },
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (context, mode, _) {
            final isDark = mode == ThemeMode.dark;
            return Material(
              color: Colors.transparent,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.card,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: context.border,
                  ),
                ),
                child: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode,
                  color: isDark ? AppColors.sun : AppColors.pulse,
                  size: 24,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The AuthGate acts as a traffic controller for your app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to auth changes continuously in real-time
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // By checking the currentSession synchronously, we instantly know if the user
        // was already logged in from a previous session (handled automatically by Supabase.initialize)
        final session = supabase.auth.currentSession;

        if (session != null) {
          // User is verified and logged in. Send them directly to the Dashboard.
          return const MainLayout();
        } else {
          // User is not logged in. Send them to the Welcome/Onboarding screen.
          return const WelcomeScreen();
        }
      },
    );
  }
}
