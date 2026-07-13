//앱 전체색상 통일, Tailwind CSS 색상을 Flutter로 변환
import 'package:flutter/material.dart';

// globals.css 변환
class AppColors {
  // Primary Colors
  static const primaryBlue = Color(0xFF3B82F6); // Blue-500
  static const primaryGreen = Color(0xFF22C55E); // Green-500
  
  // Status Colors
  static const statusRed = Color(0xFFDC2626); // Red-600 (긴급)
  static const statusYellow = Color.fromARGB(255, 236, 233, 17); // Orange-500 (주의)
  static const statusGreen = Color(0xFF22C55E); // Green-500 (정상)
  
  // Gray Scale
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);
  
  // Background
  static const background = Color(0xFFFAFAFA);
  static const white = Color(0xFFFFFFFF);
  
  // Blue Variants (선택 상태)
  static const blue50 = Color(0xFFEFF6FF);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  
  // Green Variants (비료)
  static const green50 = Color(0xFFF0FDF4);
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  
  // Red Variants (긴급)
  static const red50 = Color(0xFFFEF2F2);
  static const red600 = Color(0xFFDC2626);
  
  // Yellow Variants (주의)
  static const yellow50 = Color(0xFFFFF7ED);
  static const yellow200 = Color(0xFFF9D48A); // 노란+살색 혼합 (농약 표시용)
  static const yellow600 = Color.fromARGB(255, 206, 209, 9);

  // Starbucks Colors
  static const Color starbucksGreen = Color(0xFF00704A); // 메인 사이렌 그린
  static const Color starbucksGold = Color(0xFFC28E0E);  // 리워드 별 및 포인트 컬러
  static const Color starbucksBrown = Color(0xFF27251F); // 짙은 커피 브라운 (블랙 대용)

}
