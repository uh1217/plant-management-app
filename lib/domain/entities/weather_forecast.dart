/// 날씨 예보 집계 결과 도메인 엔티티
///
/// OpenWeatherMap /data/2.5/forecast 에서 특정 날짜의 3시간 단위 슬롯들을
/// 집계(dominant 날씨, max/min 기온, 평균 습도, max 풍속)한 결과를 담는다.
enum RecommendationSlot {
  morning, // 06:00~17:59 → 오늘 날씨 기준
  evening, // 18:00~05:59 → 내일 날씨 기준
}

class WeatherForecast {
  final String weatherCondition; // 한국어 날씨 상태 (맑음, 흐림, 비 …)
  final int weatherCode;         // OWM weather id (800, 500 …)
  final double maxTemp;          // 최고 기온 (°C)
  final double minTemp;          // 최저 기온 (°C)
  final int avgHumidity;         // 평균 습도 (%)
  final double maxWindSpeed;     // 최대 풍속 (m/s)
  final String windStrengthLabel; // 한국어 풍속 단계
  final String targetDate;       // 예보 날짜 (YYYY-MM-DD)
  final RecommendationSlot slot; // 생성 슬롯

  const WeatherForecast({
    required this.weatherCondition,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.avgHumidity,
    required this.maxWindSpeed,
    required this.windStrengthLabel,
    required this.targetDate,
    required this.slot,
  });

  /// 풍속(m/s) → 한국어 강도 레이블
  static String windLabel(double speed) {
    if (speed < 3.0) return '잔잔한 바람';
    if (speed < 6.0) return '약한 바람';
    if (speed < 11.0) return '강한 바람';
    return '매우 강한 바람';
  }

  /// OWM weather id → 한국어 날씨 상태
  static String weatherLabel(int code) {
    if (code >= 200 && code < 300) return '천둥번개';
    if (code >= 300 && code < 400) return '이슬비';
    if (code >= 500 && code < 600) return '비';
    if (code >= 600 && code < 700) return '눈';
    if (code >= 700 && code < 800) return '안개·연무';
    if (code == 800) return '맑음';
    if (code == 801 || code == 802) return '구름 조금';
    if (code == 803 || code == 804) return '흐림';
    return '흐림';
  }
}
