import 'package:flutter/foundation.dart';

import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/domain/usecases/delete_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/fertilize_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/get_plants_usecase.dart';
import 'package:plantapp_p/domain/usecases/save_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/sign_out_usecase.dart';
import 'package:plantapp_p/domain/usecases/water_plant_usecase.dart';

// 화면 상태
enum HomeUiStatus { idle, loading, success, error }

/// 홈 화면 상태 및 식물 관련 UseCase 오케스트레이션 (생성자-유스케이스 주입)
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required GetPlantsUseCase getPlants,
    required SavePlantUseCase savePlant,
    required DeletePlantUseCase deletePlant,
    required WaterPlantUseCase waterPlant,
    required FertilizePlantUseCase fertilizePlant,
    required SignOutUseCase signOut,
  })  : _getPlants = getPlants,
        _savePlant = savePlant,
        _deletePlant = deletePlant,
        _waterPlant = waterPlant,
        _fertilizePlant = fertilizePlant,
        _signOut = signOut;

  final GetPlantsUseCase _getPlants;
  final SavePlantUseCase _savePlant;
  final DeletePlantUseCase _deletePlant;
  final WaterPlantUseCase _waterPlant;
  final FertilizePlantUseCase _fertilizePlant;
  final SignOutUseCase _signOut;

  HomeUiStatus status = HomeUiStatus.idle;
  String? errorMessage;
  List<Plant> plants = [];

  Future<void> loadPlants() async {
    status = HomeUiStatus.loading;
    notifyListeners();

    final result = await _getPlants();
    switch (result) {
      case Success(:final data):
        plants = data;
        status = HomeUiStatus.success;
        errorMessage = null;
      case Failure(:final message):
        status = HomeUiStatus.error;
        errorMessage = message;
    }
    notifyListeners();
  }

  Future<bool> savePlant(Plant plant) async {
    final result = await _savePlant(plant);
    return switch (result) {
      Success() => true,
      Failure(:final message) => _fail(message),
    };
  }

  Future<bool> deletePlant(String plantId) async {
    final result = await _deletePlant(plantId);
    return switch (result) {
      Success() => true,
      Failure(:final message) => _fail(message),
    };
  }

  /// 선택된 식물들에 물 주기 기록 후 목록 갱신
  Future<bool> waterPlants(Set<String> plantIds, String today) async {
    for (final id in plantIds) {
      final result = await _waterPlant(id, today);
      if (result is Failure) return _fail(result.message);
    }
    await loadPlants();
    return true;
  }

  /// 선택된 식물들에 비료 주기 기록 후 목록 갱신
  Future<bool> fertilizePlants(Set<String> plantIds, String today) async {
    for (final id in plantIds) {
      final result = await _fertilizePlant(id, today);
      if (result is Failure) return _fail(result.message);
    }
    await loadPlants();
    return true;
  }

  /// Firebase + Google 세션 동시 로그아웃
  Future<bool> signOut() async {
    final result = await _signOut();
    return switch (result) {
      Success() => true,
      Failure(:final message) => _fail(message),
    };
  }

  bool _fail(String message) {
    status = HomeUiStatus.error;
    errorMessage = message;
    notifyListeners();
    return false;
  }
}
