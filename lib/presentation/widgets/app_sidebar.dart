import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:plantapp_p/Data/datasources/city_datasource.dart';
import 'package:plantapp_p/core/services/notification_service.dart';
import 'package:plantapp_p/presentation/app_colors.dart';
import 'package:plantapp_p/presentation/app_theme.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';
import 'package:plantapp_p/presentation/widgets/plant_agent_dialog.dart';

// ── 날씨 추천 카드 설정 다이얼로그 ────────────────────────────────────────────

Future<void> showWeatherRecommendationSettingsDialog(
  BuildContext context,
  HomeViewModel viewModel,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _WeatherRecommendationSettingsDialog(viewModel: viewModel),
  );
}

class _WeatherRecommendationSettingsDialog extends StatefulWidget {
  const _WeatherRecommendationSettingsDialog({required this.viewModel});
  final HomeViewModel viewModel;

  @override
  State<_WeatherRecommendationSettingsDialog> createState() =>
      _WeatherRecommendationSettingsDialogState();
}

class _WeatherRecommendationSettingsDialogState
    extends State<_WeatherRecommendationSettingsDialog> {
  late bool _enabled;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _enabled = widget.viewModel.weatherRecommendationEnabled;
    _selectedCity = widget.viewModel.selectedCity;
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final cityNames = CityDataSource.cities.keys.toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.wb_sunny_outlined, color: outline),
          const SizedBox(width: 8),
          Text('날씨 추천 카드',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: outline)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: Text('날씨 추천 카드',
                style: TextStyle(color: outline)),
            subtitle: Text(
              _enabled
                  ? '오전/오후 날씨 기반 식물 케어 알림 표시 중'
                  : '날씨 추천 카드 꺼짐',
              style: TextStyle(color: outline.withOpacity(0.7)),
            ),
            value: _enabled,
            activeColor: AppColors.primaryGreen,
            onChanged: (value) {
              setState(() => _enabled = value);
            },
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '전체 식물 보기에서 오전 6시(오늘 날씨)와 오후 6시(내일 날씨)에 맞춤 식물 케어 멘트를 표시합니다.',
              style: TextStyle(
                fontSize: 12,
                color: outline.withOpacity(0.55),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: outline.withOpacity(0.2)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '날씨 조회 도시',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: outline,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 도시 선택 드롭다운
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: outline.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCity,
                hint: Text(
                  '도시를 선택하세요',
                  style: TextStyle(
                      color: outline.withOpacity(0.5), fontSize: 14),
                ),
                isExpanded: true,
                items: cityNames
                    .map((city) => DropdownMenuItem(
                          value: city,
                          child: Text(city,
                              style:
                                  TextStyle(color: outline, fontSize: 14)),
                        ))
                    .toList(),
                onChanged: (city) => setState(() => _selectedCity = city),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소', style: TextStyle(color: outline)),
        ),
        FilledButton(
          onPressed: () async {
            await widget.viewModel
                .setWeatherRecommendationEnabled(_enabled);
            if (_selectedCity != null &&
                _selectedCity != widget.viewModel.selectedCity) {
              // 도시가 바뀌었으면 setCity가 캐시 무효화 + 재로드를 처리
              await widget.viewModel.setCity(_selectedCity!);
            } else if (_enabled) {
              await widget.viewModel.loadWeatherRecommendation();
            }
            if (context.mounted) Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          child: Text('저장', style: TextStyle(color: outline)),
        ),
      ],
    );
  }
}

// ── 공용 다이얼로그 / 앱 액션 함수 ─────────────────────────────────────────────

void showAppSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setDialogState) {
        final currentTheme = AppTheme.themeNotifier.value;
        final outline = Theme.of(ctx2).colorScheme.outline;
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.palette_outlined, color: outline),
              const SizedBox(width: 8),
              Text('테마 설정',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: outline)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '테마를 선택하세요',
                style: TextStyle(
                    fontSize: 13, color: outline.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: AppThemeType.values.map((type) {
                  final themeMeta = AppTheme.meta[type]!;
                  final isSelected = currentTheme == type;
                  return _ThemeChip(
                    meta: themeMeta,
                    isSelected: isSelected,
                    onTap: () async {
                      AppTheme.themeNotifier.value = type;
                      await AppTheme.saveTheme(type);
                      setDialogState(() {});
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('닫기', style: TextStyle(color: outline)),
            ),
          ],
        );
      },
    ),
  );
}

