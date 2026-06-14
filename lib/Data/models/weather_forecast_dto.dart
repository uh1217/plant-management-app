import 'package:plantapp_p/Domain/entities/weather_forecast.dart';

/// OpenWeatherMap /data/2.5/forecast 응답의 개별 3시간 슬롯 DTO
class ForecastSlotDto {
  final String dtTxt;      // "2026-06-15 12:00:00"
  final double tempMax;
  final double tempMin;
  final int humidity;
  final double windSpeed;
  final int weatherCode;   // weather[0].id

  const ForecastSlotDto({
    required this.dtTxt,
    required this.tempMax,
    required this.tempMin,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
  });

  factory ForecastSlotDto.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weatherList = json['weather'] as List<dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;

    return ForecastSlotDto(
      dtTxt: json['dt_txt'] as String,
      tempMax: (main['temp_max'] as num).toDouble(),
      tempMin: (main['temp_min'] as num).toDouble(),
      humidity: (main['humidity'] as num).toInt(),
      windSpeed: (wind['speed'] as num).toDouble(),
      weatherCode: (weatherList.first as Map<String, dynamic>)['id'] as int,
    );
  }

  /// dt_txt에서 날짜 부분만 반환 (YYYY-MM-DD)
  String get date => dtTxt.substring(0, 10);
}

/// 특정 날짜의 슬롯들을 집계해 WeatherForecast 엔티티로 변환
class WeatherForecastAggregator {
  /// [slots]: 같은 날짜의 ForecastSlotDto 목록
  static WeatherForecast aggregate({
    required List<ForecastSlotDto> slots,
    required String targetDate,
    required RecommendationSlot slot,
  }) {
    assert(slots.isNotEmpty, 'slots must not be empty');

    // 최고/최저 기온
    final maxTemp = slots.map((s) => s.tempMax).reduce((a, b) => a > b ? a : b);
    final minTemp = slots.map((s) => s.tempMin).reduce((a, b) => a < b ? a : b);

    // 평균 습도
    final avgHumidity =
        (slots.map((s) => s.humidity).reduce((a, b) => a + b) / slots.length)
            .round();

    // 최대 풍속
    final maxWindSpeed =
        slots.map((s) => s.windSpeed).reduce((a, b) => a > b ? a : b);

    // 주요 날씨 코드 (빈도 기준 dominant)
    final codeCount = <int, int>{};
    for (final s in slots) {
      codeCount[s.weatherCode] = (codeCount[s.weatherCode] ?? 0) + 1;
    }
    final dominantCode =
        codeCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return WeatherForecast(
      weatherCondition: WeatherForecast.weatherLabel(dominantCode),
      weatherCode: dominantCode,
      maxTemp: maxTemp,
      minTemp: minTemp,
      avgHumidity: avgHumidity,
      maxWindSpeed: maxWindSpeed,
      windStrengthLabel: WeatherForecast.windLabel(maxWindSpeed),
      targetDate: targetDate,
      slot: slot,
    );
  }
}
