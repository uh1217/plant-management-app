import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// 비료 주기 기록 유스케이스
class FertilizePlantUseCase {
  FertilizePlantUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(String plantId, String isoDate) =>
      _repository.fertilizePlant(plantId, isoDate);
}
