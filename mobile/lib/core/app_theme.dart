// Medical palette (Section 8): blue / white / soft green, high contrast,
// large touch targets. Light + dark variants.
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1E6FB8);      // medical blue
  static const primaryDark = Color(0xFF144D80);
  static const accent = Color(0xFF6BBF8A);       // soft green
  static const surface = Color(0xFFF7FAFC);
  static const critical = Color(0xFFD64545);
  static const warning = Color(0xFFE8A33D);
  static const info = Color(0xFF4A90D9);

  // Role accents for the bottom-nav shell (Section 1/13): a persistent,
  // always-visible cue for which of the three roles you're in. Layered only
  // on the shell's own nav indicator + Theme.primary — alert severities,
  // status colors, etc. above stay global and never change meaning by role.
  static const parentAccent = accent;              // soft green — warm, reassuring
  static const doctorAccent = primary;             // medical blue — clinical default
  static const adminAccent = Color(0xFF6B5B95);    // graphite indigo — systems/ops
}

class AppTheme {
  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      secondary: AppColors.accent,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? AppColors.surface : null,
      // Large touch targets everywhere.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static Color severityColor(String severity) => switch (severity) {
        'critical' => AppColors.critical,
        'warning' => AppColors.warning,
        _ => AppColors.info,
      };
}
