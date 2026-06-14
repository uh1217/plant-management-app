import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/Domain/entities/weather_forecast.dart';

abstract interface class WeatherRepository {
  /// [slot]에 해당하는 날짜(오늘/내일)의 날씨 예보를 반환한다.
  Future<Result<WeatherForecast>> getForecast({
    required double lat,
    required double lon,
    required RecommendationSlot slot,
  });
}
