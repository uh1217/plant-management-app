import 'package:flutter/material.dart';

import 'package:plantapp_p/domain/entities/care_item.dart';
import 'package:plantapp_p/presentation/utils/care_display.dart';
import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';

/// 비료/농약 케어 버튼 바텀시트
/// - 등록된 버튼 목록: 탭 → 해당 CareItem을 결과로 반환 (호출부에서 일괄 기록)
/// - 버튼 추가: 시트 내 폼 전환 (이름·색·주기 메모·관수 여부)
/// - 버튼 삭제: 삭제 아이콘 탭 시 즉시 삭제 (기존 기록은 유지)
class CareButtonSheet extends StatefulWidget {
  const CareButtonSheet({
    super.key,
    required this.viewModel,
    required this.type,
  });

  final HomeViewModel viewModel;
  final CareItemType type;

  @override
  State<CareButtonSheet> createState() => _CareButtonSheetState();
}

class _CareButtonSheetState extends State<CareButtonSheet> {
  static const _palette = <Color>[
    Color(0xFF22C55E), // green
    Color(0xFF16A34A), // dark green
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFFDC2626), // red
    Color(0xFFF97316), // orange
    Color(0xFFF9D48A), // light yellow
    Color(0xFF92400E), // brown
    Color(0xFF6B7280), // gray
  ];

  bool _showAddForm = false;
  bool _isSaving = false;
  final _nameCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController();
  late Color _selectedColor;

  bool _includeWatering = true;

  @override
  void initState() {
    super.initState();
    _selectedColor =
        widget.type == CareItemType.fertilizer ? _palette[0] : _palette[7];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cycleCtrl.dispose();
    super.dispose();
  }

  String get _typeLabel =>
      widget.type == CareItemType.fertilizer ? '비료' : '농약';

  Future<void> _submitAdd() async {
    setState(() => _isSaving = true);
    final ok = await widget.viewModel.addCareItem(CareItem(
      id: '', // Firestore에서 생성
      type: widget.type,
      name: _nameCtrl.text.trim(),
      color: _selectedColor.value,
      cycleMemo: _cycleCtrl.text.trim(),
      includeWatering: _includeWatering,
      createdAt: DateTime.now().toIso8601String(),
    ));
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (ok) {
      // 폼 초기화 후 목록으로 복귀
      _nameCtrl.clear();
      _cycleCtrl.clear();
      setState(() {
        _includeWatering = true;
        _showAddForm = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('버튼 등록에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        // 키보드가 올라오면 폼이 가려지지 않도록 하단 인셋 반영
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, _) {
            final items = widget.viewModel.careItems
                .where((i) => i.type == widget.type)
                .toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showAddForm ? '$_typeLabel 버튼 추가' : '$_typeLabel 버튼',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_showAddForm)
                    _buildAddForm(colorScheme)
                  else
                    _buildItemList(items, colorScheme),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 버튼 목록 ────────────────────────────────────────────────────────────

  Widget _buildItemList(List<CareItem> items, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '등록된 $_typeLabel 버튼이 없습니다.\n아래에서 새 버튼을 추가해보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  // 버튼 탭 → 시트 닫고 선택된 식물들에 일괄 기록 (호출부 처리)
                  onTap: () => Navigator.pop(context, item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Color(item.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            careLabel(item.name, item.cycleMemo),
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!item.includeWatering)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.format_color_reset_outlined,
                              size: 16,
                              color: colorScheme.onSurface.withOpacity(0.35),
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          onPressed: () =>
                              widget.viewModel.deleteCareItem(item.id),
                          tooltip: '버튼 삭제 (기존 기록은 유지됩니다)',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showAddForm = true),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('새 버튼 추가'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  // ── 버튼 추가 폼 ─────────────────────────────────────────────────────────

  Widget _buildAddForm(ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameCtrl,
          // 서버 규칙(name ≤ 50자)과 일치시켜 규칙 거부로 인한 등록 실패 방지
          maxLength: 50,
          decoration: InputDecoration(
            labelText: '이름',
            hintText: '예: 하이포넥스',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: colorScheme.surfaceContainer,
            isDense: true,
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cycleCtrl,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: '주기 메모',
            hintText: '예: 2주, 월 1회',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: colorScheme.surfaceContainer,
            isDense: true,
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '버튼 색',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _palette.map((color) {
            final isSelected = color.value == _selectedColor.value;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: colorScheme.onSurface, width: 2.5)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        CheckboxListTile(
          value: _includeWatering,
          onChanged: (v) => setState(() => _includeWatering = v ?? true),
          title: const Text('물주기 함께 기록', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            '체크 시 이 버튼으로 기록할 때 물 준 날짜도 갱신됩니다',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() => _showAddForm = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('취소'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitAdd,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('추가하기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
