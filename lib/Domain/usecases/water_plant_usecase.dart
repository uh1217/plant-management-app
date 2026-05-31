import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// 물 주기 기록 유스케이스
class WaterPlantUseCase {
  WaterPlantUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(String plantId, String isoDate) =>
      _repository.waterPlant(plantId, isoDate);
}
