/// Firestore plants 문서 DTO (snake_case)
class PlantDto {
  final String id;
  final String imageUrl;
  final String name;
  final List<String> categories;
  final int wateringFrequency;
  final String lastWatered;
  final List<String> wateringHistory;
  final List<String> fertilizerHistory;
  final String notes;

  const PlantDto({
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

  factory PlantDto.fromFirestore(Map<String, dynamic> map, String documentId) {
    return PlantDto(
      id: documentId,
      imageUrl: map['image_url'] as String? ?? '',
      name: map['name'] as String? ?? '',
      categories: List<String>.from(map['categories'] ?? const []),
      wateringFrequency: (map['watering_frequency'] as num?)?.toInt() ?? 0,
      lastWatered: map['last_watered'] as String? ?? '',
      wateringHistory: List<String>.from(map['watering_history'] ?? const []),
      fertilizerHistory:
          List<String>.from(map['fertilizer_history'] ?? const []),
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'image_url': imageUrl,
      'name': name,
      'categories': categories,
      'watering_frequency': wateringFrequency,
      'last_watered': lastWatered,
      'watering_history': wateringHistory,
      'fertilizer_history': fertilizerHistory,
      'notes': notes,
    };
  }
}
