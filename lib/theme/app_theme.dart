import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Palet warna Neo-Fintech Minimalist — hijau-putih kalem, kontras tinggi.
class AppColors {
  AppColors._();

  static const background      = Color(0xFFF4F7F5); // Off-white mint tipis
  static const surface         = Color(0xFFFFFFFF); // Card terang
  static const border          = Color(0xFFE2EAE5); // Border tipis
  static const primary         = Color(0xFF0F291E); // Hijau hutan gelap
  static const accent          = Color(0xFF1B9C67); // Emerald matte
  static const softMint        = Color(0xFFE5F2EC); // Container sekunder
  static const textPrimary     = Color(0xFF111C17); // Hampir hitam
  static const textSecondary   = Color(0xFF63736B); // Abu kehijauan
  static const expense         = Color(0xFFC84B31); // Terracotta muted
  static const divider         = Color(0xFFF0F4F2); // Pemisah list
  static const mutedOnDark     = Color(0xFFA3B8AE); // Teks di hero card
}

/// Palet Dark Mode — Deep Forest Slate (kalem, tidak hitam pekat #000000).
class AppDarkColors {
  AppDarkColors._();

  static const background      = Color(0xFF0C1411);
  static const surface         = Color(0xFF14201B);
  static const border          = Color(0xFF22332B);
  static const primary         = Color(0xFF1B9C67);
  static const accent          = Color(0xFF28B87D);
  static const softMint        = Color(0xFF192B24);
  static const textPrimary     = Color(0xFFEDF3F0);
  static const textSecondary   = Color(0xFF8FA399);
  static const expense         = Color(0xFFE0644B);
  static const divider         = Color(0xFF1D2C26);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.expense,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppDarkColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppDarkColors.primary,
          secondary: AppDarkColors.accent,
          surface: AppDarkColors.surface,
          error: AppDarkColors.expense,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      );
}

/// Controller tema & pengaturan aplikasi berbasis Hive.
class SettingsController {
  SettingsController._();

  static const String boxName = 'app_settings';
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light);

  static Future<void> init() async {
    final box = await Hive.openBox(boxName);
    final isDark = box.get('isDark', defaultValue: false) as bool;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggleDarkMode(bool isDark) async {
    final box = Hive.box(boxName);
    await box.put('isDark', isDark);
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static bool get isDark => themeMode.value == ThemeMode.dark;

  // Pengingat Menabung
  static bool get reminderEnabled =>
      Hive.box(boxName).get('reminderEnabled', defaultValue: false) as bool;

  static String get reminderTime =>
      Hive.box(boxName).get('reminderTime', defaultValue: '20:00') as String;

  static Future<void> saveReminder({
    required bool enabled,
    required String time,
  }) async {
    final box = Hive.box(boxName);
    await box.put('reminderEnabled', enabled);
    await box.put('reminderTime', time);
  }
}