// ── 테마 선택 칩 위젯 ─────────────────────────────────────────────────────────
class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.meta,
    required this.isSelected,
    required this.onTap,
  });

  final AppThemeMeta meta;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  meta.primaryColor,
                  meta.backgroundColor == AppColors.white
                      ? meta.primaryColor.withOpacity(0.6)
                      : meta.backgroundColor,
                ],
              ),
              border: isSelected
                  ? Border.all(
                      color: meta.primaryColor,
                      width: 3,
                    )
                  : Border.all(color: Colors.transparent, width: 3),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: meta.primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            meta.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? meta.primaryColor : outline,
            ),
          ),
        ],
      ),
    );
  }
}

// showAppUsageGuide는 interactive guide로 교체됨 (home_screen.dart의 startUserGuide 참조)

void _showPrivacyPolicy(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('개인정보 처리 방침'),
      content: const SingleChildScrollView(
        child: Text(
          '1. 수집하는 정보\n'
          '· Google 로그인: 이메일, 이름, 사용자 ID\n'
          '· 이용자 입력: 식물 정보, 관리 기록, 사진\n'
          '· AI 상담: 채팅 내용 및 첨부 사진\n'
          '· 날씨 추천: 선택한 도시의 위치(좌표)\n\n'
          '2. 이용 목적\n'
          '· 계정 인증, 데이터 저장·동기화\n'
          '· 식물 관리, AI 상담, 날씨 기반 케어 추천\n'
          '· 물주기 알림(선택)\n\n'
          '3. 제3자 제공\n'
          '· Google(Firebase, Gemini AI): 인증·저장·AI 처리\n'
          '· OpenWeatherMap: 날씨 예보(Cloud Functions 경유)\n\n'
          '4. 권한(선택)\n'
          '· 사진(갤러리): 식물 사진 등록·AI 첨부\n'
          '· 알림·정확한 알람: 물주기 알림\n'
          '거부 시 해당 기능만 제한됩니다.\n\n'
          '5. 보관 및 삭제\n'
          '· 앱 내에서 식물별 데이터 삭제 가능\n'
          '· 계정·전체 데이터 삭제: yoohyun031217@gmail.com\n\n'
          '6. 문의: yoohyun031217@gmail.com (개발자: 이유현)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

Widget _appInfoIcon({double size = 48}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      'assets/images/PlantApp_Icon.png',
      width: size,
      height: size,
    ),
  );
}

void showAppInfo(BuildContext context) {
  final year = DateTime.now().year;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          _appInfoIcon(),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '식물 관리 앱',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text('Version 2.4.3', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('© $year 이유현. All rights reserved.'),
            const SizedBox(height: 12),
            const Text(
              '문의: yoohyun031217@gmail.com',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              '오픈소스 패키지(Flutter, Firebase 등) 라이선스는 '
              '「라이선스 보기」에서 자동으로 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            _showPrivacyPolicy(context);
          },
          child: const Text('개인정보 처리방침'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            showLicensePage(
              context: context,
              applicationName: '식물 관리 앱',
              applicationVersion: '2.4.3',
              applicationIcon: _appInfoIcon(size: 40),
            );
          },
          child: const Text('라이선스 보기'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}

Future<void> sendAppEmail(BuildContext context) async {
  final uri = Uri(
    scheme: 'mailto',
    path: 'yoohyun031217@gmail.com',
    query:
        'subject=[식물 관리 앱 문의]&body=문의 내용을 작성해 주세요.(휴대폰 기종 정보와 에러 상황에 대한 자세한 설명이 포함되면 더욱 구체적인 답변이 가능합니다!)',
  );
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw '메일 앱을 열 수 없습니다.';
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 앱을 찾을 수 없습니다.')),
      );
    }
  }
}

// ── AppSidebar 위젯 ───────────────────────────────────────────────────────────
//
// HomeScreen 과 InputScreen 에서 공유하는 사이드바.
// - 검색 컨트롤러는 이 위젯이 내부적으로 관리한다.
// - 카테고리 목록은 viewModel.plants 에서 직접 계산한다.
// - 각 항목의 동작은 콜백으로 주입받아 화면별로 다르게 처리한다.
//
// [입력 화면] 메뉴 동작:
//   isInputActive = true  → 현재 입력 화면이므로 하이라이트 + 탭 시 사이드바만 닫음
//   isInputActive = false → 탭 시 onNavigateToInput 호출 (null 이면 onClose 호출)

