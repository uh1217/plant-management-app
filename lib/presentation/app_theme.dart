import 'package:flutter/material.dart';
import 'app_colors.dart'; // 기존 AppColors 파일 import
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// 💾 테마 저장 함수
  static Future<void> saveTheme(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  // 📂 테마 불러오기 함수 (main.dart 시작 시 호출)
  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false; // 기본값은 라이트 모드
    themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // ☀️ 라이트 모드 테마
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,// 전체 배경 톤(안보임?)
    dividerColor: AppColors.gray200, //구분선
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryBlue, //선택 됬을때
      secondary: AppColors.primaryGreen, //버튼
      tertiary: AppColors.yellow600,
      surface: AppColors.white, //전체 배경
      onSurface: AppColors.gray900, // 글자색은 어둡게 (gray900)
      error: AppColors.statusRed,
    ),
    // 앱바, 카드 등 위젯별 기본 색상도 여기서 지정 가능
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.gray900,
      elevation: 0,
    ),
  );

  // 🌙 다크 모드 테마
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.gray900, // 배경은 어둡게 (gray900)
    dividerColor: AppColors.gray500,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryBlue, // 메인 컬러는 보통 그대로 유지
      secondary: AppColors.primaryGreen,
      tertiary: AppColors.statusYellow,
      surface: AppColors.gray900, 
      onSurface: AppColors.gray50, // 글자색은 밝게 (gray50)
      error: AppColors.red600,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.gray900,
      foregroundColor: AppColors.gray50,
      elevation: 0,
    ),
  );
}