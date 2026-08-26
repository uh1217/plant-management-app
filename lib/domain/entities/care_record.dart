/// 비료/농약 기록 1건 — 기록 시점의 버튼 정보(이름·주기)를 스냅샷으로 보관
/// 버튼이 삭제되어도 기록 표시("이름(주기)")가 유지되는 근거
class CareRecord {
  final String date; // YYYY-MM-DD
  final String? itemId; // 기록에 사용된 케어 버튼 ID
  final String? name; // 버튼 이름 스냅샷 (빈 문자열 허용)
  final String? cycle; // 주기 메모 스냅샷

  const CareRecord({
    required this.date,
    this.itemId,
    this.name,
    this.cycle,
  });

  /// 구버전 문자열 기록 여부 (날짜만 존재) — UI에서 날짜만 표시
  bool get isLegacy => itemId == null && name == null && cycle == null;
}
