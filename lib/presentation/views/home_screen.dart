import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/presentation/utils/image_helpers.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';
import 'package:plantapp_p/presentation/views/input_screen.dart';
import 'package:plantapp_p/presentation/widgets/app_sidebar.dart';
import 'package:plantapp_p/presentation/widgets/plant_list_card.dart';
import 'package:plantapp_p/presentation/widgets/weather_recommendation_card.dart';

// 메인 컨테이너: 식물 목록, 수정 다이얼로그, 사이드바, 검색, 카테고리 필터링
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSidebarOpen = false;
  bool _isDragging = false;
  String? _selectedCategory;
  String? _selectedDate;
  Set<String> _selectedPlantIds = {};
  String _activeSearchQuery = '';

  // ── 사용자 가이드 ─────────────────────────────────────────────────────────
  late final ShowcaseView _showcaseView;
  int _guideStep = 0; // 0=비활성, 1~7=활성 단계

  // Phase 1: 홈 화면 사이드바 조작
  final GlobalKey _menuBtnKey = GlobalKey(debugLabel: 'guide_menuBtn');
  final GlobalKey _sidebarInputMenuKey =
      GlobalKey(debugLabel: 'guide_sidebarInput');
  final GlobalKey _sidebarBodyKey =
      GlobalKey(debugLabel: 'guide_sidebarBody');

  // Phase 3: 리스트 관리
  final GlobalKey _plantCardKey = GlobalKey(debugLabel: 'guide_plantCard');
  final GlobalKey _actionBtnsKey = GlobalKey(debugLabel: 'guide_actionBtns');

  HomeViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onVmChanged);
    _initializeApp();
    _showcaseView = ShowcaseView.register(
      scope: 'home',
      onComplete: _onGuideStepComplete,
      globalTooltipActionConfig: const TooltipActionConfig(
        position: TooltipActionPosition.outside,
        alignment: MainAxisAlignment.end,
      ),
    );
  }

  @override
  void dispose() {
    _showcaseView.unregister();
    _vm.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  // ── 사용자 가이드 로직 ────────────────────────────────────────────────────

  /// 사이드바 "사용 가이드" 탭 시 호출
  void startUserGuide() {
    if (!mounted) return;
    _guideStep = 1;
    _showcaseView.startShowCase([_menuBtnKey]);
  }

  /// showcaseView.onComplete — 각 step 완료 시 호출
  void _onGuideStepComplete(int? index, GlobalKey key) {
    if (_guideStep == 0) return;
    _guideStep++;
    _advanceGuide();
  }

  void _advanceGuide() {
    if (!mounted) return;
    if (_guideStep == 2) {
      // Step 1 완료: 사이드바 자동 오픈 → 입력 메뉴 강조
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _isSidebarOpen = true);
        await Future.delayed(const Duration(milliseconds: 420));
        if (mounted) _showcaseView.startShowCase([_sidebarInputMenuKey]);
      });
    } else if (_guideStep == 3) {
      // Step 2 완료: 사이드바 기능+카테고리 영역 강조
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showcaseView.startShowCase([_sidebarBodyKey]);
      });
    } else if (_guideStep == 4) {
      // Step 3 완료: 사이드바 닫고 입력 화면으로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _isSidebarOpen = false);
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) _openGuideInputScreen();
      });
    } else if (_guideStep == 5) {
      // Phase 2 복귀 후: 식물 카드 강조 (또는 없으면 안내 후 종료)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (_filteredPlants.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '가이드 완료! 식물을 추가하면 카드 관리 기능을 이용할 수 있어요 🌱'),
              duration: Duration(seconds: 4),
            ),
          );
          _guideStep = 0;
          return;
        }
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _showcaseView.startShowCase([_plantCardKey]);
      });
    } else if (_guideStep == 6) {
      // Step 5 완료: 물주기·비료 버튼 강조
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showcaseView.startShowCase([_actionBtnsKey]);
      });
    } else if (_guideStep == 7) {
      // 가이드 완료
      _guideStep = 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('가이드 완료! 사이드바에서 언제든 다시 볼 수 있어요 🎉'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      _guideStep = 0;
    }
  }

  /// Phase 2: 입력 화면 (가이드 모드) 이동 및 Phase 3 시작
  Future<void> _openGuideInputScreen() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => InputScreen(
          viewModel: _vm,
          onSave: _addPlant,
          guideMode: true,
          onSearchRequested: (query) => setState(() {
            _activeSearchQuery = query;
            _selectedCategory = null;
          }),
          onCategoryRequested: (cat) => setState(() {
            _selectedCategory = cat;
            _activeSearchQuery = '';
          }),
        ),
      ),
    );
    if (!mounted) return;
    await _vm.loadPlants();
    _guideStep = 5;
    _advanceGuide();
  }

  Future<void> _initializeApp() async {
    await _requestInitialPermissions();
    await _vm.loadWeatherRecommendationSetting();
    await _vm.loadPlants();
    // 식물 목록 로드 후 날씨 추천 카드 비동기 로드 (UI 블로킹 없음)
    _vm.loadWeatherRecommendation();
  }

  // ── Plant Operations ──────────────────────────────────────────────────────

  Future<void> _addPlant(Plant plant) async {
    await _vm.savePlant(plant);
  }


  // 이전 — .then() 콜백은 mounted 체크 없이 실행, 예외 시 조용히 실패
  
