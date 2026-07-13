import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── 테마 식별자 ──────────────────────────────────────────────────────────────
// 새 테마 추가 시 이 enum에 항목만 추가하면 됩니다.
enum AppThemeType {
  light,
  dark,
  starbucks,
  // 여기에 추가: forest, ocean, cherry, ...
}

// ── 테마 메타데이터 (UI 표시용) ───────────────────────────────────────────────
// 색상 칩 그리드 등 테마 선택 UI에서 사용합니다.
class AppThemeMeta {
  final String label;
  final Color primaryColor;
  final Color backgroundColor;

  const AppThemeMeta({
    required this.label,
    required this.primaryColor,
    required this.backgroundColor,
  });
}

// ── AppTheme ─────────────────────────────────────────────────────────────────
class AppTheme {
  // 현재 테마 상태 (앱 전체에서 listen)
  static final ValueNotifier<AppThemeType> themeNotifier =
      ValueNotifier(AppThemeType.light);

  // SharedPreferences 저장 키
  static const _prefsKey = 'theme_key';

  // ── 테마 메타데이터 레지스트리 ──────────────────────────────────────────
  // 새 테마 추가 시 이 맵에도 항목을 추가하세요.
  static const Map<AppThemeType, AppThemeMeta> meta = {
    AppThemeType.light: AppThemeMeta(
      label: '라이트',
      primaryColor: AppColors.white,
      backgroundColor: AppColors.primaryBlue,
    ),
    AppThemeType.dark: AppThemeMeta(
      label: '다크',
      primaryColor: AppColors.gray900,
      backgroundColor: AppColors.primaryBlue,
    ),
    AppThemeType.starbucks: AppThemeMeta(
      label: 'Starbucks',
      primaryColor: AppColors.starbucksGreen,
      backgroundColor: AppColors.starbucksGold,
    ),
    // 새 테마 추가 시 여기에 메타 정보를 넣으세요.
  };

  // ── ThemeData 레지스트리 ────────────────────────────────────────────────
  // 새 테마 추가 시 이 맵에도 ThemeData를 추가하세요.
  static final Map<AppThemeType, ThemeData> _themes = {
    AppThemeType.light: _lightTheme,
    AppThemeType.dark: _darkTheme,
    AppThemeType.starbucks: _starbucksTheme,
    // 새 테마 추가 시 여기에 ThemeData를 연결하세요.
  };

  // 현재 테마 타입에 해당하는 ThemeData 반환
  static ThemeData getTheme(AppThemeType type) =>
      _themes[type] ?? _lightTheme;

  // ── 저장 / 불러오기 ────────────────────────────────────────────────────
  static Future<void> saveTheme(AppThemeType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, type.name);
  }

  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_prefsKey);

    if (savedKey != null) {
      // 저장된 테마 이름으로 복원 (없으면 light 기본값)
      themeNotifier.value = AppThemeType.values.firstWhere(
        (t) => t.name == savedKey,
        orElse: () => AppThemeType.light,
      );
      return;
    }

    // 이전 버전 bool 기반 저장값과의 하위 호환
    final legacyDark = prefs.getBool('isDarkMode') ?? false;
    themeNotifier.value =
        legacyDark ? AppThemeType.dark : AppThemeType.light;
  }

  // ── ThemeData 정의 ─────────────────────────────────────────────────────

  // ── ColorScheme 슬롯 역할 정의 ──────────────────────────────────────────────
  // primary                → 탭 선택 강조
  // secondary              → 카테고리 선택 항목 선택
  // scaffoldBackground     → 전체 페이지 배경 (헤더·카드 제외 영역)
  // surface                → 홈 헤더 배경, 다이얼로그 배경
  // onSurface              → 홈 헤더 텍스트·아이콘 기본색
  // surfaceContainer       → 식물 카드 배경
  // onSurfaceVariant       → 카드 텍스트·아이콘
  // surfaceContainerLow    → 사이드바 전체 배경
  // surfaceContainerHigh   → 사이드바 헤더 배경
  // outline                → 사이드바 메뉴 텍스트·아이콘

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,   // 전체 배경: #FAFAFA
    dividerColor: AppColors.gray400,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryBlue,
      secondary: AppColors.primaryGreen,
      tertiary: AppColors.gray100,
      surface: AppColors.white,                      // 헤더 배경: #FFFFFF
      onSurface: AppColors.gray900,                  // 헤더 텍스트: #111827
      surfaceContainer: AppColors.gray100,           // 카드 배경: #F3F4F6
      onSurfaceVariant: AppColors.gray700,           // 카드 텍스트: #374151
      surfaceContainerLow: AppColors.gray50,         // 사이드바 배경: #F9FAFB
      surfaceContainerHigh: AppColors.gray200,       // 사이드바 헤더: #E5E7EB
      outline: AppColors.gray600,                    // 사이드바 텍스트: #4B5563
      error: AppColors.statusRed,
    ),
  );

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.gray900,      // 전체 배경: #111827
    dividerColor: AppColors.gray500,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryBlue,
      secondary: AppColors.primaryGreen,
      tertiary: AppColors.gray900,
      surface: AppColors.gray900,                    // 헤더 배경: #111827
      onSurface: AppColors.gray50,                   // 헤더 텍스트: #F9FAFB
      surfaceContainer: AppColors.gray800,           // 카드 배경: #1F2937
      onSurfaceVariant: AppColors.gray200,           // 카드 텍스트: #E5E7EB
      surfaceContainerLow: AppColors.gray900,        // 사이드바 배경: #111827
      surfaceContainerHigh: AppColors.gray700,       // 사이드바 헤더: #374151
      outline: AppColors.gray300,                    // 사이드바 텍스트: #D1D5DB
      error: AppColors.red600,
    ),
  );

  static final ThemeData _starbucksTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.starbucksBrown,    // 전체 배경: #27251F
    dividerColor: AppColors.starbucksGold,
    colorScheme: ColorScheme.dark(
      primary: AppColors.white, //선택시 강조
      secondary: AppColors.starbucksGold,
      tertiary: Colors.transparent,          // 이미지 섹션 오버레이 완전 투명
      surface: AppColors.starbucksBrown,             // 헤더 배경: #27251F
      onSurface: AppColors.white,                    // 헤더 텍스트: #FFFFFF
      surfaceContainer: AppColors.starbucksGreen,     // 카드 배경: starbucksGold
      onSurfaceVariant: AppColors.starbucksGold,    // 카드 텍스트: #27251F
      surfaceContainerLow: AppColors.starbucksBrown, // 사이드바 배경: #27251F
      surfaceContainerHigh: AppColors.starbucksBrown,// 사이드바 헤더: #27251F
      outline: AppColors.white,              // 사이드바 텍스트: starbucksGold
      error: AppColors.statusRed,
    ),
  );
}
