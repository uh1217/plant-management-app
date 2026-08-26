/// 케어 버튼·기록 공통 표시 라벨: "이름(주기)"
/// - 이름이 비어 있으면 '이름 없음'
/// - 주기가 비어 있으면 괄호 생략
String careLabel(String? name, String? cycle) {
  final displayName = (name == null || name.isEmpty) ? '이름 없음' : name;
  if (cycle == null || cycle.isEmpty) return displayName;
  return '$displayName($cycle)';
}
