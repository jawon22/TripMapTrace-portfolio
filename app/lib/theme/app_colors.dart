import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary     = Color(0xFF1A2235); // 다크 네이비 (앱바, 로그인 배경)
  static const primaryDark = Color(0xFF2A3347); // 입력 필드 배경
  static const accent      = Color(0xFFF59E0B); // Amber (버튼, 활성 탭, 강조)
  static const background  = Color(0xFFF8F9FA); // off-white (홈, 프로필)
  static const cardBg      = Color(0xFFFFFFFF); // 카드 배경
  static const textOnDark  = Color(0xFFFFFFFF);
  static const textOnLight = Color(0xFF1A2235);
  static const textSub     = Color(0xFF9CA3AF); // 날짜, 설명 등 부제
  static const roleOwner   = Color(0xFFF59E0B); // amber
  static const roleEditor  = Color(0xFF3B82F6); // 파란색
  static const roleViewer  = Color(0xFF9CA3AF); // 회색
  static const destructive = Color(0xFFEF4444); // 빨간색

  // 상태 색상 (Tailwind-500 계열)
  static const success = Color(0xFF22C55E); // green-500 (성공)
  static const warning = Color(0xFFF97316); // orange-500 (경고·근사 위치)
  static const info    = Color(0xFF3B82F6); // blue-500 (정보)
  static const border  = Color(0xFFE5E7EB); // 입력/카드/구분선 테두리
}
