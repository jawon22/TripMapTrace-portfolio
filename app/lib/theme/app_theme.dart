import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const fontFamily = 'Pretendard';

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.cardBg,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: AppColors.background,

      // AppBar 표면 위계 규칙:
      //   - 루트 4탭(홈·커뮤니티·글로벌 지도·프로필) = 라이트 앱바(아래 기본값)
      //   - 여행상세·풀스크린 등 몰입 화면 = 다크 앱바(각 화면에서 개별 설정)
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textOnLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnLight,
        ),
      ),

      // FilledButton — amber 배경
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardBg,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSub,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 11,
        ),
      ),

      // TabBar
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textSub,
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),

      // CircularProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
