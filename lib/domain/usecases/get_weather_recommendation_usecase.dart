import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/data/datasources/city_datasource.dart';
import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/domain/repositories/weather_repository.dart';
import 'package:plantapp_p/core/services/weather_recommendation_service.dart';

/// 도시 좌표 → 날씨 예보 → Gemini 추천 멘트 생성 파이프라인 UseCase
class GetWeatherRecommendationUseCase {
  final CityDataSource _city;
  final WeatherRepository _weather;
  final WeatherRecommendationService _recommendation;

  const GetWeatherRecommendationUseCase({
    required CityDataSource city,
    required WeatherRepository weather,
    required WeatherRecommendationService recommendation,
  })  : _city = city,
        _weather = weather,
        _recommendation = recommendation;

  Future<Result<String>> call(List<Plant> plants) async {
    // 1. 선택된 도시 좌표 취득
    final posResult = await _city.getPosition();
    if (posResult is Failure) {
      final f = posResult as Failure;
      return Failure(error: f.error, message: f.message);
    }
    final pos = (posResult as Success<({double lat, double lon})>).data;

    // 2. 현재 슬롯에 맞는 날씨 예보 취득 (캐시 적용)
    final slot = WeatherRecommendationService.currentSlot();
    final forecastResult = await _weather.getForecast(
      lat: pos.lat,
      lon: pos.lon,
      slot: slot,
    );
    if (forecastResult is Failure) {
      final f = forecastResult as Failure;
      return Failure(error: f.error, message: f.message);
    }
    final forecast = (forecastResult as Success).data;

    // 3. Gemini one-shot 추천 멘트 생성 (슬롯 캐시 적용)
    return _recommendation.getRecommendation(forecast, plants);
  }
}