class AppSidebar extends StatefulWidget {
  const AppSidebar({
    super.key,
    required this.viewModel,
    required this.onClose,
    required this.onAllPlants,
    required this.onSelectCategory,
    required this.onSearch,
    required this.onSettings,
    required this.onUsageGuide,
    required this.onLogout,
    required this.onContactEmail,
    required this.onAppInfo,
    this.selectedCategory,
    this.onNavigateToInput,
    this.isInputActive = false,
    this.onDateSearch,
    this.selectedDate,
    this.guideInputMenuKey,
    this.guideSidebarBodyKey,
    this.guideNavSectionKey,
    this.guideFuncSectionKey,
    this.guideCategoryListKey,
  });

  final HomeViewModel viewModel;
  final VoidCallback onClose;
  final VoidCallback onAllPlants;
  final void Function(String?) onSelectCategory;
  final void Function(String) onSearch;
  final VoidCallback onSettings;
  final VoidCallback onUsageGuide;
  final VoidCallback onLogout;
  final VoidCallback onContactEmail;
  final VoidCallback onAppInfo;
  final String? selectedCategory;

  /// null 이면 이미 입력 화면에 있는 것으로 간주 (isInputActive = true 와 함께 사용)
  final VoidCallback? onNavigateToInput;
  final bool isInputActive;

  /// null 이면 날짜 검색 항목을 표시하지 않음
  final void Function(String isoDate)? onDateSearch;
  final String? selectedDate;

  /// 사용 가이드 spotlight 키 — "입력 화면" 메뉴 항목 강조용
  final GlobalKey? guideInputMenuKey;

  /// 사용 가이드 spotlight 키 — 사이드바 전체 본문(기능+카테고리) 강조용
  final GlobalKey? guideSidebarBodyKey;

  /// 사용 가이드 spotlight 키 — 내비게이션 섹션 강조용
  final GlobalKey? guideNavSectionKey;

  /// 사용 가이드 spotlight 키 — 기능 섹션 강조용
  final GlobalKey? guideFuncSectionKey;

  /// 사용 가이드 spotlight 키 — 카테고리 목록 강조용
  final GlobalKey? guideCategoryListKey;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final TextEditingController _searchCtrl = TextEditingController();
  Set<String> _favoriteCategories = {};

