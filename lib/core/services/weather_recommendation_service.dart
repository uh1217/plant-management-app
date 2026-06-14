import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/plant.dart';
import 'package:plantapp_p/Domain/entities/weather_forecast.dart';

/// 날씨 + 식물 상태 기반 오늘의 식물 케어 추천 멘트 생성 서비스
///
/// [설계 원칙]
/// - 챗봇용 GeminiService와 완전히 분리된 독립 서비스
/// - ChatSession 없이 one-shot generateContent 호출
/// - 오전/오후 슬롯 기반 캐시: 슬롯 경계(06:00/18:00) 이후에 캐싱된 결과만 유효
class WeatherRecommendationService {
  static const String _modelName = 'gemini-3.5-flash';

  // ─── 페르소나 + 출력 규칙 ──────────────────────────────────────────────────
  static const String _personaSystemInstruction = '''
# 역할
너는 매일 아침(오전 슬롯)과 저녁(오후 슬롯)에 날씨 예보를 바탕으로 반려식물 관리를 도와주는 '오늘의 식물 케어 알리미'야.

# 출력 규칙
1. 순수 텍스트만 출력. 마크다운(**굵게**, *, ##, - 목록 등) 절대 금지.
2. 전체 2~3문장 이내.
3. 이모티콘은 최대 1개만 허용 (문장 끝에만 배치).
4. 숫자 데이터를 구체적으로 언급해. (예: "30°C", "습도 45%", "강한 바람")

# 멘트 구성 규칙
문장 1: 날씨 상태 + 최고·최저 기온 + 평균 습도 + 바람 강도를 1문장으로 자연스럽게 요약.
문장 2~3: 아래 우선순위에 따라 결정.

  [우선순위 1] 오늘(오전) 또는 내일(오후) 물이 필요한 식물이 있으면
    → 날씨와 연결해 물 주기 구체적 조언
    예) 비 예상, 고습도 → "물 주기를 하루 미루세요"
    예) 맑음, 저습도 → "충분히 흘러나올 정도로 흠뻑 적셔주세요"
    예) 강한 바람 → "물 준 뒤 화분이 넘어지지 않게 주의하세요"

  [우선순위 2] 물이 필요한 식물이 없으면
    → 날씨 기반 일반 케어 팁 1문장
    예) 강한 햇빛/고온 → "직사광선을 피해 반그늘로 이동 권장"
    예) 비/고습 → "통풍을 줄이고 과습에 주의하세요"
    예) 건조/저습 → "분무기로 잎 표면에 수분 공급을 권장해요"
    예) 강한 바람 → "야외 화분은 실내로 이동하세요"

  [우선순위 3] 등록 식물이 없으면
    → 날씨 요약 1문장 + "식물을 등록하면 맞춤 케어 알림을 드려요!"

# 시간대 시작 단어 (반드시 준수)
- 오전 슬롯(06:00~17:59 기준): 반드시 "오늘은 " 으로 시작
- 오후 슬롯(18:00~05:59 기준): 반드시 "내일은 " 으로 시작

# 출력 예시 (오전 슬롯, 맑음, 고온 건조, 물 필요 식물 있음)
오늘은 맑고 최고 30°C, 습도 20%, 강한 바람이 예상돼요. 몬스테라와 아이비에 물이 충분히 흘러나올 정도로 흠뻑 적셔주세요. 강한 바람에 화분이 넘어질 수 있으니 주의하세요 🌿

# 출력 예시 (오후 슬롯, 비 예상, 물 필요 없음)
내일은 비가 내릴 예정으로 최고 22°C, 습도 85%가 예상돼요. 실내 식물의 통풍을 줄이고 과습에 주의하세요.
''';

  late GenerativeModel _model;

  // ─── 슬롯 기반 캐시 ────────────────────────────────────────────────────────
  String? _cachedRecommendation;
  RecommendationSlot? _cachedSlot;
  DateTime? _cachedAt;

