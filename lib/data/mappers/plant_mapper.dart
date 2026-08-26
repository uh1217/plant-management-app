import 'package:plantapp_p/data/mappers/care_record_mapper.dart';
import 'package:plantapp_p/data/models/plant_dto.dart';
import 'package:plantapp_p/domain/entities/plant.dart';

/// Plant DTO ↔ Domain Entity 변환
class PlantMapper {
  static Plant toEntity(PlantDto dto) => Plant(
        id: dto.id,
        imageUrl: dto.imageUrl,
        name: dto.name,
        categories: dto.categories,
        wateringFrequency: dto.wateringFrequency,
        lastWatered: dto.lastWatered,
        wateringHistory: dto.wateringHistory,
        fertilizerHistory:
            dto.fertilizerHistory.map(CareRecordMapper.toEntity).toList(),
        pesticideHistory:
            dto.pesticideHistory.map(CareRecordMapper.toEntity).toList(),
        notes: dto.notes,
      );

  static PlantDto toDto(Plant entity) => PlantDto(
        id: entity.id,
        imageUrl: entity.imageUrl,
        name: entity.name,
        categories: entity.categories,
        wateringFrequency: entity.wateringFrequency,
        lastWatered: entity.lastWatered,
        wateringHistory: entity.wateringHistory,
        fertilizerHistory:
            entity.fertilizerHistory.map(CareRecordMapper.toDto).toList(),
        pesticideHistory:
            entity.pesticideHistory.map(CareRecordMapper.toDto).toList(),
        notes: entity.notes,
      );
}
