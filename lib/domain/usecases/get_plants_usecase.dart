import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// 식물 목록 조회 유스케이스
class GetPlantsUseCase {
  GetPlantsUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<List<Plant>>> call() => _repository.getPlants();
}