  void init() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.system(_personaSystemInstruction),
    );
  }

  /// 현재 시각 기준 슬롯 반환 (static: UseCase에서도 참조 가능)
  static RecommendationSlot currentSlot() {
    final hour = DateTime.now().hour;
    return (hour >= 6 && hour < 18)
        ? RecommendationSlot.morning
        : RecommendationSlot.evening;
  }

  bool _isCacheValid() {
    if (_cachedRecommendation == null ||
        _cachedSlot == null ||
        _cachedAt == null) {
      return false;
    }
    final slot = currentSlot();
    if (_cachedSlot != slot) return false;
    final now = DateTime.now();
    final slotStart = slot == RecommendationSlot.morning
        ? DateTime(now.year, now.month, now.day, 6, 0)
        : DateTime(now.year, now.month, now.day, 18, 0);
    return _cachedAt!.isAfter(slotStart);
  }

  /// 슬롯 캐시 무효화 (식물 목록 변경 시 HomeViewModel에서 호출)
  void invalidateCache() {
    _cachedRecommendation = null;
    _cachedSlot = null;
    _cachedAt = null;
  }

  // ─── RAG 컨텍스트 빌더 ─────────────────────────────────────────────────────
  String _buildPrompt(WeatherForecast forecast, List<Plant> plants) {
    final slot = currentSlot();
    final slotLabel =
        slot == RecommendationSlot.morning ? '오늘 (오전 슬롯)' : '내일 (오후 슬롯)';
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('[날씨 기반 식물 케어 추천]');
    buffer.writeln('조회 기준: $slotLabel 날씨 (${forecast.targetDate})');
    buffer.writeln('기준일: $todayStr');
    buffer.writeln('');

    buffer.writeln('날씨 예상:');
    buffer.writeln('  - 날씨 상태: ${forecast.weatherCondition}');
    buffer.writeln(
        '  - 최고 기온: ${forecast.maxTemp.toStringAsFixed(0)}°C / 최저 기온: ${forecast.minTemp.toStringAsFixed(0)}°C');
    buffer.writeln('  - 평균 습도: ${forecast.avgHumidity}%');
    buffer.writeln(
        '  - 바람 강도: ${forecast.windStrengthLabel} (${forecast.maxWindSpeed.toStringAsFixed(1)}m/s)');
    buffer.writeln('');

    if (plants.isEmpty) {
      buffer.writeln('등록된 식물: 없음');
      buffer.writeln('[컨텍스트 끝]');
      return buffer.toString();
    }

    // 물이 필요한 식물 분류
    final needWater = <Plant>[];
    final soonWater = <Plant>[];

    for (final plant in plants) {
      try {
        final lastDate = DateTime.parse(plant.lastWatered);
        final today0 = DateTime(today.year, today.month, today.day);
        final last0 = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final daysSince = today0.difference(last0).inDays;
        final daysUntil = plant.wateringFrequency - daysSince;
        if (daysUntil <= 0) {
          needWater.add(plant);
        } else if (daysUntil <= 2) {
          soonWater.add(plant);
        }
      } catch (_) {
        // 날짜 파싱 실패 시 건너뜀
      }
    }

    if (needWater.isNotEmpty) {
      buffer.writeln('오늘 물 주기가 필요한 식물 (${needWater.length}개):');
      for (int i = 0; i < needWater.length; i++) {
        final p = needWater[i];
        try {
          final lastDate = DateTime.parse(p.lastWatered);
          final today0 = DateTime(today.year, today.month, today.day);
          final last0 =
              DateTime(lastDate.year, lastDate.month, lastDate.day);
          final daysSince = today0.difference(last0).inDays;
          buffer.writeln(
              '  ${i + 1}. ${p.name} — 마지막 물 ${daysSince}일 전 (⚠️ 지금 필요)');
        } catch (_) {
          buffer.writeln('  ${i + 1}. ${p.name} — ⚠️ 지금 필요');
        }
      }
      buffer.writeln('');
    } else {
      buffer.writeln('오늘 물 주기가 필요한 식물: 없음');
      buffer.writeln('');
    }

    if (soonWater.isNotEmpty) {
      buffer.writeln('물 주기 임박 (1~2일 이내, ${soonWater.length}개):');
      for (int i = 0; i < soonWater.length; i++) {
        final p = soonWater[i];
        try {
          final lastDate = DateTime.parse(p.lastWatered);
          final today0 = DateTime(today.year, today.month, today.day);
          final last0 =
              DateTime(lastDate.year, lastDate.month, lastDate.day);
          final daysSince = today0.difference(last0).inDays;
          final daysUntil = p.wateringFrequency - daysSince;
          buffer.writeln('  ${i + 1}. ${p.name} — ${daysUntil}일 후 필요');
        } catch (_) {
          buffer.writeln('  ${i + 1}. ${p.name}');
        }
      }
      buffer.writeln('');
    }

    buffer.writeln('전체 식물 현황:');
    buffer.writeln('  - 등록 식물: ${plants.length}개');

    final categoryCount = <String, int>{};
    for (final p in plants) {
      for (final c in p.categories) {
        categoryCount[c] = (categoryCount[c] ?? 0) + 1;
      }
    }
    if (categoryCount.isNotEmpty) {
      final summary =
          categoryCount.entries.map((e) => '${e.key} ${e.value}개').join(', ');
      buffer.writeln('  - 분류: $summary');
    }

    buffer.writeln('[컨텍스트 끝]');
    return buffer.toString();
  }

  // ─── Gemini one-shot 호출 ──────────────────────────────────────────────────
  Future<Result<String>> getRecommendation(
    WeatherForecast forecast,
    List<Plant> plants,
  ) async {
    if (_isCacheValid()) {
      debugPrint('[WeatherRecommendationService] 슬롯 캐시 사용 (Gemini 재호출 생략)');
      return Success(_cachedRecommendation!);
    }

    try {
      final prompt = _buildPrompt(forecast, plants);
      debugPrint('[WeatherRecommendationService] Gemini 호출 (슬롯: ${currentSlot().name})');

      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      if (text.isEmpty) {
        return const Failure(error: 'empty_response', message: '추천 멘트를 생성할 수 없습니다.');
      }

      _cachedRecommendation = text.trim();
      _cachedSlot = currentSlot();
      _cachedAt = DateTime.now();
      debugPrint('[WeatherRecommendationService] 생성 완료: ${text.substring(0, text.length.clamp(0, 60))}...');
      return Success(_cachedRecommendation!);
    } catch (e) {
      debugPrint('[WeatherRecommendationService] Gemini 오류: $e');
      return Failure(error: e, message: '추천 멘트 생성 중 오류가 발생했습니다.');
    }
  }
}
