import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/presentation/utils/image_helpers.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';
import 'package:plantapp_p/presentation/views/input_screen.dart';
import 'package:plantapp_p/presentation/widgets/app_sidebar.dart';
import 'package:plantapp_p/presentation/widgets/plant_list_card.dart';

// 메인 컨테이너: 식물 목록, 수정 다이얼로그, 사이드바, 검색, 카테고리 필터링
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSidebarOpen = false;
  String? _selectedCategory;
  Set<String> _selectedPlantIds = {};
  String _activeSearchQuery = '';

  HomeViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.addListener(_onVmChanged);
    _initializeApp();
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeApp() async {
    await _requestInitialPermissions();
    await _vm.loadPlants();
  }

  // ── Plant Operations ──────────────────────────────────────────────────────

  Future<void> _addPlant(Plant plant) async {
    await _vm.savePlant(plant);
    // loadPlants는 _openInputScreen의 .then()에서 처리하므로 여기선 생략
  }

  Future<void> _updatePlant(Plant updatedPlant) async {
    await _vm.savePlant(updatedPlant);
    await _vm.loadPlants();
  }

  Future<void> _deletePlant(String plantId) async {
    await _vm.deletePlant(plantId);
    await _vm.loadPlants();
    setState(() => _selectedPlantIds.remove(plantId));
  }

  Future<void> _handleWaterSelectedPlants() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _vm.waterPlants(_selectedPlantIds, today);
    setState(() => _selectedPlantIds.clear());
  }

  Future<void> _handleFertilizeSelectedPlants() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _vm.fertilizePlants(_selectedPlantIds, today);
    setState(() => _selectedPlantIds.clear());
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
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
    return _vm.plants.where((p) {
      if (_activeSearchQuery.isNotEmpty) {
        return p.name
            .toLowerCase()
            .contains(_activeSearchQuery.toLowerCase());
      }
      if (_selectedCategory != null) {
        return p.categories.contains(_selectedCategory);
      }
      return true;
    }).toList();
  }

  // ── Navigate to InputScreen ───────────────────────────────────────────────

  void _openInputScreen() {
    setState(() => _isSidebarOpen = false);
    Navigator.push(
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
    ).then((_) async {
      // InputScreen이 pop된 직후 HomeScreen이 활성화된 상태에서 데이터 재로드
      // → notifyListeners → _onVmChanged → setState 순으로 즉시 반영 보장
      await _vm.loadPlants();
    });
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
            maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                    Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            final confirmed =
                                await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('식물 삭제'),
                                content: Text(
                                    '${plant.name}을(를) 삭제하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      '삭제',
                                      style: TextStyle(
                                          color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) {
                              Navigator.pop(ctx);
                              await _deletePlant(plant.id);
                            }
                          },
                          child: const Text(
                            '삭제',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
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
                    onAllPlants: () => _selectCategory(null),
                    onSelectCategory: _selectCategory,
                    onSearch: (query) => setState(() {
                      _activeSearchQuery = query;
                      _selectedCategory = null;
                      _isSidebarOpen = false;
                    }),
                    onSettings: () {
                      setState(() => _isSidebarOpen = false);
                      showAppSettingsDialog(context);
                    },
                    onUsageGuide: () {
                      setState(() => _isSidebarOpen = false);
                      showAppUsageGuide(context);
                    },
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_florist_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              _activeSearchQuery.isNotEmpty
                  ? '검색 결과가 없습니다.'
                  : '등록된 식물이 없습니다.',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5)),
            ),
            if (_activeSearchQuery.isEmpty) ...[
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPlants.length,
      itemBuilder: (_, index) {
        final plant = _filteredPlants[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PlantListCard(
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
          ),
        );
      },
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
                IconButton(
                  onPressed: () =>
                      setState(() => _isSidebarOpen = true),
                  icon: Icon(Icons.menu, color: colorScheme.onSurface),
                  padding: const EdgeInsets.all(8),
                ),
                Text(
                  _selectedCategory ?? '내 식물',
                  style: TextStyle(
                    fontSize: 18,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
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
    _lastWatered = p.lastWatered.isNotEmpty
        ? p.lastWatered
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
    if (xFile != null && mounted) {
      final compressed = await compressImage(xFile.path);
      setState(() => _imageUrl = compressed);
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
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: '카테고리 이름 입력'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null &&
        result.isNotEmpty &&
        !_categories.contains(result)) {
      setState(() => _categories.add(result));
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
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: _imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(_imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildImagePlaceholder(colorScheme),
                        ),
                      )
                    : _buildImagePlaceholder(colorScheme),
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

          // 마지막 물 준 날짜
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 20,
                      color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '마지막으로 물 준 날짜',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _lastWatered,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 메모
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메모',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // 수정하기 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '카테고리',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (_categories.length < 5)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.add,
                        size: 20, color: colorScheme.primary),
                    onPressed: _addCategory,
                    tooltip: '카테고리 추가 (최대 5개)',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '최대 5개',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            colorScheme.onSurface.withOpacity(0.4)),
                  ),
                ),
            ],
          ),
          if (_categories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '+ 버튼으로 카테고리를 추가하세요 (최대 5개)',
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.4)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
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
            ),
        ],
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
