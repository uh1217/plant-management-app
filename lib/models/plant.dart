// App.tsx의 Plant interface 변환(데이터 모델 파일)
//final-> 데이터 상수화(영구)-데이터 안정성 높임
class Plant {
  final String id;
  final String imageUrl;
  final String name;
  final List<String> categories;
  final int wateringFrequency; // 물 주기 (일)
  final String lastWatered; // 최근 물 준 날짜 (ISO 형식)
  final List<String> wateringHistory; // 물 준 날짜들
  final List<String> fertilizerHistory; // 비료 준 날짜들
  final String notes;

  //생성자 (required-반드시 입력해야함)
  Plant({
    required this.id,
    required this.imageUrl,
    required this.name,
    required this.categories,
    required this.wateringFrequency,
    required this.lastWatered,
    required this.wateringHistory,
    required this.fertilizerHistory,
    required this.notes,
  });

  // copyWith 메서드 (업데이트용 - 복사해서 바뀐 정보만 바꿈,?는 널값이 들어올 수도 있다는 뜻)
  Plant copyWith({
    String? id,
    String? imageUrl,
    String? name,
    List<String>? categories,
    int? wateringFrequency,
    String? lastWatered,
    List<String>? wateringHistory,
    List<String>? fertilizerHistory,
    String? notes,
  }) {
    //(?? -> 새로운 값이 안들어왔으면 기존 this값 그대로 씀)
    return Plant(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      name: name ?? this.name,
      categories: categories ?? this.categories,
      wateringFrequency: wateringFrequency ?? this.wateringFrequency,
      lastWatered: lastWatered ?? this.lastWatered,
      wateringHistory: wateringHistory ?? this.wateringHistory,
      fertilizerHistory: fertilizerHistory ?? this.fertilizerHistory,
      notes: notes ?? this.notes,
    );
  }

  // JSON 변환 (DB-Dart 서로 통하기 위해서 필요) -> 객체를 DB(Map)용으로 전환(저장할 때)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_url': imageUrl,      // DB 컬럼명과 일치시킴
      'name': name,
      'watering_frequency': wateringFrequency,
      'last_watered': lastWatered,
      'notes': notes,
      // 나머지 값은 list값이므로 PlantRepository 클래스에서 별도 변환 후 저장
    };
  }

  //다시 복원 -> DB(Map) 데이터를 객체로 변환 (불러올 때 사용)
  factory Plant.fromMap(Map<String, dynamic> map, {
    List<String>? categories, 
    List<String>? wHistory, 
    List<String>? fHistory
  }) {
    return Plant(
      id: map['id'] as String,
      imageUrl: map['image_url'] as String,
      name: map['name'] as String,
      wateringFrequency: map['watering_frequency'] as int,
      lastWatered: map['last_watered'] as String,
      notes: map['notes'] as String,
      // 리스트들은 인자로 받은 값을 사용 (없으면 빈 리스트)
      categories: categories ?? [],
      wateringHistory: wHistory ?? [],
      fertilizerHistory: fHistory ?? [],
    );
  }

  bool get needsWaterToday {
    final lastDate = DateTime.parse(lastWatered);
    final today = DateTime.now();

    // 시간 정보를 제거하고 '날짜'만 비교 (중요)
    final date1 = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final date2 = DateTime(today.year, today.month, today.day);

    final daysSinceWatered = date2.difference(date1).inDays;
    
    // 주기가 되었거나 이미 지난 경우 모두 포함
    return (wateringFrequency - daysSinceWatered) <= 0;
  }
}
