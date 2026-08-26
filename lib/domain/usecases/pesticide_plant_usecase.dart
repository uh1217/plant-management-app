import 'package:plantapp_p/domain/entities/care_record.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// 농약 주기 기록 유스케이스 — 버튼 스냅샷(record)과 관수 여부를 함께 전달
class PesticidePlantUseCase {
  PesticidePlantUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(String plantId, CareRecord record,
          {required bool includeWatering}) =>
      _repository.pesticidePlant(plantId, record,
          includeWatering: includeWatering);
}
