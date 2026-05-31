import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// 식물 저장·수정 유스케이스
class SavePlantUseCase {
  SavePlantUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(Plant plant) => _repository.savePlant(plant);
}
