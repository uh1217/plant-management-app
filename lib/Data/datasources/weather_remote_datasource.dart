import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/Data/models/weather_forecast_dto.dart';
import 'package:plantapp_p/Domain/entities/weather_forecast.dart';

/// OpenWeatherMap /data/2.5/forecast 호출 및 날씨 집계 담당 데이터 소스
///
/// API 키는 --dart-define=OWM_API_KEY=xxx 빌드 인수로 주입한다.
/// 슬롯 기반 메모리 캐시를 적용해 슬롯 경계(06:00/18:00) 전까지 재조회를 생략한다.
class WeatherRemoteDataSource {
  static const String _apiKey =
      String.fromEnvironment('OWM_API_KEY', defaultValue: '');
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/forecast';

  WeatherForecast? _cachedForecast;
  RecommendationSlot? _cachedSlot;
  DateTime? _cachedAt;

  bool _isCacheValid(RecommendationSlot requestedSlot) {
    if (_cachedForecast == null || _cachedSlot == null || _cachedAt == null) {
      return false;
    }
    if (_cachedSlot != requestedSlot) return false;
    final now = DateTime.now();
    final slotStart = requestedSlot == RecommendationSlot.morning
        ? DateTime(now.year, now.month, now.day, 6, 0)
        : DateTime(now.year, now.month, now.day, 18, 0);
    return _cachedAt!.isAfter(slotStart);
  }

  Future<Result<WeatherForecast>> getForecast({
    required double lat,
    required double lon,
    required RecommendationSlot slot,
  }) async {
    if (_isCacheValid(slot)) {
      debugPrint('[WeatherRemoteDataSource] 슬롯 캐시 사용 (API 재조회 생략)');
      return Success(_cachedForecast!);
    }

    if (_apiKey.isEmpty) {
      return const Failure(error: 'no_api_key', message: 'OWM_API_KEY가 설정되지 않았습니다. --dart-define=OWM_API_KEY=xxx 로 빌드하세요.');
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&lang=ko&cnt=16',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 429) {
        return const Failure(error: 'rate_limit', message: '날씨 API 요청 한도를 초과했습니다. (HTTP 429)');
      }
      if (response.statusCode != 200) {
        return Failure(error: 'http_error_${response.statusCode}', message: '날씨 API 오류: HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final list = json['list'] as List<dynamic>;

      // 대상 날짜 결정 (오전=오늘, 오후=내일)
      final now = DateTime.now();
      final targetDate = slot == RecommendationSlot.morning
          ? _formatDate(now)
          : _formatDate(now.add(const Duration(days: 1)));

      // 대상 날짜의 슬롯만 필터링
      final slots = list
          .map((e) => ForecastSlotDto.fromJson(e as Map<String, dynamic>))
          .where((s) => s.date == targetDate)
          .toList();

      // API 응답에 대상 날짜 데이터가 없으면 첫 번째 날짜 데이터로 대체
      final effectiveSlots = slots.isNotEmpty
          ? slots
          : list
              .map((e) => ForecastSlotDto.fromJson(e as Map<String, dynamic>))
              .take(8)
              .toList();

      final effectiveDate =
          slots.isNotEmpty ? targetDate : effectiveSlots.first.date;

      final forecast = WeatherForecastAggregator.aggregate(
        slots: effectiveSlots,
        targetDate: effectiveDate,
        slot: slot,
      );

      _cachedForecast = forecast;
      _cachedSlot = slot;
      _cachedAt = DateTime.now();
      debugPrint(
          '[WeatherRemoteDataSource] 날씨 취득: ${forecast.weatherCondition}, ${forecast.maxTemp}°C, 습도 ${forecast.avgHumidity}%');
      return Success(forecast);
    } catch (e) {
      debugPrint('[WeatherRemoteDataSource] 오류: $e');
      return Failure(error: e, message: '날씨 정보를 가져올 수 없습니다.');
    }
  }

  static String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void invalidateCache() {
    _cachedForecast = null;
    _cachedSlot = null;
    _cachedAt = null;
  }
}
