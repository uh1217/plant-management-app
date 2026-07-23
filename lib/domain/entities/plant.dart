/// 식물 도메인 엔티티 (외부 라이브러리·Firestore 의존 없음)
class Plant {
  final String id;
  final String imageUrl;// 🌟 갤러리의 대표 사진 역할로 쓰게 됩니다!
  final String name;
  final List<String> categories;
  final int wateringFrequency; // 물 주기 (일)
  final String lastWatered; // 최근 물 준 날짜 (ISO 형식)
  final List<String> wateringHistory; // 물 준 날짜들
  final List<String> fertilizerHistory; // 비료 준 날짜들
  final List<String> pesticideHistory; // 농약 준 날짜들
  final String notes;

  const Plant({
    required this.id,
    required this.imageUrl,
    required this.name,
    required this.categories,
    required this.wateringFrequency,
    required this.lastWatered,
    required this.wateringHistory,
    required this.fertilizerHistory,
    required this.pesticideHistory,
    required this.notes,
  });

  Plant copyWith({
    String? id,
    String? imageUrl,
    String? name,
    List<String>? categories,
    int? wateringFrequency,
    String? lastWatered,
    List<String>? wateringHistory,
    List<String>? fertilizerHistory,
    List<String>? pesticideHistory,
    String? notes,
  }) {
    return Plant(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      name: name ?? this.name,
      categories: categories ?? this.categories,
      wateringFrequency: wateringFrequency ?? this.wateringFrequency,
      lastWatered: lastWatered ?? this.lastWatered,
      wateringHistory: wateringHistory ?? this.wateringHistory,
      fertilizerHistory: fertilizerHistory ?? this.fertilizerHistory,
      pesticideHistory: pesticideHistory ?? this.pesticideHistory,
      notes: notes ?? this.notes,
    );
  }

  bool get needsWaterToday {
    final lastDate = DateTime.parse(lastWatered);
    final today = DateTime.now();
    final date1 = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final date2 = DateTime(today.year, today.month, today.day);
    final daysSinceWatered = date2.difference(date1).inDays;
    return (wateringFrequency - daysSinceWatered) <= 0;
  }
}
