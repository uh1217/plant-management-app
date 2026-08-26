import 'package:plantapp_p/data/models/care_item_dto.dart';
import 'package:plantapp_p/domain/entities/care_item.dart';

/// CareItem DTO ↔ Domain Entity 변환
class CareItemMapper {
  static CareItem toEntity(CareItemDto dto) => CareItem(
        id: dto.id,
        type: dto.type == 'pesticide'
            ? CareItemType.pesticide
            : CareItemType.fertilizer,
        name: dto.name,
        color: dto.color,
        cycleMemo: dto.cycleMemo,
        includeWatering: dto.includeWatering,
        createdAt: dto.createdAt,
      );

  static CareItemDto toDto(CareItem entity) => CareItemDto(
        id: entity.id,
        type: entity.type == CareItemType.pesticide
            ? 'pesticide'
            : 'fertilizer',
        name: entity.name,
        color: entity.color,
        cycleMemo: entity.cycleMemo,
        includeWatering: entity.includeWatering,
        createdAt: entity.createdAt,
      );
}
