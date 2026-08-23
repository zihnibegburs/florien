import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icon_park/flutter_icon_park.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:florien/core/firebase/user_profile_service.dart';
import 'package:florien/core/storage/settings_storage.dart';

/// Florien design tokens — soft neo-brutalist, pastel accents, bold type.
class FlorienColors {
  static const primary = Color(0xFFFFF76A);
  static const accentText = Color(0xFF765415);
  static const focusAccent = Color(0xFFF2BC52);
  static const onPrimary = Color(0xFF171717);
  static const primaryLight = Color(0xFFFFF9A8);
  static const accent = Color(0xFFC4B5FD);
  static const aiAccent = Color(0xFFA78BFA);
  static const aiLavender = Color(0xFFE9E2FF);
  static const mint = Color(0xFFB8F2D0);
  static const paleBlue = Color(0xFFBCEEFF);
  static const softPink = Color(0xFFFFD6E7);
  static const softLime = Color(0xFFDDFC83);
  static const success = Color(0xFF2F9E6B);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);

  static const background = Color(0xFFFAF9F6);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF171717);
  static const textSecondary = Color(0xFF6B6B70);
  static const border = Color(0xFF171717);

  static const darkBackground = Color(0xFF29292B);
  static const darkSurface = Color(0xFF333336);
  static const darkTextPrimary = Color(0xFFF7F7F5);
  static const darkTextSecondary = Color(0xFFB7B7BA);
  static const darkBorder = Color(0xFF4A4A4E);

  static const taskColors = [
    '#FFF76A',
    '#C4B5FD',
    '#B8F2D0',
    '#BCEEFF',
    '#FFD6E7',
    '#DDFC83',
    '#FFE0B2',
    '#D1C4E9',
  ];

  static Color fromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  static LinearGradient get aiGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [paleBlue, aiAccent, softLime, primary],
  );
}

abstract final class FlorienSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double screen = 20;
}

abstract final class FlorienRadius {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
  static const double pill = 999;
}

abstract final class FlorienBorders {
  static const double thin = 1.25;
  static const double medium = 1.5;
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
    required this.accent,
    required this.aiSurface,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color primaryMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color error;
  final Color accent;
  final Color aiSurface;

  static const light = FlorienPalette(
    background: FlorienColors.background,
    surface: FlorienColors.surface,
    surfaceMuted: Color(0xFFF3F1EC),
    primaryMuted: Color(0xFFFFF6B8),
    textPrimary: FlorienColors.textPrimary,
    textSecondary: FlorienColors.textSecondary,
    border: Color(0xFF1A1A1A),
    error: FlorienColors.error,
    accent: FlorienColors.accent,
    aiSurface: FlorienColors.aiLavender,
  );

  static const dark = FlorienPalette(
    background: FlorienColors.darkBackground,
    surface: FlorienColors.darkSurface,
    surfaceMuted: Color(0xFF3A3A3E),
    primaryMuted: Color(0xFF4A4630),
    textPrimary: FlorienColors.darkTextPrimary,
    textSecondary: FlorienColors.darkTextSecondary,
    border: FlorienColors.darkBorder,
    error: Color(0xFFF87171),
    accent: FlorienColors.accent,
    aiSurface: Color(0xFF3A3550),
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
    Color? accent,
    Color? aiSurface,
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
      accent: accent ?? this.accent,
      aiSurface: aiSurface ?? this.aiSurface,
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
      accent: Color.lerp(accent, other.accent, t)!,
      aiSurface: Color.lerp(aiSurface, other.aiSurface, t)!,
    );
  }
}

extension FlorienPaletteContext on BuildContext {
  FlorienPalette get palette =>
      Theme.of(this).extension<FlorienPalette>() ?? FlorienPalette.light;

  bool get isFlorienDark => Theme.of(this).brightness == Brightness.dark;
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
    const primary = FlorienColors.primary;
    const interactivePrimary = FlorienColors.accentText;
    const onPrimary = FlorienColors.onPrimary;
    final baseTextTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: interactivePrimary,
      onPrimary: onPrimary,
      primaryContainer: palette.primaryMuted,
      onPrimaryContainer: palette.textPrimary,
      secondary: FlorienColors.accent,
      onSecondary: onPrimary,
      secondaryContainer: palette.aiSurface,
      onSecondaryContainer: palette.textPrimary,
      tertiary: FlorienColors.aiAccent,
      onTertiary: onPrimary,
      error: palette.error,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.surfaceMuted,
      surfaceContainer: palette.surfaceMuted,
      outline: palette.border,
      outlineVariant: palette.border.withValues(alpha: isDark ? 0.7 : 0.18),
    );

    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FlorienRadius.pill),
      side: BorderSide(color: palette.border, width: FlorienBorders.thin),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [
        palette,
        IconParkTheme.fromColorScheme(
          colorScheme,
          defaultTheme: IconParkThemeType.multiColor,
          strokeWidth: 3,
        ),
      ],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.border.withValues(alpha: isDark ? 0.5 : 0.12),
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -0.8,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -0.7,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: palette.border.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(FlorienRadius.xl),
          ),
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
        ),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: palette.textPrimary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.pill),
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          borderSide: BorderSide(
            color: palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          borderSide: BorderSide(
            color: palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          borderSide: BorderSide(
            color: palette.border,
            width: FlorienBorders.medium,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: palette.surfaceMuted,
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size(48, 54),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: pill,
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: palette.surfaceMuted,
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size(48, 54),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: pill,
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: palette.surface,
          minimumSize: const Size(48, 54),
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FlorienRadius.pill),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(44, 44),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
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
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: primary,
        side: BorderSide(color: palette.border, width: FlorienBorders.thin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.pill),
        ),
        labelStyle: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        checkColor: const WidgetStatePropertyAll(onPrimary),
        side: BorderSide(color: palette.border, width: FlorienBorders.thin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : palette.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border.withValues(alpha: isDark ? 0.45 : 0.12),
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? primary : onPrimary,
        linearTrackColor: palette.surfaceMuted,
        circularTrackColor: palette.surfaceMuted,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.textPrimary,
          backgroundColor: Colors.transparent,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FlorienRadius.pill),
            side: BorderSide(color: palette.border, width: FlorienBorders.thin),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
          borderRadius: BorderRadius.circular(FlorienRadius.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: palette.textPrimary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(size: 22, color: palette.textPrimary);
        }),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.textPrimary),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: palette.background,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? palette.surface : palette.textPrimary,
        contentTextStyle: TextStyle(
          color: isDark ? palette.textPrimary : palette.surface,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          side: BorderSide(color: palette.border, width: FlorienBorders.thin),
        ),
      ),
    );
  }
}
