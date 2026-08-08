import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mimio/core/firebase/user_profile_service.dart';
import 'package:mimio/core/storage/settings_storage.dart';

/// Quiet Momentum — warm neutrals, grounded indigo and optimistic amber.
///
/// Colour is reserved for meaning and primary actions. The neutral surfaces keep
/// long planning sessions calm while the indigo remains recognisable in both
/// light and dark modes.
class MimioColors {
  static const primary = Color(0xFF5457A6);
  static const primaryLight = Color(0xFF8588D8);
  static const accent = Color(0xFFE06F4F);
  static const success = Color(0xFF2E8B6F);
  static const warning = Color(0xFFD18A22);

  // Light semantic defaults (prefer [MimioPalette] via context in widgets).
  static const background = Color(0xFFF7F5F0);
  static const surface = Color(0xFFFFFDF9);
  static const textPrimary = Color(0xFF24242B);
  static const textSecondary = Color(0xFF696872);
  static const border = Color(0xFFE5E1D9);

  static const taskColors = [
    '#5457A6',
    '#D96C4F',
    '#2E8B6F',
    '#8A62A8',
    '#347BA8',
    '#C68A28',
    '#B85F78',
    '#5F8D4E',
    '#637CC4',
    '#A67751',
    '#7765A8',
    '#438B86',
  ];

  static Color fromHex(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

@immutable
class MimioPalette extends ThemeExtension<MimioPalette> {
  const MimioPalette({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  static const light = MimioPalette(
    background: Color(0xFFF7F5F0),
    surface: Color(0xFFFFFDF9),
    textPrimary: Color(0xFF24242B),
    textSecondary: Color(0xFF696872),
    border: Color(0xFFE5E1D9),
  );

  static const dark = MimioPalette(
    background: Color(0xFF17171C),
    surface: Color(0xFF222228),
    textPrimary: Color(0xFFF3F0EA),
    textSecondary: Color(0xFFAAA7B0),
    border: Color(0xFF37363E),
  );

  @override
  MimioPalette copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
  }) {
    return MimioPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
    );
  }

  @override
  MimioPalette lerp(MimioPalette? other, double t) {
    if (other == null) return this;
    return MimioPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension MimioPaletteContext on BuildContext {
  MimioPalette get palette =>
      Theme.of(this).extension<MimioPalette>() ?? MimioPalette.light;
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

class MimioTheme {
  static ThemeData get light => _build(Brightness.light, MimioPalette.light);

  static ThemeData get dark => _build(Brightness.dark, MimioPalette.dark);

  static ThemeData _build(Brightness brightness, MimioPalette palette) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFFAEB0FF) : MimioColors.primary;
    final baseTextTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [palette],
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        surface: palette.surface,
        primary: primary,
        secondary: MimioColors.accent,
        onSurface: palette.textPrimary,
      ),
      scaffoldBackgroundColor: palette.background,
      cardColor: palette.surface,
      dividerColor: palette.border,
      textTheme: baseTextTheme.copyWith(
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
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
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        contentTextStyle: GoogleFonts.manrope(
          fontSize: 14,
          color: palette.textPrimary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: isDark ? const Color(0xFF1C1C24) : Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C22) : const Color(0xFFF1EEE8),
        hintStyle: TextStyle(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? const Color(0xFF1C1C24) : Colors.white,
          disabledBackgroundColor: palette.border,
          disabledForegroundColor: palette.textSecondary,
          minimumSize: const Size(48, 52),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
          side: BorderSide(color: palette.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