  static const _prefsKey = 'favorite_categories';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) setState(() => _favoriteCategories = saved.toSet());
  }

  Future<void> _toggleFavorite(String category) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteCategories.contains(category)) {
        _favoriteCategories.remove(category);
      } else {
        _favoriteCategories.add(category);
      }
    });
    await prefs.setStringList(_prefsKey, _favoriteCategories.toList());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    widget.onSearch(query);
    _searchCtrl.clear();
  }

  Future<void> _pickDateAndSearch(BuildContext context) async {
    final initial = widget.selectedDate != null
        ? (DateTime.tryParse(widget.selectedDate!) ?? DateTime.now())
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '물 준 날짜 선택',
      confirmText: '검색',
      cancelText: '취소',
    );
    if (picked != null) {
      final isoDate = picked.toIso8601String().split('T')[0];
      widget.onDateSearch?.call(isoDate);
    }
  }

  void _showSettingsMenu(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final outline = Theme.of(ctx).colorScheme.outline;
        return SimpleDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.settings_outlined, size: 20, color: outline),
              const SizedBox(width: 8),
              Text('설정', style: TextStyle(color: outline)),
            ],
          ),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                showAppSettingsDialog(context);
              },
              child: ListTile(
                leading:
                    Icon(Icons.palette_outlined, color: outline),
                title: Text('테마 설정',
                    style: TextStyle(color: outline)),
                subtitle: Text('라이트 / 다크 모드',
                    style: TextStyle(
                        color: outline.withOpacity(0.7))),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: outline.withOpacity(0.3)),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog<void>(
                  context: context,
                  builder: (_) => const _AlarmSettingsDialog(),
                );
              },
              child: ListTile(
                leading: Icon(Icons.alarm, color: outline),
                title: Text('알람 설정',
                    style: TextStyle(color: outline)),
                subtitle: Text('알람 시간 및 켜기 / 끄기',
                    style: TextStyle(
                        color: outline.withOpacity(0.7))),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: outline.withOpacity(0.3)),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                showWeatherRecommendationSettingsDialog(
                    context, widget.viewModel);
              },
              child: ListTile(
                leading:
                    Icon(Icons.wb_sunny_outlined, color: outline),
                title: Text('날씨 추천 카드',
                    style: TextStyle(color: outline)),
                subtitle: Text(
                  widget.viewModel.weatherRecommendationEnabled
                      ? '켜짐 — 오전/오후 식물 케어 멘트'
                      : '꺼짐',
                  style:
                      TextStyle(color: outline.withOpacity(0.7)),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> get _allCategories {
    final cats = <String>{};
    for (final plant in widget.viewModel.plants) {
      cats.addAll(plant.categories);
    }
    final all = cats.toList();
    final favorites = all.where((c) => _favoriteCategories.contains(c)).toList()..sort();
    final normal = all.where((c) => !_favoriteCategories.contains(c)).toList()..sort();
    return [...favorites, ...normal];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── 헤더 ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                border: Border(
                    bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '메뉴',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close,
                        size: 20,
                        color:
                            colorScheme.onSurface.withOpacity(0.6)),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ),
            ),

            // ── 스크롤 가능 본문 ────────────────────────────────
            Expanded(
              child: _wrapWithShowcase(
                showcaseKey: widget.guideSidebarBodyKey,
                title: '사이드바 기능',
                description: '설정·AI 챗봇·카테고리 등 다양한 기능에 접근할 수 있어요',
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    primary: false,
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          // ── 내비게이션 섹션 ────────────────────
                          _wrapWithShowcase(
                            showcaseKey: widget.guideNavSectionKey,
                            title: '화면 이동',
                            description: '입력·전체 식물·날짜 검색 화면으로 이동합니다',
                            child: Column(
                              children: [
                                _buildMenuItem(
                                  icon: Icons.add_circle_outline,
                                  label: '입력 화면',
                                  isSelected: widget.isInputActive,
                                  onTap: widget.isInputActive
                                      ? widget.onClose
                                      : (widget.onNavigateToInput ??
                                          widget.onClose),
                                  showcaseKey: widget.guideInputMenuKey,
                                  showcaseDescription:
                                      '여기서 새 식물 추가 화면으로 이동합니다',
                                ),
                                _buildMenuItem(
                                  icon: Icons.list,
                                  label: '전체 식물',
                                  isSelected: !widget.isInputActive &&
                                      widget.selectedCategory == null &&
                                      widget.selectedDate == null,
                                  onTap: widget.onAllPlants,
                                ),
                                if (widget.onDateSearch != null)
                                  _buildMenuItem(
                                    icon: Icons.calendar_month_outlined,
                                    label: '날짜 기반 검색',
                                    isSelected: widget.selectedDate != null,
                                    onTap: () =>
                                        _pickDateAndSearch(context),
                                    trailing: widget.selectedDate != null
                                        ? Text(
                                            widget.selectedDate!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        : null,
                                  ),
                              ],
                            ),
                          ),

                          // ── 기능 섹션 ──────────────────────────
                          _wrapWithShowcase(
                            showcaseKey: widget.guideFuncSectionKey,
                            title: '기능 메뉴',
                            description: 'AI 챗봇·설정·가이드·로그아웃 기능을 사용할 수 있어요',
                            child: Column(
                              children: [
                                _buildAgentMenuItem(context),
                                _buildMenuItem(
                                  icon: Icons.settings_outlined,
                                  label: '설정',
                                  isSelected: false,
                                  onTap: () => _showSettingsMenu(context),
                                ),
                                _buildMenuItem(
                                  icon: Icons.help_outline,
                                  label: '사용 가이드',
                                  isSelected: false,
                                  onTap: widget.onUsageGuide,
                                ),
                                _buildMenuItem(
                                  icon: Icons.logout,
                                  label: '로그아웃',
                                  isSelected: false,
                                  onTap: widget.onLogout,
                                ),
                              ],
                            ),
                          ),

                        // ── 검색 ──────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: TextField(
                            controller: _searchCtrl,
                            onSubmitted: (_) => _handleSearch(),
                            style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.outline),
                            decoration: InputDecoration(
                              hintText: '식물 이름 검색',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: colorScheme.outline
                                    .withOpacity(0.4),
                              ),
                              prefixIcon: GestureDetector(
                                onTap: _handleSearch,
                                child: Icon(Icons.search,
                                    size: 20,
                                    color: colorScheme.outline
                                        .withOpacity(0.6)),
                              ),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: theme.dividerColor,
                                    width: 1),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: colorScheme.primary,
                                    width: 2),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 12),
                            ),
                          ),
                        ),

                        // ── 카테고리 목록 ──────────────────────
                        if (_allCategories.isNotEmpty)
                          _wrapWithShowcase(
                            showcaseKey: widget.guideCategoryListKey,
                            title: '카테고리',
                            description: '카테고리별로 식물을 필터링할 수 있어요',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '카테고리',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.outline
                                            .withOpacity(0.5),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                ..._allCategories
                                    .map((cat) => _buildCategoryItem(cat)),
                              ],
                            ),
                          ),

                          const Divider(),
                          Builder(
                            builder: (ctx) {
                              final outline = Theme.of(ctx).colorScheme.outline;
                              return Column(
                                children: [
                                  ListTile(
                                    leading: Icon(
                                        Icons.contact_support_outlined,
                                        color: outline),
                                    title: Text('고객 문의',
                                        style: TextStyle(color: outline)),
                                    subtitle: Text(
                                      '불편한 점이나 제안사항을 보내주세요',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: outline.withOpacity(0.7)),
                                    ),
                                    onTap: widget.onContactEmail,
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.info_outline,
                                        color: outline),
                                    title: Text('앱 정보',
                                        style: TextStyle(color: outline)),
                                    onTap: widget.onAppInfo,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapWithShowcase({
    required GlobalKey? showcaseKey,
    required String title,
    required String description,
    required Widget child,
  }) {
    if (showcaseKey == null) return child;
    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      tooltipBackgroundColor: Colors.white,
      textColor: Colors.black87,
      tooltipActions: const [
        TooltipActionButton(
          type: TooltipDefaultActionType.next,
          name: '다음',
        ),
      ],
      child: child,
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
    GlobalKey? showcaseKey,
    String? showcaseDescription,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outline.withOpacity(0.7),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
    if (showcaseKey != null && showcaseDescription != null) {
      return Showcase(
        key: showcaseKey,
        description: showcaseDescription,
        tooltipBackgroundColor: Colors.white,
        textColor: Colors.black87,
        tooltipActions: const [
          TooltipActionButton(
            type: TooltipDefaultActionType.next,
            name: '다음',
          ),
        ],
        child: item,
      );
    }
    return item;
  }

  /// 식물 Agent 메뉴 항목 — 강조 배지 포함 특수 스타일
  Widget _buildAgentMenuItem(BuildContext context) {
    return InkWell(
      onTap: () {
        widget.onClose(); // 사이드바 닫기
        // 사이드바 닫힘 애니메이션이 끝난 뒤 다이얼로그 표시
        Future.delayed(const Duration(milliseconds: 220), () {
          if (context.mounted) showPlantAgentDialog(context);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryGreen.withOpacity(0.12),
              AppColors.primaryGreen.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primaryGreen.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.eco,
              size: 20,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '식물 Agent',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String category) {
    final isSelected = widget.selectedCategory == category;
    final isFavorite = _favoriteCategories.contains(category);
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => widget.onSelectCategory(category),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.secondary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_offer,
              size: 16,
              color: isSelected
                  ? colorScheme.secondary
                  : colorScheme.outline.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? colorScheme.secondary
                      : colorScheme.outline.withOpacity(0.7),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _toggleFavorite(category),
              child: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                size: 18,
                color: isFavorite
                    ? Colors.amber
                    : colorScheme.outline.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 알람 설정 다이얼로그 ────────────────────────────────────────────────────────

class _AlarmSettingsDialog extends StatefulWidget {
  const _AlarmSettingsDialog();

  @override
  State<_AlarmSettingsDialog> createState() => _AlarmSettingsDialogState();
}

class _AlarmSettingsDialogState extends State<_AlarmSettingsDialog> {
  int _hour = 7;
  int _minute = 0;
  bool _isAm = true;
  bool _alarmEnabled = false;

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;

  static const _keyHour = 'alarm_hour';
  static const _keyMinute = 'alarm_minute';
  static const _keyIsAm = 'alarm_is_am';
  static const _keyEnabled = 'alarm_enabled';

  /// AM/PM 12시간제 → 24시간제 변환
  /// AM 12:xx = 자정(0시), PM 12:xx = 정오(12시)
  int get _hour24 {
    if (_isAm) {
      return _hour == 12 ? 0 : _hour;
    } else {
      return _hour == 12 ? 12 : _hour + 12;
    }
  }

  @override
  void initState() {
    super.initState();
    _hourCtrl = FixedExtentScrollController(initialItem: _hour - 1);
    _minCtrl = FixedExtentScrollController(initialItem: _minute);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final h = prefs.getInt(_keyHour) ?? 7;
    final m = prefs.getInt(_keyMinute) ?? 0;
    final am = prefs.getBool(_keyIsAm) ?? true;
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    if (!mounted) return;
    setState(() {
      _hour = h;
      _minute = m;
      _isAm = am;
      _alarmEnabled = enabled;
    });
    _hourCtrl.jumpToItem(_hour - 1);
    _minCtrl.jumpToItem(_minute);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, _hour);
    await prefs.setInt(_keyMinute, _minute);
    await prefs.setBool(_keyIsAm, _isAm);
    await prefs.setBool(_keyEnabled, _alarmEnabled);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final outline = colorScheme.outline;
    final minuteStr = _minute.toString().padLeft(2, '0');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      title: Row(
        children: [
          Icon(Icons.alarm, color: outline),
          const SizedBox(width: 8),
          Text('알람 설정',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: outline)),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 시계 영역 (알람 꺼짐이면 흐리게) ──────────────────
            AbsorbPointer(
              absorbing: !_alarmEnabled,
              child: AnimatedOpacity(
                opacity: _alarmEnabled ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 250),
                child: Column(
                  children: [
                    // 현재 선택 시간 크게 표시
                    Text(
                      '$_hour:$minuteStr',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 시 / 분 드럼 롤러 피커
                    SizedBox(
                      height: 140,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 시간 (1 ~ 12)
                          Expanded(
                            child: Column(
                              children: [
                                Text('시',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: outline.withOpacity(0.5),
                                    )),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: _hourCtrl,
                                    itemExtent: 38,
                                    selectionOverlay:
                                        CupertinoPickerDefaultSelectionOverlay(
                                      background: colorScheme.primary
                                          .withOpacity(0.12),
                                    ),
                                    onSelectedItemChanged: (i) =>
                                        setState(() => _hour = i + 1),
                                    children: List.generate(
                                      12,
                                      (i) => Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 구분자
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 4, top: 16),
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: outline,
                              ),
                            ),
                          ),

                          // 분 (00 ~ 59)
                          Expanded(
                            child: Column(
                              children: [
                                Text('분',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: outline.withOpacity(0.5),
                                    )),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: CupertinoPicker(
                                    scrollController: _minCtrl,
                                    itemExtent: 38,
                                    selectionOverlay:
                                        CupertinoPickerDefaultSelectionOverlay(
                                      background: colorScheme.primary
                                          .withOpacity(0.12),
                                    ),
                                    onSelectedItemChanged: (i) =>
                                        setState(() => _minute = i),
                                    children: List.generate(
                                      60,
                                      (i) => Center(
                                        child: Text(
                                          i.toString().padLeft(2, '0'),
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // AM / PM 토글
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                            value: true,
                            label: Text('AM'),
                            icon: Icon(Icons.wb_sunny_outlined, size: 16)),
                        ButtonSegment(
                            value: false,
                            label: Text('PM'),
                            icon: Icon(Icons.nights_stay_outlined, size: 16)),
                      ],
                      selected: {_isAm},
                      onSelectionChanged: (v) =>
                          setState(() => _isAm = v.first),
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),

            // ── 알람 켜기 / 끄기 스위치 ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _alarmEnabled ? Icons.alarm_on : Icons.alarm_off,
                      key: ValueKey(_alarmEnabled),
                      color: _alarmEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _alarmEnabled ? '알람 켜짐' : '알람 꺼짐',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _alarmEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _alarmEnabled,
                    activeColor: Colors.green,
                    onChanged: (v) => setState(() => _alarmEnabled = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소', style: TextStyle(color: outline)),
        ),
        FilledButton.icon(
          onPressed: () async {
            await _saveSettings();
            if (_alarmEnabled) {
              await NotificationService.instance
                  .scheduleWateringAlarm(_hour24, _minute);
            } else {
              await NotificationService.instance.cancelWateringAlarm();
            }
            if (context.mounted) Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          icon: Icon(Icons.save_outlined, size: 16, color: outline),
          label: Text('저장', style: TextStyle(color: outline)),
        ),
      ],
    );
  }
}
