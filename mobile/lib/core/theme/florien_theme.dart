import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:florien/core/firebase/user_profile_service.dart';
import 'package:florien/core/storage/settings_storage.dart';

/// Clear Focus — crisp neutrals, calm indigo and restrained semantic colour.
///
/// Colour is reserved for meaning and primary actions. The neutral surfaces keep
/// long planning sessions calm while the indigo remains recognisable in both
/// light and dark modes.
class FlorienColors {
  static const primary = Color(0xFF4F52B2);
  static const primaryLight = Color(0xFF7C7FE0);
  static const accent = Color(0xFFE06F4F);
  static const success = Color(0xFF059669);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);

  // Light semantic defaults (prefer [FlorienPalette] via context in widgets).
  static const background = Color(0xFFF8F9FB);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  static const taskColors = [
    '#4F52B2',
    '#6366F1',
    '#059669',
    '#0891B2',
    '#D97706',
    '#DC2626',
    '#9333EA',
    '#DB2777',
    '#65A30D',
    '#0D9488',
    '#EA580C',
    '#7C3AED',
  ];

  static Color fromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

abstract final class FlorienSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class FlorienRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

@immutable
class FlorienPalette extends ThemeExtension<FlorienPalette> {
  const FlorienPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.primaryMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color primaryMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color error;

  static const light = FlorienPalette(
    background: Color(0xFFF8F9FB),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F3F6),
    primaryMuted: Color(0xFFEEF0FF),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    error: Color(0xFFDC2626),
  );

  static const dark = FlorienPalette(
    background: Color(0xFF0F1117),
    surface: Color(0xFF1A1D27),
    surfaceMuted: Color(0xFF252A36),
    primaryMuted: Color(0xFF2A2D5C),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9CA3AF),
    border: Color(0xFF2D3340),
    error: Color(0xFFF87171),
  );

  @override
  FlorienPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? primaryMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? error,
  }) {
    return FlorienPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      error: error ?? this.error,
    );
  }

  @override
  FlorienPalette lerp(FlorienPalette? other, double t) {
    if (other == null) return this;
    return FlorienPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension FlorienPaletteContext on BuildContext {
  FlorienPalette get palette =>
      Theme.of(this).extension<FlorienPalette>() ?? FlorienPalette.light;
}

enum AppThemePreference { system, light, dark }

final appThemeModeProvider =
    AsyncNotifierProvider<AppThemeModeNotifier, ThemeMode>(
      AppThemeModeNotifier.new,
    );

class AppThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    return ref.read(settingsStorageProvider).getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(settingsStorageProvider).setThemeMode(mode);
    state = AsyncData(mode);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final theme = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      try {
        await ref.read(userProfileServiceProvider).patchSettings(uid, {
          'themeMode': theme,
        });
      } catch (_) {}
    }
  }
}

ThemeMode themeModeFromPreference(AppThemePreference pref) => switch (pref) {
  AppThemePreference.light => ThemeMode.light,
  AppThemePreference.dark => ThemeMode.dark,
  AppThemePreference.system => ThemeMode.system,
};

AppThemePreference preferenceFromThemeMode(ThemeMode mode) => switch (mode) {
  ThemeMode.light => AppThemePreference.light,
  ThemeMode.dark => AppThemePreference.dark,
  ThemeMode.system => AppThemePreference.system,
};

class FlorienTheme {
  static ThemeData get light => _build(Brightness.light, FlorienPalette.light);

  static ThemeData get dark => _build(Brightness.dark, FlorienPalette.dark);

  static ThemeData _build(Brightness brightness, FlorienPalette palette) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFFAEB0FF) : FlorienColors.primary;
    final onPrimary = isDark ? const Color(0xFF0F1117) : Colors.white;
    final baseTextTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [palette],
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: primary,
            brightness: brightness,
            surface: palette.surface,
            primary: primary,
            secondary: FlorienColors.accent,
            error: palette.error,
            onSurface: palette.textPrimary,
          ).copyWith(
            onPrimary: onPrimary,
            primaryContainer: palette.primaryMuted,
            onPrimaryContainer: isDark
                ? const Color(0xFFD9DAFF)
                : FlorienColors.primary,
            surfaceContainer: palette.surfaceMuted,
            surfaceContainerHighest: palette.surfaceMuted,
            outline: palette.border,
            outlineVariant: palette.border,
          ),
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.border,
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.45),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(FlorienRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.xl),
        ),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 14,
          color: palette.textPrimary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        highlightElevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceMuted,
        hintStyle: TextStyle(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: palette.border,
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size(48, 52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FlorienRadius.md),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(48, 52),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FlorienRadius.md),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: palette.surface,
        iconColor: palette.textPrimary,
        textColor: palette.textPrimary,
        minTileHeight: 56,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border),
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.primaryMuted,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.sm),
        ),
        labelStyle: TextStyle(color: palette.textPrimary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? onPrimary
              : palette.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : palette.surfaceMuted,
        ),
        trackOutlineColor: WidgetStatePropertyAll(palette.border),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : null,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.xs / 2),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : palette.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: palette.surfaceMuted,
        circularTrackColor: palette.surfaceMuted,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: palette.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.primaryMuted,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? palette.surface : palette.textPrimary,
        contentTextStyle: TextStyle(
          color: isDark ? palette.textPrimary : palette.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
        ),
      ),
    );
  }
}