// 이후 — await로 pop을 명시적으로 기다린 뒤, mounted 확인 후 loadPlants
  Future<void> _updatePlant(Plant updatedPlant) async {
    await _vm.savePlant(updatedPlant);
    await _vm.loadPlants();
    if (!mounted) return;  // 위젯이 살아있을 때만 실행
    setState(() {});  // → notifyListeners → setState → 리빌드
  }

  Future<void> _deletePlant(String plantId) async {
    await _vm.deletePlant(plantId);
    await _vm.loadPlants();
    if (!mounted) return;
    setState(() => _selectedPlantIds.remove(plantId));
  }

  Future<void> _handleWaterSelectedPlants() async {
    final today = DateTime.now().toIso8601String();
    await _vm.waterPlants(_selectedPlantIds, today);
    if (!mounted) return;
    setState(() => _selectedPlantIds.clear());
  }

  Future<void> _handleFertilizeSelectedPlants() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _vm.fertilizePlants(_selectedPlantIds, today);
    if (!mounted) return;
    setState(() => _selectedPlantIds.clear());
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      _selectedDate = null;
      _activeSearchQuery = '';
      _isSidebarOpen = false;
    });
  }

  void _selectDateFilter(String isoDate) {
    setState(() {
      _selectedDate = isoDate;
      _selectedCategory = null;
      _activeSearchQuery = '';
      _isSidebarOpen = false;
    });
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<void> _requestInitialPermissions() async {
    final photosStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;
    if (photosStatus.isGranted ||
        photosStatus.isLimited ||
        storageStatus.isGranted) {
      return;
    }
    final statuses =
        await [Permission.photos, Permission.storage].request();
    final np = statuses[Permission.photos];
    final ns = statuses[Permission.storage];
    if (np != null && np.isPermanentlyDenied ||
        ns != null && ns.isPermanentlyDenied) {
      debugPrint('갤러리 권한 거부됨. 설정에서 허용해 주세요.');
    }
  }

  // ── Computed Getters ──────────────────────────────────────────────────────

  List<Plant> get _filteredPlants {
    final plants = _vm.plants.where((p) {
      if (_activeSearchQuery.isNotEmpty) {
        return p.name
            .toLowerCase()
            .contains(_activeSearchQuery.toLowerCase());
      }
      if (_selectedDate != null) {
        return p.wateringHistory
            .any((h) => h.startsWith(_selectedDate!));
      }
      if (_selectedCategory != null) {
        return p.categories.contains(_selectedCategory);
      }
      return true;
    }).toList();


    //초 단위 계산산
    int secondsUntilWatering(Plant p) {
      final last = DateTime.tryParse(p.lastWatered);
      if (last == null) return p.wateringFrequency * 86400;
      return p.wateringFrequency * 86400 -
          DateTime.now().difference(last).inSeconds;
    }

    plants.sort((a, b) {
      final cmp =
          secondsUntilWatering(a).compareTo(secondsUntilWatering(b));
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

    return plants;
  }

  // ── Navigate to InputScreen ───────────────────────────────────────────────

  Future<void> _openInputScreen() async {
    setState(() => _isSidebarOpen = false);
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => InputScreen(
          viewModel: _vm,
          onSave: _addPlant,
          onSearchRequested: (query) => setState(() {
            _activeSearchQuery = query;
            _selectedCategory = null;
          }),
          onCategoryRequested: (cat) => setState(() {
            _selectedCategory = cat;
            _activeSearchQuery = '';
          }),
        ),
      ),
    );
    if (!mounted) return;
    await _vm.loadPlants();
  }


  // ── Edit Dialog ───────────────────────────────────────────────────────────

  void _showEditDialog(Plant plant) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
          constraints: BoxConstraints(
            // 바깥 context 대신 다이얼로그 전용 ctx 사용 → _dependents.isEmpty 오류 방지
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 고정 헤더
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '식물 수정',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    // 삭제 기능은 카드 드래그(삭제 존 드롭)로 통일 — 헤더 삭제 버튼 제거
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 스크롤 가능한 폼
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _EditPlantFormContent(
                      plant: plant,
                      onSave: (updated) {
                        Navigator.pop(ctx);
                        _updatePlant(updated);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 20,
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildListContent()),
                ],
              ),

              // Overlay
              if (_isSidebarOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _isSidebarOpen = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      color: Colors.black
                          .withOpacity(isDark ? 0.7 : 0.5),
                    ),
                  ),
                ),

              // 드래그 중 삭제 존(하단 100px) 제외 영역에 40% 음영 오버레이
              // IgnorePointer로 감싸 드래그 제스처를 방해하지 않음
              if (_isDragging)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 100,
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                    ),
                  ),
                ),

              // Delete Drop Zone
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                bottom: _isDragging ? 0 : -120,
                height: 100,
                child: DragTarget<Plant>(
                  onAcceptWithDetails: (details) async {
                    setState(() => _isDragging = false);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('식물 삭제'),
                        content: const Text('정말 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              '삭제',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && mounted) {
                      await _deletePlant(details.data.id);
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = candidateData.isNotEmpty;
                    // 기본색 rgb(219,25,25) / 호버 시 약 20% 어둡게
                    const deleteColor = Color(0xFFDB1919);
                    const deleteColorHover = Color(0xFFAF1414);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isHovered ? deleteColorHover : deleteColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: deleteColor.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isHovered
                                  ? Icons.delete_forever
                                  : Icons.delete_outline,
                              color: Colors.white,
                              size: isHovered ? 38 : 30,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isHovered ? '놓으세요!' : '여기에 놓으면 삭제됩니다',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: isHovered ? 15 : 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Sidebar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: _isSidebarOpen ? 0 : -264,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 264,
                  child: AppSidebar(
                    viewModel: _vm,
                    selectedCategory: _selectedCategory,
                    isInputActive: false,
                    onClose: () =>
                        setState(() => _isSidebarOpen = false),
                    onNavigateToInput: _openInputScreen,
                    onAllPlants: () {
                      setState(() {
                        _selectedCategory = null;
                        _selectedDate = null;
                        _activeSearchQuery = '';
                        _isSidebarOpen = false;
                      });
                    },
                    onSelectCategory: _selectCategory,
                    onSearch: (query) => setState(() {
                      _activeSearchQuery = query;
                      _selectedCategory = null;
                      _selectedDate = null;
                      _isSidebarOpen = false;
                    }),
                    onDateSearch: _selectDateFilter,
                    selectedDate: _selectedDate,
                    onSettings: () {
                      setState(() => _isSidebarOpen = false);
                      showAppSettingsDialog(context);
                    },
                    onUsageGuide: () {
                      setState(() => _isSidebarOpen = false);
                      Future.delayed(
                        const Duration(milliseconds: 300),
                        () { if (mounted) startUserGuide(); },
                      );
                    },
                    guideInputMenuKey: _sidebarInputMenuKey,
                    guideSidebarBodyKey: _sidebarBodyKey,
                    onLogout: () async {
                      setState(() => _isSidebarOpen = false);
                      await _vm.signOut();
                    },
                    onContactEmail: () => sendAppEmail(context),
                    onAppInfo: () => showAppInfo(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── List Content ──────────────────────────────────────────────────────────

  Widget _buildListContent() {
    if (_vm.status == HomeUiStatus.loading && _vm.plants.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vm.status == HomeUiStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(_vm.errorMessage ?? '오류가 발생했습니다.'),
            TextButton(
              onPressed: _vm.loadPlants,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredPlants.isEmpty) {
      final emptyMessage = _activeSearchQuery.isNotEmpty
          ? '검색 결과가 없습니다.'
          : _selectedDate != null
              ? '$_selectedDate에 물을 준 식물이 없습니다.'
              : '등록된 식물이 없습니다.';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedDate != null
                  ? Icons.water_drop_outlined
                  : Icons.local_florist_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5)),
              textAlign: TextAlign.center,
            ),
            if (_activeSearchQuery.isEmpty && _selectedDate == null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _openInputScreen,
                child: const Text('첫 번째 식물 추가하기'),
              ),
            ],
          ],
        ),
      );
    }

    // 날씨 추천 카드 표시 조건: 전체 식물(카테고리·날짜·검색 없음) + 설정 ON
    final showWeatherCard = _selectedCategory == null &&
        _selectedDate == null &&
        _activeSearchQuery.isEmpty &&
        _vm.weatherRecommendationEnabled &&
        (_vm.recommendationText != null ||
            _vm.recommendationStatus == RecommendationStatus.loading);

    return CustomScrollView(
      slivers: [
        if (showWeatherCard)
          SliverToBoxAdapter(
            child: WeatherRecommendationCard(
              viewModel: _vm,
              onRetry: () => _vm.loadWeatherRecommendation(),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              16, showWeatherCard ? 8 : 16, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, index) {
                final plant = _filteredPlants[index];
                final card = PlantListCard(
                  plant: plant,
                  isSelected: _selectedPlantIds.contains(plant.id),
                  onSelect: () => setState(() {
                    if (_selectedPlantIds.contains(plant.id)) {
                      _selectedPlantIds.remove(plant.id);
                    } else {
                      _selectedPlantIds.add(plant.id);
                    }
                  }),
                  onEdit: () => _showEditDialog(plant),
                  onUpdate: _updatePlant,
                  onDragStarted: () =>
                      setState(() => _isDragging = true),
                  onDragEnded: () =>
                      setState(() => _isDragging = false),
                );
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Showcase(
                      key: _plantCardKey,
                      title: '식물 카드',
                      description:
                          '탭: 선택  ·  더블탭: 편집\n길게 누른 후 드래그: 삭제',
                      tooltipBackgroundColor: Colors.white,
                      textColor: Colors.black87,
                      tooltipActions: const [
                        TooltipActionButton(
                          type: TooltipDefaultActionType.next,
                          name: '다음',
                        ),
                      ],
                      child: card,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: card,
                );
              },
              childCount: _filteredPlants.length,
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Showcase(
                  key: _menuBtnKey,
                  title: '사이드바',
                  description:
                      '탭하면 사이드바가 열립니다.\n다양한 기능에 접근해보세요!',
                  tooltipBackgroundColor: Colors.white,
                  textColor: Colors.black87,
                  tooltipActions: const [
                    TooltipActionButton(
                      type: TooltipDefaultActionType.next,
                      name: '다음',
                    ),
                  ],
                  child: IconButton(
                    onPressed: () =>
                        setState(() => _isSidebarOpen = true),
                    icon: Icon(Icons.menu, color: colorScheme.onSurface),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                Text(
                  _activeSearchQuery.isNotEmpty
                      ? "'$_activeSearchQuery' 검색"
                      : _selectedDate != null
                          ? '물주기 $_selectedDate'
                          : (_selectedCategory ?? '내 식물'),
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Showcase(
                  key: _actionBtnsKey,
                  title: '물주기 / 비료',
                  description:
                      '카드를 탭해 식물을 선택한 후\n이 버튼으로 물주기·비료 기록을 남기세요',
                  tooltipBackgroundColor: Colors.white,
                  textColor: Colors.black87,
                  tooltipActions: const [
                    TooltipActionButton(
                      type: TooltipDefaultActionType.next,
                      name: '완료',
                    ),
                  ],
                  child: Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.eco,
                        color: colorScheme.secondary,
                        onPressed: _selectedPlantIds.isEmpty
                            ? null
                            : _handleFertilizeSelectedPlants,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.water_drop,
                        color: colorScheme.primary,
                        onPressed: _selectedPlantIds.isEmpty
                            ? null
                            : _handleWaterSelectedPlants,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withOpacity(0.5),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(40, 36),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6)),
      ),
      child: Icon(icon, size: 16),
    );
  }
}

// ── Edit Plant Form ───────────────────────────────────────────────────────────
// 수정 Dialog 내부 폼 (삭제 버튼은 Dialog 헤더에서 관리)
class _EditPlantFormContent extends StatefulWidget {
  const _EditPlantFormContent({
    required this.plant,
    required this.onSave,
  });

  final Plant plant;
  final void Function(Plant) onSave;

  @override
  State<_EditPlantFormContent> createState() =>
      _EditPlantFormContentState();
}

class _EditPlantFormContentState
    extends State<_EditPlantFormContent> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _freqCtrl;
  late TextEditingController _notesCtrl;
  late List<String> _categories;
  late String _imageUrl;
  bool _isUploading = false;
  late String _lastWatered;

  @override
  void initState() {
    super.initState();
    final p = widget.plant;
    _nameCtrl = TextEditingController(text: p.name);
    _freqCtrl =
        TextEditingController(text: p.wateringFrequency.toString());
    _notesCtrl = TextEditingController(text: p.notes);
    _categories = List.from(p.categories);
    _imageUrl = p.imageUrl;
    // ISO 8601 전체 문자열이 저장된 경우에도 날짜 부분(yyyy-MM-dd)만 추출
    _lastWatered = p.lastWatered.isNotEmpty
        ? p.lastWatered.split('T')[0]
        : DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _freqCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final status = await Permission.photos.request();
    if (!status.isGranted && !status.isLimited) {
      if (mounted) showPermissionRequestDialog(context);
      return;
    }
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final compressed = await compressImage(xFile.path);
      final url = await uploadImageToStorage(compressed);
      if (mounted) setState(() => _imageUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 업로드에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _selectDate() async {
    final initial =
        DateTime.tryParse(_lastWatered) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() =>
          _lastWatered = picked.toIso8601String().split('T')[0]);
    }
  }

  Future<void> _addCategory() async {
    if (_categories.length >= 5) return;
    // 컨트롤러 생명주기를 _AddCategoryDialog StatefulWidget에 위임
    // → 다이얼로그 닫기 애니메이션 완료 후 Flutter가 안전하게 dispose 호출
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddCategoryDialog(),
    );
    if (result != null &&
        result.isNotEmpty &&
        !_categories.contains(result)) {
      if (mounted) setState(() => _categories.add(result));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final updated = Plant(
      id: widget.plant.id,
      imageUrl: _imageUrl,
      name: _nameCtrl.text.trim(),
      categories: List.from(_categories),
      wateringFrequency:
          int.tryParse(_freqCtrl.text.trim()) ?? 1,
      lastWatered: _lastWatered,
      wateringHistory: widget.plant.wateringHistory,
      fertilizerHistory: widget.plant.fertilizerHistory,
      notes: _notesCtrl.text.trim(),
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 사진
          Center(
            child: GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _imageUrl.isNotEmpty
                            ? (_imageUrl.startsWith('http')
                                ? Image.network(
                                    _imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildImagePlaceholder(colorScheme),
                                  )
                                : Image.file(
                                    File(_imageUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildImagePlaceholder(colorScheme),
                                  ))
                            : _buildImagePlaceholder(colorScheme),
                      ),
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 이름
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '식물 이름 *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty)
                    ? '이름을 입력하세요'
                    : null,
          ),
          const SizedBox(height: 12),

          // 카테고리
          _buildCategoryField(colorScheme),
          const SizedBox(height: 12),

          // 물 주기
          TextFormField(
            controller: _freqCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '물 주기 (일) *',
              hintText: '예: 7',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final n = int.tryParse(v?.trim() ?? '');
              if (n == null || n <= 0) return '1 이상의 숫자를 입력하세요';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 마지막 물 준 날짜 — InputDecorator 로 라벨을 OutlineInputBorder 상단에 고정
          GestureDetector(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '마지막으로 물 준 날짜',
                border: const OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                prefixIcon: Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 16),
              ),
              child: Text(
                _lastWatered,
                style: TextStyle(
                    fontSize: 16, color: colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 메모 — floatingLabelBehavior.always 로 라벨을 항상 상단 테두리에 고정
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메모',
              hintText: '식물에 대한 메모를 입력하세요',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
          const SizedBox(height: 24),

          // 수정하기 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('수정하기',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCategoryField(ColorScheme colorScheme) {
    // InputDecorator 로 라벨을 OutlineInputBorder 상단에 고정
    // 추가 버튼은 suffixIcon 으로 배치해 라벨과 겹치지 않게 처리
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '카테고리',
        border: const OutlineInputBorder(),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        suffixIcon: _categories.length < 5
            ? IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.add,
                    size: 20, color: colorScheme.primary),
                onPressed: _addCategory,
                tooltip: '카테고리 추가 (최대 5개)',
              )
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(
                  alignment: Alignment.center,
                  widthFactor: 1.0,
                  child: Text(
                    '최대 5개',
                    style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withOpacity(0.4)),
                  ),
                ),
              ),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
      child: _categories.isEmpty
          ? Text(
              '+ 버튼으로 카테고리를 추가하세요 (최대 5개)',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.4)),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _categories
                  .map(
                    (cat) => Chip(
                      label: Text(cat,
                          style: const TextStyle(fontSize: 13)),
                      onDeleted: () =>
                          setState(() => _categories.remove(cat)),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildImagePlaceholder(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 40, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          '사진 추가',
          style: TextStyle(
              fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── 카테고리 추가 다이얼로그 ───────────────────────────────────────────────────
// TextEditingController를 StatefulWidget 내부에서 관리해
// 다이얼로그 닫기 애니메이션이 끝난 뒤 Flutter가 dispose()를 보장하도록 함
// → "TextEditingController used after being disposed" 오류 방지
class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('카테고리 추가'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(hintText: '카테고리 이름 입력'),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('추가'),
        ),
      ],
    );
  }
}
