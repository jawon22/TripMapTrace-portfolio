import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 앱 전역 타이포그래피 토큰(Pretendard 기반). 화면별 하드코딩을 점진 치환하는 기준점.
class AppTextStyles {
  AppTextStyles._();

  static const String _f = 'Pretendard';

  static const h1 = TextStyle(
      fontFamily: _f,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textOnLight);
  static const h2 = TextStyle(
      fontFamily: _f,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textOnLight);
  static const title = TextStyle(
      fontFamily: _f,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textOnLight);
  static const body = TextStyle(
      fontFamily: _f,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textOnLight);
  static const caption = TextStyle(
      fontFamily: _f,
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: AppColors.textSub);
}
