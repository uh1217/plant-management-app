import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:plantapp_p/core/services/notification_service.dart';
import 'package:plantapp_p/presentation/app_colors.dart';
import 'package:plantapp_p/presentation/app_theme.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';
import 'package:plantapp_p/presentation/widgets/plant_agent_dialog.dart';

// ── 공용 다이얼로그 / 앱 액션 함수 ─────────────────────────────────────────────

void showAppSettingsDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setDialogState) {
        bool isDarkMode =
            AppTheme.themeNotifier.value == ThemeMode.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('설정',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('다크 모드'),
                subtitle: Text(
                    isDarkMode ? '다크 테마 사용 중' : '밝은 테마 사용 중'),
                value: isDarkMode,
                activeColor: AppColors.primaryBlue,
                onChanged: (value) async {
                  AppTheme.themeNotifier.value =
                      value ? ThemeMode.dark : ThemeMode.light;
                  await AppTheme.saveTheme(value);
                  setDialogState(() {});
                },
              ),
              const Divider(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    ),
  );
}

void showAppUsageGuide(BuildContext context) {
  final guideImages = [
    'assets/images/6.jpg',
    'assets/images/7.jpg',
    'assets/images/8.jpg',
    'assets/images/9.jpg',
    'assets/images/10.jpg',
  ];
  final pageController = PageController();
  showDialog<void>(
    context: context,
    builder: (_) {
      int currentPage = 0;
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final screenSize = MediaQuery.of(ctx).size;
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: screenSize.width * 0.85,
              height: screenSize.height * 0.7,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: guideImages.length,
                    onPageChanged: (p) =>
                        setDialogState(() => currentPage = p),
                    itemBuilder: (_, i) => InteractiveViewer(
                      child: Image.asset(guideImages[i],
                          fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor:
                          Colors.black.withOpacity(0.5),
                      radius: 18,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        guideImages.length,
                        (i) => AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 4),
                          height: 8,
                          width: currentPage == i ? 20 : 8,
                          decoration: BoxDecoration(
                            color: currentPage == i
                                ? Colors.white
                                : Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showPrivacyPolicy(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('개인정보 처리 방침'),
      content: const SingleChildScrollView(
        child: Text(
          '1. 본 앱은 사용자가 입력한 식물 정보를 Firebase에 안전하게 보관합니다.\n\n'
          '2. 사용자의 이메일 등 개인 식별 정보는 문의하기 기능을 이용할 때 외에는 수집하지 않습니다.\n\n'
          '3. 권한 수집 안내\n'
          '- 사용자는 식물 사진 등록을 위해 갤러리 접근 권한을 허용할 수 있습니다.\n'
          '- 선택 권한은 거부하더라도 앱의 다른 기능은 이용 가능하지만, 사진 등록 기능은 제한될 수 있습니다.',
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

void showAppInfo(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: '식물 관리 앱 (Plant Management App)',
    applicationVersion: '1.1.1',
    applicationIcon: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/images/PlantApp_Icon.png',
        width: 50,
        height: 50,
      ),
    ),
    applicationLegalese:
        '© ${DateTime.now().year} 이유현. All rights reserved.',
    children: [
      const SizedBox(height: 20),
      const Text('기본 이미지 및 사진 삽입 배경 이미지 출처',
          style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('Designed by Freepik'),
      const SizedBox(height: 15),
      const Text('개발자 문의',
          style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('• 이메일: yoohyun031217@gmail.com'),
      const SizedBox(height: 15),
      TextButton(
        onPressed: () => _showPrivacyPolicy(context),
        child: const Text('개인정보 처리 방침 확인하기'),
      ),
    ],
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
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, size: 20),
            SizedBox(width: 8),
            Text('설정'),
          ],
        ),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              showAppSettingsDialog(context);
            },
            child: const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('테마 설정'),
              subtitle: Text('라이트 / 다크 모드'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              showDialog<void>(
                context: context,
                builder: (_) => const _AlarmSettingsDialog(),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.alarm),
              title: Text('알람 설정'),
              subtitle: Text('알람 시간 및 켜기 / 끄기'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
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
        color: colorScheme.surface,
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
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  primary: false,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        // 입력 화면
                        _buildMenuItem(
                          icon: Icons.add_circle_outline,
                          label: '입력 화면',
                          isSelected: widget.isInputActive,
                          onTap: widget.isInputActive
                              ? widget.onClose
                              : (widget.onNavigateToInput ??
                                  widget.onClose),
                        ),
                        // 전체 식물
                        _buildMenuItem(
                          icon: Icons.list,
                          label: '전체 식물',
                          isSelected: !widget.isInputActive &&
                              widget.selectedCategory == null &&
                              widget.selectedDate == null,
                          onTap: widget.onAllPlants,
                        ),
                        // 날짜 기반 검색
                        if (widget.onDateSearch != null)
                          _buildMenuItem(
                            icon: Icons.calendar_month_outlined,
                            label: '날짜 기반 검색',
                            isSelected: widget.selectedDate != null,
                            onTap: () => _pickDateAndSearch(context),
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
                        // 식물 Agent (AI 챗봇)
                        _buildAgentMenuItem(context),
                        // 설정
                        _buildMenuItem(
                          icon: Icons.settings_outlined,
                          label: '설정',
                          isSelected: false,
                          onTap: () => _showSettingsMenu(context),
                        ),
                        // 사용 가이드
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          label: '사용 가이드',
                          isSelected: false,
                          onTap: widget.onUsageGuide,
                        ),
                        // 로그아웃
                        _buildMenuItem(
                          icon: Icons.logout,
                          label: '로그아웃',
                          isSelected: false,
                          onTap: widget.onLogout,
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
                                color: colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: '식물 이름 검색',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface
                                    .withOpacity(0.4),
                              ),
                              prefixIcon: GestureDetector(
                                onTap: _handleSearch,
                                child: Icon(Icons.search,
                                    size: 20,
                                    color: colorScheme.onSurface
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
                        if (_allCategories.isNotEmpty) ...[
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
                                  color: colorScheme.onSurface
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

                        const Divider(),
                        ListTile(
                          leading: const Icon(
                              Icons.contact_support_outlined),
                          title: const Text('고객 문의'),
                          subtitle: const Text(
                            '불편한 점이나 제안사항을 보내주세요',
                            style: TextStyle(fontSize: 12),
                          ),
                          onTap: widget.onContactEmail,
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.info_outline),
                          title: const Text('앱 정보'),
                          onTap: widget.onAppInfo,
                        ),
                      ],
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

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
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
                  : colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
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
                  : colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected
                      ? colorScheme.secondary
                      : colorScheme.onSurface.withOpacity(0.7),
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
                    : colorScheme.onSurface.withOpacity(0.3),
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
    final minuteStr = _minute.toString().padLeft(2, '0');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      title: const Row(
        children: [
          Icon(Icons.alarm),
          SizedBox(width: 8),
          Text('알람 설정', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                      color: colorScheme.onSurface
                                          .withOpacity(0.5),
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
                                color: colorScheme.onSurface,
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
                                      color: colorScheme.onSurface
                                          .withOpacity(0.5),
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
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: () async {
            // SharedPreferences에 설정값 저장
            await _saveSettings();
            // 알람 켜짐 → 설정 시각으로 매일 반복 알림 예약
            // 알람 꺼짐 → 기존 예약 알림 취소
            if (_alarmEnabled) {
              await NotificationService.instance
                  .scheduleWateringAlarm(_hour24, _minute);
            } else {
              await NotificationService.instance.cancelWateringAlarm();
            }
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('저장'),
        ),
      ],
    );
  }
}
