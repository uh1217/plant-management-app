import 'package:flutter/material.dart';
import '../models/plant.dart';
import '../presentation/app_colors.dart';
import 'plant_list_card.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../presentation/input_screen.dart';
import '../Data/plant_repository.dart';

// ListScreen.tsx 변환
class ListScreen extends StatefulWidget { //StatefulWidget 사용해 개별 변화 관리
  final List<Plant> plants;
  final Function(Plant) onUpdate;
  final Function(String) onDelete;
  final Set<String> selectedPlantIds;
  final Function(Set<String>) onSelectionChange;
  final Function onDataChanged;
  final bool showGuide;

  ListScreen({
    super.key,
    //HomeScreen이 넘겨주는 기능들
    required this.plants,
    required this.onUpdate,
    required this.onDelete,
    required this.selectedPlantIds,
    required this.onSelectionChange,
    required this.onDataChanged,
    this.showGuide = false,
  });

  @override
  State<ListScreen> createState() => _ListScreenState();
  //ListScreen은 틀이고 ListScreenState는 실제 상태 변화하는 실무자임
}

class _ListScreenState extends State<ListScreen> {
  bool _isDragging = false; // 드래그 중인지 확인하는 변수
   //  데이터가 바뀌었음을 알림(삭제)

  // Sort plants by urgency
  List<Plant> get _sortedPlants { //get-함수를 변수처럼 호출 가능
    final plants = List<Plant>.from(widget.plants); //부모의 위젯 데이터 순서까지 뒤엉키는거 방지
    plants.sort((a, b) {
      final aDaysUntil = _getDaysUntilWatering(a);
      final bDaysUntil = _getDaysUntilWatering(b);
      final daysComparison = aDaysUntil.compareTo(bDaysUntil);

      // 🌟 날짜가 완전히 똑같다면 (daysComparison 결과가 0이면)
      if (daysComparison == 0) {
        // 2차 정렬 기준: 식물 이름 글자 순서대로 (가나다/알파벳 순)
        return a.name.compareTo(b.name); 
      }

      // 날짜가 다르면 그대로 날짜 순 정렬 결과를 반환
      return daysComparison;
    });
    
    return plants;
  }

  int _getDaysUntilWatering(Plant plant) { //물 주기 계산
    final lastWatered = DateTime.parse(plant.lastWatered);
    final today = DateTime.now();
    final daysSinceWatered = today.difference(lastWatered).inDays;
    return plant.wateringFrequency - daysSinceWatered;
  }

  void _toggleSelection(String plantId) { //체크박스 선택및 해제
    final newSelection = Set<String>.from(widget.selectedPlantIds); //부모로 부터 현재 선택된 ID들 받음(복사본)
    if (newSelection.contains(plantId)) {
      newSelection.remove(plantId);
    } else {
      newSelection.add(plantId);
    }
    widget.onSelectionChange(newSelection); //HomeScreen에 전달 (선택된 식물 리스트 업데이트)
  }

  // 2. 실제 삭제를 집행하는 함수
Future<void> _executeDelete(Plant plant) async {
  // DB에서 삭제 (사용자님이 작성하신 코드 호출)
  await PlantRepository.deletePlant(plant.id); 

  // UI 리스트에서 즉시 제거하여 화면 갱신
  setState(() {
    _sortedPlants.removeWhere((p) => p.id == plant.id);
  });

  // 🚨 가장 중요: 삭제 후 '오늘 물 줄 식물 개수' 알람 다시 계산
  // 이 함수는 이전에 우리가 만든 알람 갱신 로직입니다.
  widget.onDataChanged();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${plant.name}이(가) 삭제되었습니다.')),
  );
}

  // 1. 삭제 확인 팝업을 먼저 띄웁니다.
