/// 케어 버튼 구분 (비료/농약)
enum CareItemType { fertilizer, pesticide }

/// 사용자가 등록한 비료/농약 버튼 (계정 전체 공유)
class CareItem {
  final String id;
  final CareItemType type;
  final String name; // 빈 문자열 허용 (UI에서 '이름 없음' 표시)
  final int color; // ARGB int (Flutter Color.value)
  final String cycleMemo; // 주기 메모 (자유 텍스트, 빈 문자열 허용)
  final bool includeWatering; // true면 기록 시 물주기도 동시 갱신
  final String createdAt; // ISO 8601 (목록 정렬용)

  const CareItem({
    required this.id,
    required this.type,
    required this.name,
    required this.color,
    required this.cycleMemo,
    required this.includeWatering,
    required this.createdAt,
  });
}
