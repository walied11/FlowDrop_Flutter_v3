import 'package:flutter/material.dart';

/// ألوان FlowDrop (مأخوذة من colors.xml في النسخة الأصلية).
class AppColors {
  static const primary = Color(0xFF159EFF);
  static const secondary = Color(0xFF7B24FF);

  static const bgDark = Color(0xFF071321);
  static const cardDark = Color(0xFF102238);
  static const textDark = Color(0xFFF7FAFF);
  static const mutedDark = Color(0xFFAAB9CF);

  static const bgLight = Color(0xFFF4F8FF);
  static const cardLight = Color(0xFFFFFFFF);
  static const textLight = Color(0xFF17243A);
  static const mutedLight = Color(0xFF66758C);

  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);

  static const gradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  static ThemeData build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? AppColors.bgDark : AppColors.bgLight;
    final card = dark ? AppColors.cardDark : AppColors.cardLight;
    final text = dark ? AppColors.textDark : AppColors.textLight;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: b,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: card,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF1B3350) : const Color(0xFF17243A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: AppColors.primary.withOpacity(.16),
        height: 66,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final sel = states.contains(MaterialState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            color: sel
                ? AppColors.primary
                : (dark ? AppColors.mutedDark : AppColors.mutedLight),
          );
        }),
      ),
    );
  }
}

extension ThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bgColor => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get cardColor2 => isDark ? AppColors.cardDark : AppColors.cardLight;
  Color get textColor => isDark ? AppColors.textDark : AppColors.textLight;
  Color get mutedColor => isDark ? AppColors.mutedDark : AppColors.mutedLight;
  Color get borderColor =>
      isDark ? Colors.white.withOpacity(.07) : Colors.black.withOpacity(.07);
}
