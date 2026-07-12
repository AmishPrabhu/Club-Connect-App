import 'package:flutter/material.dart';

class AppTheme {
  static const Color navy = Color(0xFF002147);
  static const Color surface = Color(0xFFF4F7FB);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF162033);
  static const Color muted = Color(0xFF6E7A8A);
  static const Color cyan = Color(0xFF38BDF8);
  static const Color blue = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);

  static const Color darkBackground = Color(0xFF080808);
  static const Color darkSurface    = Color(0xFF131313);
  static const Color darkElevated   = Color(0xFF1C1C1C);
  static const Color darkText       = Color(0xFFFFFFFF);
  static const Color darkMuted      = Color(0xFF7A7A7A);
  static const Color darkSubtle     = Color(0xFF444444);
  static const Color darkAccent     = Color(0xFF818CF8);
  static const Color darkBorder     = Color(0xFF242424);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: blue,
        surface: surface,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: text,
      ),
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: text,
          height: 1.1,
        ),
        headlineMedium: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: text,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: text,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: text, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 14, color: text, height: 1.5),
        bodySmall: const TextStyle(fontSize: 12, color: muted),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.blueGrey.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: blue, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: text,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: text,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: muted,
        indicatorColor: text,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      dividerColor: const Color(0xFFE2E8F0),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkAccent,
        primary: darkAccent,
        secondary: cyan,
        surface: darkSurface,
        brightness: Brightness.dark,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: darkText,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: darkText,
        displayColor: darkText,
      ).copyWith(
        bodySmall: const TextStyle(fontSize: 12, color: darkMuted),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkElevated,
        hintStyle: const TextStyle(color: darkMuted),
        prefixIconColor: darkMuted,
        labelStyle: const TextStyle(color: darkMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkAccent, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: darkElevated,
        selectedColor: Colors.white,
        disabledColor: darkSurface,
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(
          color: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return darkBackground;
            }
            return darkText;
          }),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(color: darkBackground, fontSize: 13, fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: darkMuted,
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      dividerColor: darkBorder,
    );
  }

  // ── Context-aware colour helpers ──────────────────────────────────────────

  /// Primary text colour that adapts to light/dark mode.
  static Color textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  /// Secondary/muted text colour that adapts to light/dark mode.
  static Color mutedColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Card/container background colour that adapts to light/dark mode.
  static Color cardBg(BuildContext context) =>
      Theme.of(context).cardColor;

  /// Scaffold/page background colour that adapts to light/dark mode.
  static Color surfaceBg(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  /// True when the current theme is dark mode.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Primary accent color that adapts to light/dark mode.
  static Color accent(BuildContext context) =>
      isDark(context) ? darkAccent : blue;

  /// Navy text color that adapts to light/dark mode.
  static Color navyColor(BuildContext context) =>
      isDark(context) ? darkText : navy;

  /// Elevated surface (inputs, nested cards) — darker than card in dark mode.
  static Color elevatedBg(BuildContext context) =>
      isDark(context) ? darkElevated : Colors.white;

  /// Unified border color across all widgets.
  static Color borderColor(BuildContext context) =>
      isDark(context) ? darkBorder : const Color(0xFFE2E8F0);
}
