import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/repositories/plant_repository.dart';

/// 식물 삭제 유스케이스 (비지니스 로직이 아닌 viewmodels에서 데이터 받아 repository에게 작업 위임)
// 구현 안해도 되지만 나중에 추가 조건 생길 경우 대비 (행동 지침서)
class DeletePlantUseCase {
  DeletePlantUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(String plantId) => _repository.deletePlant(plantId);
  //call - class를  함수처럼 쓸 수 있게 해줌
}
