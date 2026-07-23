import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/core/services/gemini_service.dart';
import 'package:plantapp_p/data/datasources/city_datasource.dart';
import 'package:plantapp_p/data/datasources/weather_remote_datasource.dart';
import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/domain/usecases/delete_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/fertilize_plant_usecase.dart';
import 'package:plantapp_p/domain/usecases/pesticide_plant_usecase.dart';
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
  static const _prefKeyRecText = 'weather_rec_text';
  static const _prefKeyRecSlot = 'weather_rec_slot';
  static const _prefKeyRecDate = 'weather_rec_date';

  HomeViewModel({
    required GetPlantsUseCase getPlants,
    required SavePlantUseCase savePlant,
    required DeletePlantUseCase deletePlant,
    required WaterPlantUseCase waterPlant,
    required FertilizePlantUseCase fertilizePlant,
    required PesticidePlantUseCase pesticidePlant,
    required SignOutUseCase signOut,
    required GeminiService geminiService,
    required GetWeatherRecommendationUseCase getWeatherRecommendation,
    required CityDataSource cityDataSource,
    required WeatherRemoteDataSource weatherDataSource,
  })  : _getPlants = getPlants,
        _savePlant = savePlant,
        _deletePlant = deletePlant,
        _waterPlant = waterPlant,
        _fertilizePlant = fertilizePlant,
        _pesticidePlant = pesticidePlant,
        _signOut = signOut,
        _geminiService = geminiService,
        _getWeatherRecommendation = getWeatherRecommendation,
        _cityDataSource = cityDataSource,
        _weatherDataSource = weatherDataSource;

  final GetPlantsUseCase _getPlants;
  final SavePlantUseCase _savePlant;
  final DeletePlantUseCase _deletePlant;
  final WaterPlantUseCase _waterPlant;
  final FertilizePlantUseCase _fertilizePlant;
  final PesticidePlantUseCase _pesticidePlant;
  final SignOutUseCase _signOut;
  final GeminiService _geminiService;
  final GetWeatherRecommendationUseCase _getWeatherRecommendation;
  final CityDataSource _cityDataSource;
  final WeatherRemoteDataSource _weatherDataSource;

  HomeUiStatus status = HomeUiStatus.idle;
  String? errorMessage;
  List<Plant> plants = [];

  // ─── 날씨 추천 카드 상태 ────────────────────────────────────────────────────
  RecommendationStatus recommendationStatus = RecommendationStatus.idle;
  String? recommendationText;
  bool weatherRecommendationEnabled = true;
  String? selectedCity;

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

  // ─── 날씨 추천 설정 + 영속 캐시 + 선택 도시 로드 (initState에서 호출) ──────
  Future<void> loadWeatherRecommendationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    weatherRecommendationEnabled =
        prefs.getBool(_prefKeyWeatherEnabled) ?? true;
    selectedCity = await _cityDataSource.getSelectedCityName();
    _tryLoadPersistedRecommendation(prefs);
    notifyListeners();
  }

  /// 도시를 변경하고 날씨 캐시를 무효화한 뒤 추천을 재로드한다.
  Future<void> setCity(String cityName) async {
    await _cityDataSource.saveCity(cityName);
    selectedCity = cityName;

    // OWM 메모리 캐시 무효화 (이전 도시의 날씨 데이터 제거)
    _weatherDataSource.invalidateCache();

    // 영속 추천 캐시 삭제 (이전 도시 기준 Gemini 텍스트 제거)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyRecText);
    await prefs.remove(_prefKeyRecSlot);
    await prefs.remove(_prefKeyRecDate);

    recommendationText = null;
    recommendationStatus = RecommendationStatus.idle;
    notifyListeners();

    await loadWeatherRecommendation();
  }

  /// SharedPreferences에서 추천 텍스트를 읽어 현재 슬롯·날짜와 일치하면 즉시 적용
  void _tryLoadPersistedRecommendation(SharedPreferences prefs) {
    final text = prefs.getString(_prefKeyRecText);
    final slotStr = prefs.getString(_prefKeyRecSlot);
    final date = prefs.getString(_prefKeyRecDate);
    if (text == null || slotStr == null || date == null) return;

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentSlotStr = (now.hour >= 6 && now.hour < 18) ? 'morning' : 'evening';

    if (slotStr == currentSlotStr && date == todayStr) {
      recommendationText = text;
      recommendationStatus = RecommendationStatus.success;
    }
  }

  /// 추천 텍스트를 현재 슬롯·날짜와 함께 SharedPreferences에 저장
  Future<void> _persistRecommendation(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final slotStr = (now.hour >= 6 && now.hour < 18) ? 'morning' : 'evening';
    await prefs.setString(_prefKeyRecText, text);
    await prefs.setString(_prefKeyRecSlot, slotStr);
    await prefs.setString(_prefKeyRecDate, todayStr);
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
  /// - 영속 캐시(SharedPreferences)가 유효하면 GPS·OWM·Gemini 파이프라인 전체 생략
  /// - 캐시 미스 시 전체 파이프라인 실행 후 결과를 SharedPreferences에 저장
  /// - 오류 발생 시 설정을 자동으로 OFF로 전환한다.
  Future<void> loadWeatherRecommendation() async {
    if (!weatherRecommendationEnabled) return;
    // 영속 캐시가 이미 로드된 경우 전체 파이프라인 생략
    if (recommendationStatus == RecommendationStatus.success &&
        recommendationText != null) return;

    recommendationStatus = RecommendationStatus.loading;
    notifyListeners();

    final result = await _getWeatherRecommendation(plants);
    switch (result) {
      case Success(:final data):
        recommendationText = data;
        recommendationStatus = RecommendationStatus.success;
        await _persistRecommendation(data);
      case Failure(:final error, :final message):
        debugPrint('[HomeViewModel] 날씨 추천 오류: $message');
        recommendationText = null;
        if (error == 'no_city_selected' || error == 'city_not_found') {
          // 도시 미선택: 설정 저장 없이 카드만 숨김 (도시 선택 후 자동 복구)
          recommendationStatus = RecommendationStatus.idle;
        } else {
          // 실제 오류(네트워크·API 등): 설정 영구 OFF
          recommendationStatus = RecommendationStatus.error;
          await setWeatherRecommendationEnabled(false);
        }
    }
    notifyListeners();
  }

  /// 날씨 카드는 슬롯 경계(06:00/18:00)에만 갱신하므로
  /// 식물 추가·수정·삭제 시 카드를 그대로 유지한다.
  void invalidateRecommendationCache() {}

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

  static const _historyLimit = 3;

  List<String> _trimHistory(List<String> history, String today) {
    final updated = [...history];
    if (!updated.contains(today)) updated.add(today);
    return updated.length > _historyLimit
        ? updated.sublist(updated.length - _historyLimit)
        : updated;
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
        wateringHistory: _trimHistory(p.wateringHistory, today),
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
        fertilizerHistory: _trimHistory(p.fertilizerHistory, today),
      );
    }).toList();
    notifyListeners();
    return true;
  }

  /// 선택된 식물들에 농약 주기 병렬 기록 후 로컬 상태만 갱신 (네트워크 재조회 없음)
  Future<bool> pesticidePlants(Set<String> plantIds, String today) async {
    final results = await Future.wait(
      plantIds.map((id) => _pesticidePlant(id, today)),
    );
    for (final result in results) {
      if (result case Failure(:final message)) return _fail(message);
    }
    plants = plants.map((p) {
      if (!plantIds.contains(p.id)) return p;
      return p.copyWith(
        pesticideHistory: _trimHistory(p.pesticideHistory, today),
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
