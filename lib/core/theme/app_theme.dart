import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.slate900,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.slate800,
        primary: AppColors.accent,
        secondary: AppColors.accentDark,
        error: AppColors.statusOpen,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.slate900,
        foregroundColor: AppColors.slate200,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.slate800,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.slate700, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: AppColors.slate700,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate800,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.slate700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.slate500),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.slate900,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.slate200,
        displayColor: AppColors.slate200,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.slate700,
        contentTextStyle: TextStyle(color: AppColors.slate200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
