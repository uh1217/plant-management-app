import 'package:plantapp_p/domain/repositories/plant_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// 농약 주기 기록 유스케이스
class PesticidePlantUseCase {
  PesticidePlantUseCase(this._repository);
  final PlantRepository _repository;

  Future<Result<void>> call(String plantId, String isoDate) =>
      _repository.pesticidePlant(plantId, isoDate);
}
