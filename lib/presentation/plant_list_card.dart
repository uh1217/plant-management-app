//가로로 긴 카드 UI, 물주기 상태 표시 (색상 구분)
//체크박스 선택, 최근 물 준 날짜 클릭 → 캘린더 팝업
//이미지 클릭 → 갤러리 팝업, 더블클릭 → 편집 모달
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/plant.dart';
//import '../presentation/app_colors.dart';
import 'dart:io';

// PlantListCard.tsx 변환
class PlantListCard extends StatefulWidget {
  final Plant plant; //식물들의 정보 들어가있음
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final Function(Plant) onUpdate;

  const PlantListCard({ //생성자
    super.key, //ID
    required this.plant,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onUpdate,
  });

  @override
  State<PlantListCard> createState() => _PlantListCardState();
}

class _PlantListCardState extends State<PlantListCard> { //State를 상속
  //bool _isGalleryOpen = false; //내부 상태 관리?

  // Calculate days until watering
  int _getDaysUntilWatering() { //식물이 앞으로 얼마뒤에 물을 마셔야할지
    final lastWatered = DateTime.parse(widget.plant.lastWatered); //widget은 state클래스가 일반 설계도에 접근할 수 있음
    final today = DateTime.now();
    final daysSinceWatered = today.difference(lastWatered).inDays;
    final daysUntil = widget.plant.wateringFrequency - daysSinceWatered;
    return daysUntil;
  }

  // Get watering status (color and text)
  Map<String, dynamic> _getWateringStatus() { //맵 형태의 결과물 리턴

    final colorScheme = Theme.of(context).colorScheme;
    final daysUntil = _getDaysUntilWatering();
    
    if (daysUntil <= 0) {
      return {
        'text': '물이 필요해요!',
        'color': colorScheme.error,
        'bg': colorScheme.error.withOpacity(0.1),
      };
    } else if (daysUntil <= 2) {
      return {
        'text': '$daysUntil일 후',
        'color': colorScheme.tertiary,
        'bg': colorScheme.tertiary.withOpacity(0.1),
      };
    } else {
      return {
        'text': '$daysUntil일 후',
        'color': colorScheme.secondary,
        'bg': colorScheme.secondary.withOpacity(0.1),
      };
    }
  }

  // 카드 상세정보
  Future<void> _showCalendarDialog() async {
    final status = _getWateringStatus();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    //띄울 이미지 박스,색상
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('${widget.plant.name} 물주기 기록'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: status['bg'],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.water_drop,
                      color: status['color'],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status['text'],
                      style: TextStyle(
                        color: status['color'],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Watering History
               Text(
                '💧 물 준 날짜',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.plant.wateringHistory.map((date) => Padding( //날짜리스트 달력화
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              )),
              
              // Fertilizer History
              if (widget.plant.fertilizerHistory.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '🌿 비료 준 날짜',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.plant.fertilizerHistory.map((date) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 날짜 포맷팅
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy년 M월 d일').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // 이미지 클릭
  void _showImageGallery() {
    //final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
              child: widget.plant.imageUrl.isNotEmpty
                  ? Image.file(
                      File(widget.plant.imageUrl),
                      fit: BoxFit.contain, // 확대 시에는 전체가 보이게
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(), // 경로 없으면 기본 이미지
            ),
          ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  side: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 기본 이미지(Placeholder)를 생성하는 공통 함수
  Widget _buildPlaceholder() {
    return Image.asset(
      'assets/images/home_gardening.jpg', 
      width: 80,
      height: 120,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _getWateringStatus();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector( //제스처
      onTap: widget.onSelect, //리스트 카드 체크 액션
      onDoubleTap: widget.onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isSelected 
            ? colorScheme.primary.withOpacity(0.1) 
            : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isSelected ? colorScheme.primary : theme.dividerColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.15 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              GestureDetector(
                onTap: _showImageGallery, //터치한 이미지 확장
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.plant.imageUrl.isNotEmpty
                      ? Image.file( // 👈 Image.network에서 Image.file로 변경
                        File(widget.plant.imageUrl), // 👈 File 객체로 경로 감싸기
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                    // 2. 처음부터 이미지 경로가 없을 때 처리
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
              // Info
              Expanded( //위젯 남은부분 식물 정보로 체움
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      widget.plant.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Categories
                    if (widget.plant.categories.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 14,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.plant.categories.join(', '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                  decoration: TextDecoration.none,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Watering Info
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.water_drop,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.plant.wateringFrequency}일마다',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '·',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.3),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status['text'],
                            style: TextStyle(
                              fontSize: 12,
                              color: status['color'],
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Last Watered (Clickable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector( //최근 물준 날짜 클릭
                        onTap: _showCalendarDialog,
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '최근: ${_formatDate(widget.plant.lastWatered)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.primary,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Notes
                    if (widget.plant.notes.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.description,
                            size: 14,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.plant.notes,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withOpacity(0.6),
                                decoration: TextDecoration.none,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
