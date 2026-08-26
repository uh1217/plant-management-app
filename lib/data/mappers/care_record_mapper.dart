import 'package:plantapp_p/data/models/care_record_dto.dart';
import 'package:plantapp_p/domain/entities/care_record.dart';

/// CareRecord DTO ↔ Domain Entity 변환
class CareRecordMapper {
  static CareRecord toEntity(CareRecordDto dto) => CareRecord(
        date: dto.date,
        itemId: dto.itemId,
        name: dto.name,
        cycle: dto.cycle,
      );

  static CareRecordDto toDto(CareRecord entity) => CareRecordDto(
        date: entity.date,
        itemId: entity.itemId,
        name: entity.name,
        cycle: entity.cycle,
        // 스냅샷 필드가 전혀 없으면 구버전 문자열 기록 → 저장 시 문자열 유지
        isLegacy: entity.isLegacy,
      );
}
