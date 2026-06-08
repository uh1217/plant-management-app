//가로로 긴 카드 UI, 물주기 상태 표시 (색상 구분)
//체크박스 선택, 최근 물 준 날짜 클릭 → 캘린더 팝업
//이미지 클릭 → 갤러리 팝업, 더블클릭 → 편집 모달
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:plantapp_p/domain/entities/plant.dart';
import 'dart:io';

// PlantListCard.tsx 변환
class PlantListCard extends StatefulWidget {
  final Plant plant;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final Function(Plant) onUpdate;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  const PlantListCard({
    super.key,
    required this.plant,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onUpdate,
    this.onDragStarted,
    this.onDragEnded,
  });

  @override
  State<PlantListCard> createState() => _PlantListCardState();
}

//날짜 계산산
class _PlantListCardState extends State<PlantListCard> {
  int _getDaysUntilWatering() {
    final lastWatered = DateTime.parse(widget.plant.lastWatered);
    final today = DateTime.now();
    final daysSinceWatered = today.difference(lastWatered).inDays;
    final daysUntil = widget.plant.wateringFrequency - daysSinceWatered;
    return daysUntil;
  }

  Map<String, dynamic> _getWateringStatus() {
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

  Future<void> _showCalendarDialog() async {
    final status = _getWateringStatus();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              Text(
                '💧 물 준 날짜',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.plant.wateringHistory.map((date) => Padding(
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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy년 M월 d일').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void _showImageGallery() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: widget.plant.imageUrl.isNotEmpty
                    ? (widget.plant.imageUrl.startsWith('http')
                        ? Image.network(
                            widget.plant.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          )
                        : Image.file(
                            File(widget.plant.imageUrl),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          ))
                    : _buildPlaceholder(),
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

  Widget _buildPlaceholder() {
    return Image.asset(
      'assets/images/home_gardening.jpg',
      width: 80,
      height: 120,
      fit: BoxFit.cover,
    );
  }

  Widget _buildCardContent(
      Map<String, dynamic> status, ThemeData theme, ColorScheme colorScheme) {
    return Container(
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
            color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.15 : 0.05),
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
            GestureDetector(
              onTap: _showImageGallery,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.plant.imageUrl.isNotEmpty
                    ? (widget.plant.imageUrl.startsWith('http')
                        ? Image.network(
                            widget.plant.imageUrl,
                            width: 80,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          )
                        : Image.file(
                            File(widget.plant.imageUrl),
                            width: 80,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          ))
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GestureDetector(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _getWateringStatus();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardContent = _buildCardContent(status, theme, colorScheme);

    return LongPressDraggable<Plant>(
      data: widget.plant,
      delay: const Duration(milliseconds: 450),
      onDragStarted: widget.onDragStarted,
      onDragEnd: (_) => widget.onDragEnded?.call(),
      feedback: Material(
        // 드래그 중 손가락을 따라다니는 위젯: 실제 카드와 동일한 크기·디자인, 85% 불투명
        elevation: 10,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          // 화면 너비(최대 430) - ListView 좌우 패딩(16+16=32) = 실제 카드 너비
          width: MediaQuery.of(context).size.width.clamp(0.0, 430.0) - 32,
          child: Opacity(
            opacity: 0.85,
            child: _buildCardContent(status, theme, colorScheme),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: cardContent,
      ),
      child: GestureDetector(
        onTap: widget.onSelect,
        onDoubleTap: widget.onEdit,
        child: cardContent,
      ),
    );
  }
}
