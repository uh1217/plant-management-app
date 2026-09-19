import 'package:plantapp_p/domain/entities/care_item.dart';
import 'package:plantapp_p/domain/entities/care_record.dart';

/// 식물 수정에서 마지막 물 준 날짜를 바꿀 때
/// 물주기/비료/농약 히스토리의 최근 기록을 같은 날짜로 맞춘다.
abstract final class SyncLastCareDate {
  static String dateOnly(String value) => value.split('T')[0];

  /// 가장 최근 물주기 날짜를 [newDate]로 바꾸고, 그보다 뒤인 기록은 삭제한다.
  /// 빈 목록이면 [newDate] 한 건을 넣는다. 같은 날짜는 하나만 남긴다.
  static List<String> wateringHistory({
    required List<String> history,
    required String newDate,
  }) {
    final date = dateOnly(newDate);
    final replaced = history.isEmpty
        ? <String>[date]
        : [...history.sublist(0, history.length - 1), date];
    final kept = replaced
        .map(dateOnly)
        .where((d) => d.compareTo(date) <= 0)
        .toList();
    return _uniquePreserveOrder(kept.isEmpty ? [date] : kept);
  }

  /// 최근 1건이 옛 마지막 물 준 날과 같고, 물과 함께 준 기록이면 날짜를 [newDate]로 바꾼다.
  /// 같은 버튼·같은 날이 이미 있으면 최근 건만 남긴다.
  static List<CareRecord> careHistory({
    required List<CareRecord> history,
    required String oldDate,
    required String newDate,
    required List<CareItem> careItems,
  }) {
    if (history.isEmpty) return history;
    final last = history.last;
    if (dateOnly(last.date) != dateOnly(oldDate)) return history;
    if (!_recordedWithWatering(last, careItems)) return history;

    final shifted = CareRecord(
      date: dateOnly(newDate),
      itemId: last.itemId,
      name: last.name,
      cycle: last.cycle,
    );
    final earlier = history.sublist(0, history.length - 1).where(
          (r) => !(r.date == shifted.date && r.itemId == shifted.itemId),
        );
    return [...earlier, shifted];
  }

  static bool _recordedWithWatering(
    CareRecord record,
    List<CareItem> careItems,
  ) {
    final id = record.itemId;
    if (id == null || id.isEmpty) return true;
    for (final item in careItems) {
      if (item.id == id) return item.includeWatering;
    }
    return true;
  }

  static List<String> _uniquePreserveOrder(List<String> dates) {
    final seen = <String>{};
    final result = <String>[];
    for (final date in dates) {
      if (seen.add(date)) result.add(date);
    }
    return result;
  }
}
