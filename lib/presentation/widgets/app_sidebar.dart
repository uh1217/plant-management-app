import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:plantapp_p/presentation/app_colors.dart';
import 'package:plantapp_p/presentation/app_theme.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';

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

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final TextEditingController _searchCtrl = TextEditingController();

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

  List<String> get _allCategories {
    final cats = <String>{};
    for (final plant in widget.viewModel.plants) {
      cats.addAll(plant.categories);
    }
    return cats.toList()..sort();
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
                              widget.selectedCategory == null,
                          onTap: widget.onAllPlants,
                        ),
                        // 설정
                        _buildMenuItem(
                          icon: Icons.settings_outlined,
                          label: '설정',
                          isSelected: false,
                          onTap: widget.onSettings,
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
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String category) {
    final isSelected = widget.selectedCategory == category;
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
            Text(
              category,
              style: TextStyle(
                fontSize: 14,
                color: isSelected
                    ? colorScheme.secondary
                    : colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
