/// fertilizer_history / pesticide_history 배열 원소 DTO
/// 구버전(문자열)과 신버전(맵) 두 형식을 모두 파싱하고,
/// 구버전 원소는 저장 시에도 문자열 그대로 유지해 기존 데이터를 재작성하지 않는다.
class CareRecordDto {
  final String date; // YYYY-MM-DD
  final String? itemId;
  final String? name;
  final String? cycle;
  final bool isLegacy; // 문자열 원소였는지 여부

  const CareRecordDto({
    required this.date,
    this.itemId,
    this.name,
    this.cycle,
    required this.isLegacy,
  });

  factory CareRecordDto.fromRaw(dynamic raw) {
    if (raw is String) {
      return CareRecordDto(date: raw, isLegacy: true);
    }
    final map = Map<String, dynamic>.from(raw as Map);
    return CareRecordDto(
      date: map['date'] as String? ?? '',
      itemId: map['item_id'] as String?,
      name: map['name'] as String?,
      cycle: map['cycle'] as String?,
      isLegacy: false,
    );
  }

  /// 구버전 기록은 문자열, 신규 기록은 맵으로 직렬화
  dynamic toFirestore() {
    if (isLegacy) return date;
    return {
      'date': date,
      'item_id': itemId,
      'name': name,
      'cycle': cycle,
    };
  }
}
