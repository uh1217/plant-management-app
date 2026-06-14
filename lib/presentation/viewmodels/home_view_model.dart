import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/core/services/gemini_service.dart';
import 'package:plantapp_p/core/services/weather_recommendation_service.dart';
import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/domain/usecases/delete_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/fertilize_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/get_plants_usecase.dart';
import 'package:plantapp_p/domain/usecases/save_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/sign_out_usecase.dart';
import 'package:plantapp_p/domain/usecases/water_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/get_weather_recommendation_usecase.dart';

// 화면 상태
enum HomeUiStatus { idle, loading, success, error }

// 추천 카드 상태
enum RecommendationStatus { idle, loading, success, error }

/// 홈 화면 상태 및 식물 관련 UseCase 오케스트레이션 (생성자-유스케이스 주입)
class HomeViewModel extends ChangeNotifier {
  static const _prefKeyWeatherEnabled = 'weather_recommendation_enabled';

  HomeViewModel({
    required GetPlantsUseCase getPlants,
    required SavePlantUseCase savePlant,
    required DeletePlantUseCase deletePlant,
    required WaterPlantUseCase waterPlant,
    required FertilizePlantUseCase fertilizePlant,
    required SignOutUseCase signOut,
    required GeminiService geminiService,
    required GetWeatherRecommendationUseCase getWeatherRecommendation,
    required WeatherRecommendationService weatherRecommendationService,
  })  : _getPlants = getPlants,
        _savePlant = savePlant,
        _deletePlant = deletePlant,
        _waterPlant = waterPlant,
        _fertilizePlant = fertilizePlant,
        _signOut = signOut,
        _geminiService = geminiService,
        _getWeatherRecommendation = getWeatherRecommendation,
        _weatherRecommendationService = weatherRecommendationService;

  final GetPlantsUseCase _getPlants;
  final SavePlantUseCase _savePlant;
  final DeletePlantUseCase _deletePlant;
  final WaterPlantUseCase _waterPlant;
  final FertilizePlantUseCase _fertilizePlant;
  final SignOutUseCase _signOut;
  final GeminiService _geminiService;
  final GetWeatherRecommendationUseCase _getWeatherRecommendation;
  final WeatherRecommendationService _weatherRecommendationService;

  HomeUiStatus status = HomeUiStatus.idle;
  String? errorMessage;
  List<Plant> plants = [];

  // ─── 날씨 추천 카드 상태 ────────────────────────────────────────────────────
  RecommendationStatus recommendationStatus = RecommendationStatus.idle;
  String? recommendationText;
  bool weatherRecommendationEnabled = true;

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

  // ─── 날씨 추천 설정 로드 (initState에서 호출) ──────────────────────────────
  Future<void> loadWeatherRecommendationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    weatherRecommendationEnabled =
        prefs.getBool(_prefKeyWeatherEnabled) ?? true;
    notifyListeners();
  }

  /// 설정 on/off 변경 (사이드바 설정 다이얼로그에서 호출)
  Future<void> setWeatherRecommendationEnabled(bool value) async {
    weatherRecommendationEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyWeatherEnabled, value);
  }

  /// 날씨 추천 멘트 로드
  ///
  /// 오류 발생 시 설정을 자동으로 OFF로 전환한다.
  Future<void> loadWeatherRecommendation() async {
    if (!weatherRecommendationEnabled) return;

    recommendationStatus = RecommendationStatus.loading;
    notifyListeners();

    final result = await _getWeatherRecommendation(plants);
    switch (result) {
      case Success(:final data):
        recommendationText = data;
        recommendationStatus = RecommendationStatus.success;
      case Failure(:final message):
        debugPrint('[HomeViewModel] 날씨 추천 오류 → 설정 OFF: $message');
        recommendationText = null;
        recommendationStatus = RecommendationStatus.error;
        // 오류 발생 시 자동 OFF
        await setWeatherRecommendationEnabled(false);
    }
    notifyListeners();
  }

  /// 식물 목록 변경 시 추천 캐시도 함께 무효화
  void invalidateRecommendationCache() {
    _weatherRecommendationService.invalidateCache();
    recommendationText = null;
    recommendationStatus = RecommendationStatus.idle;
  }

  Future<bool> savePlant(Plant plant) async {
    final result = await _savePlant(plant);
    if (result is Failure) return _fail(result.message);
    _geminiService.invalidateRagCache();
    invalidateRecommendationCache();
    return true;
  }

  Future<bool> deletePlant(String plantId) async {
    final result = await _deletePlant(plantId);
    if (result is Failure) return _fail(result.message);
    _geminiService.invalidateRagCache();
    invalidateRecommendationCache();
    return true;
  }

  /// 선택된 식물들에 물 주기 병렬 기록 후 로컬 상태만 갱신 (네트워크 재조회 없음)
  Future<bool> waterPlants(Set<String> plantIds, String today) async {
    final results = await Future.wait(
      plantIds.map((id) => _waterPlant(id, today)),
    );
    for (final result in results) {
      if (result case Failure(:final message)) return _fail(message);
    }
    plants = plants.map((p) {
      if (!plantIds.contains(p.id)) return p;
      return p.copyWith(
        lastWatered: today,
        wateringHistory: [...p.wateringHistory, today],
      );
    }).toList();
    notifyListeners();
    return true;
  }

  /// 선택된 식물들에 비료 주기 병렬 기록 후 로컬 상태만 갱신 (네트워크 재조회 없음)
  Future<bool> fertilizePlants(Set<String> plantIds, String today) async {
    final results = await Future.wait(
      plantIds.map((id) => _fertilizePlant(id, today)),
    );
    for (final result in results) {
      if (result case Failure(:final message)) return _fail(message);
    }
    plants = plants.map((p) {
      if (!plantIds.contains(p.id)) return p;
      return p.copyWith(
        fertilizerHistory: [...p.fertilizerHistory, today],
      );
    }).toList();
    notifyListeners();
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
