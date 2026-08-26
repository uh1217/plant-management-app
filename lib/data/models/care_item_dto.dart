/// Firestore care_items 문서 DTO (snake_case)
class CareItemDto {
  final String id;
  final String type; // 'fertilizer' | 'pesticide'
  final String name;
  final int color; // ARGB int
  final String cycleMemo;
  final bool includeWatering;
  final String createdAt; // ISO 8601

  const CareItemDto({
    required this.id,
    required this.type,
    required this.name,
    required this.color,
    required this.cycleMemo,
    required this.includeWatering,
    required this.createdAt,
  });

  factory CareItemDto.fromFirestore(
      Map<String, dynamic> map, String documentId) {
    return CareItemDto(
      id: documentId,
      type: map['type'] as String? ?? 'fertilizer',
      name: map['name'] as String? ?? '',
      color: (map['color'] as num?)?.toInt() ?? 0xFF22C55E,
      cycleMemo: map['cycle_memo'] as String? ?? '',
      includeWatering: map['include_watering'] as bool? ?? true,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'name': name,
      'color': color,
      'cycle_memo': cycleMemo,
      'include_watering': includeWatering,
      'created_at': createdAt,
    };
  }
}