void _confirmDelete(Plant plant) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('식물 삭제'),
      content: Text('${plant.name}을(를) 정말 삭제할까요?\n삭제된 정보는 복구할 수 없습니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // 취소
          child: const Text('취소', style: TextStyle(color: AppColors.gray600)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _executeDelete(plant); // 실제 삭제 실행
          },
          child: const Text('삭제', style: TextStyle(color: AppColors.statusRed)),
        ),
      ],
    ),
  );
}

  void _handleEdit(Plant plant) {
  // 1. 기존 데이터로 컨트롤러 및 임시 변수 초기화
  final nameController = TextEditingController(text: plant.name);
  final frequencyController = TextEditingController(text: plant.wateringFrequency.toString());
  final notesController = TextEditingController(text: plant.notes);
  final categoryController = TextEditingController();
  // 팝업 내부에서만 사용할 임시 상태 변수들 (초기 1회 설정)
  // 갤러리 이미지 경로와 카테고리 리스트
  String currentImageUrl = plant.imageUrl; 
  List<String> tempCategories = List<String>.from(plant.categories);

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {

          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
      // 팝업 내부의 실시간 변화(사진, 칩 추가 등)를 감지하기 위한 StatefulBuilder
      return StatefulBuilder(
        builder: (context, setDialogState) {
          
          final screenSize = MediaQuery.of(context).size;

          return AlertDialog(
            backgroundColor: colorScheme.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: screenSize.width * 0.8,
              height: screenSize.height * 0.8,
              child: Column(
                children: [
                  // 제목 영역
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('식물 정보 수정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: colorScheme.onSurface,)),
                  ),
                  
                  // 스크롤 가능한 본문
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. 사진 수정 (갤러리 연동)
                          _buildSectionTitle('사진'),
const SizedBox(height: 8),
GestureDetector(
  onTap: () async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final String savedPath = await compressImage(image.path);
        // 다이얼로그 전용 상태 갱신
        setDialogState(() {
          currentImageUrl = savedPath;
        });
      }
    } catch (e) {
      print("갤러리 접근 오류: $e");
      showPermissionRequestDialog(context);
    }
  },
  child: Container(
    height: 150,
    width: double.infinity,
    decoration: BoxDecoration(
      color: colorScheme.onSurface.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      // 🌟 로컬 파일 경로만 존재한다고 가정하므로 로직 단순화
      image: currentImageUrl.trim().isNotEmpty 
          ? DecorationImage(
              image: FileImage(File(currentImageUrl)),
              fit: BoxFit.cover,
            )
          : null,
    ),
    // 🌟 이미지가 없을 때(빈 화면 방지) 보여줄 가이드 UI
    child: Stack(
      children: [
        // 1. 사진이 비었을 때만 나타나는 가이드 (아이콘 + 글씨)
        if (currentImageUrl.trim().isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: 40,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  "사진 추가하기",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

        // 2. 사진이 있을 때만 우측 하단에 나타나는 수정 버튼
        if (currentImageUrl.trim().isNotEmpty)
          Positioned( // Align 대신 Positioned를 써서 위치를 고정합니다.
            bottom: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: colorScheme.primary,
              radius: 18,
              child: const Icon(Icons.edit, size: 20, color: Colors.white),
            ),
          ),
      ],
    ),
  ),
),

                          // 2. 이름 수정
                          _buildSectionTitle('이름'),
                          TextField(controller: nameController, decoration: const InputDecoration(hintText: '식물 이름')),

                          // 3. 카테고리 관리 (칩 + 추가/삭제 + 1~5개 제한)
                          _buildSectionTitle('카테고리 (${tempCategories.length}/5)'),
                          Wrap(
                            spacing: 8,
                            children: tempCategories.map((cat) => Chip(
                              backgroundColor: colorScheme.secondary.withOpacity(0.1),
                              label: Text(cat, style: const TextStyle(fontSize: 12)),
                              onDeleted: tempCategories.length > 1 
                                ? () => setDialogState(() => tempCategories.remove(cat)) 
                                : null, // 최소 1개 제한
                            )).toList(),
                          ),
                          if (tempCategories.length < 5)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: categoryController,
                                    decoration: const InputDecoration(hintText: '새 카테고리 입력'),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle, color: colorScheme.primary),
                                  onPressed: () {
                                    if (categoryController.text.isNotEmpty) {
                                      setDialogState(() {
                                        tempCategories.add(categoryController.text);
                                        tempCategories = List.from(tempCategories);
                                        categoryController.clear();
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),

                          // 4. 물 주기
                          _buildSectionTitle('물 주기 (일)'),
                          TextField(
                            controller: frequencyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(suffixText: '일마다'),
                          ),

                          // 5. 특이사항
                          _buildSectionTitle('특이사항'),
                          TextField(
                            controller: notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // 하단 버튼
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () { //수정 버튼 누르면 수정된 결과 updateplant에 담음
                            final cleanCategories = tempCategories
                            .map((e) => e.trim())         // 앞뒤 공백 제거
                            .where((e) => e.isNotEmpty)    // 혹시 모를 빈 문자열 제거
                            .toSet()                      // 중복 제거 (핵심!)
                            .toList();                    // 다시 리스트로 변환
                            
                            final updatedPlant = Plant(
                              id: plant.id,
                              name: nameController.text,
                              imageUrl: currentImageUrl,
                              categories: cleanCategories,
                              wateringFrequency: int.tryParse(frequencyController.text) ?? plant.wateringFrequency,
                              lastWatered: plant.lastWatered,
                              notes: notesController.text,
                              wateringHistory: plant.wateringHistory,
                              fertilizerHistory: plant.fertilizerHistory,
                            );
                            widget.onUpdate(updatedPlant); //수정 결과 반영
                            Navigator.pop(context);
                          },
                          child: const Text('수정 완료'),
                        ),
                      ],
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

Widget _buildSectionTitle(String title) {

  final colorScheme = Theme.of(context).colorScheme;

  return Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,color: colorScheme.onSurface.withOpacity(0.8),)),
  );
}

  @override
  Widget build(BuildContext context) { //빌드 (위젯이 비어있는지)

    //final colorScheme = Theme.of(context).colorScheme;
    //final theme = Theme.of(context);

    if (widget.plants.isEmpty) {
      return  _buildEmptyState(); 
    }

    return Scaffold(
    // 배경색을 투명하게 하거나 테마에 맞게 설정 (기존 앱 디자인 유지)
    backgroundColor: Colors.transparent,
    body: Stack(
      children: [
        // 레이어 1: 실제 식물 리스트
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // 하단 여백 추가 (삭제 영역에 가려지지 않게)
          itemCount: _sortedPlants.length,
          itemBuilder: (context, index) {
            final plant = _sortedPlants[index];
            
            // 여기에 Draggable을 적용합니다.
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LongPressDraggable<Plant>(
                data: plant,
                // 드래그 시작 시 하단 영역 표시
                onDragStarted: () => setState(() => _isDragging = true),
                // 드래그 종료 시 하단 영역 숨김
                onDragEnd: (_) => setState(() => _isDragging = false),
                // 드래그 중인 모습 (반투명 카드)
                feedback: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Opacity(
                    opacity: 0.8,
                    child: PlantListCard(
                      plant: plant,
                      isSelected: false,
                      onSelect: () {},
                      onEdit: () {},
                      onUpdate: (updatedPlant) {},
                    ),
                  ),
                ),
                // 드래그 시작 후 원래 자리에 남는 모습
                childWhenDragging: Opacity(
                  opacity: 0.2,
                  child: PlantListCard(
                    plant: plant,
                    isSelected: widget.selectedPlantIds.contains(plant.id),
                    onSelect: () {},
                    onEdit: () {},
                    onUpdate: widget.onUpdate,
                  ),
                ),
                // 평소 모습
                child: PlantListCard(
                  plant: plant,
                  isSelected: widget.selectedPlantIds.contains(plant.id),
                  onSelect: () => _toggleSelection(plant.id),
                  onEdit: () => _handleEdit(plant),
                  onUpdate: widget.onUpdate,
                ),
              ),
            );
              },
            ),

        // 레이어 2: 하단 삭제 영역 (애니메이션Positioned)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _isDragging ? 0 : -120, // _isDragging 상태에 따라 올라옴
          left: 0,
          right: 0,
          child: _buildDeleteTarget(), // 아까 만든 삭제 영역 함수
        ),
      ],
    ),
  );
  }

  // Empty State
  Widget _buildEmptyState() {

    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.eco,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '아직 등록된 식물이 없어요',
            style: TextStyle(
              fontSize: 18,
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '입력 화면에서 첫 식물을 등록해보세요!',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteTarget() {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DragTarget<Plant>(
      onWillAccept: (data) => true,
      onAccept: (plant) {
        // 나중에 여기서 삭제 로직을 실행할 거예요.
        _confirmDelete(plant); 
      },
      builder: (context, candidateData, rejectedData) {
        // 드래그 중인 카드가 삭제 영역 바로 위에 올라왔는지 확인
        final isHovering = candidateData.isNotEmpty;

        return Container(
          height: 120,
          decoration: BoxDecoration(
            // 영역 위에 올라오면 빨간색이 더 진해짐
            color: isHovering 
              ? colorScheme.error 
              : colorScheme.error.withOpacity(isDark ? 0.35 : 0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(color: isDark ? Colors.black45 : Colors.black12, blurRadius: 10, spreadRadius: 2)
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHovering ? Icons.delete_forever : Icons.delete_outline,
                color: isHovering ? colorScheme.onError : colorScheme.error,
                size: isHovering ? 45 : 35,
              ),
              const SizedBox(height: 8),
              Text(
                isHovering ? "놓아서 삭제하기" : "여기로 끌어서 삭제",
                style: TextStyle(
                  color: isHovering ? colorScheme.onError : colorScheme.error,
                  fontWeight: isHovering ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}