import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Intent 분류 결과
/// - [allPlants] : 전체 식물 데이터를 RAG 컨텍스트로 주입
/// - [noRag]     : 사용자 데이터 없이 Gemini 자체 지식으로 답변
enum _QueryIntent { allPlants, noRag }

/// 식물 이름 캐시에 사용되는 경량 엔트리 (이름 + Firestore doc ID만 보관)
class _PlantEntry {
  final String id;
  final String name;
  const _PlantEntry({required this.id, required this.name});
}

/// Gemini 모델 초기화·세션 관리·API 호출을 담당하는 서비스
///
/// [RAG 전략 — 동적 선택적 주입]
///   1단계 (방법 2): 사용자 질문에서 등록된 식물 이름 키워드를 탐색
///     → 매칭 성공: 해당 식물 데이터만 Firestore에서 fetch 후 주입
///   2단계 (방법 1, 폴백): Gemini로 Intent 경량 분류
///     → ALL_PLANTS : 전체 식물 데이터 주입 (집합형 질문)
///     → NO_RAG     : 식물 데이터 없이 Gemini 자체 지식으로 답변
class GeminiService {
  static const String _modelName = 'gemini-3.5-flash';

  // ─── 페르소나 + 프롬프트 증강 지침 ───────────────────────────────────────
  static const String _personaSystemInstruction = '''
# 역할
너는 한국의 식물 환경에 정통한 '전문 원예학자'이자 친절한 '반려식물 관리사'야. 사용자가 텍스트나 사진으로 식물에 대해 질문하면, 다음 지침에 따라 전문가적이고 다정한 팁을 제공해.

# 주요 지침
1. 식별 및 추론: 처음 보는 식물의 사진이나 특징이 주어지면, 가장 확률이 높은 식물명과 그 근거를 제시해.
2. 맞춤형 정보 제공: 해당 식물의 야생 서식 환경을 기반으로 추천 흙 배합, 영양 정보, 적정 빛의 세기, 통풍 조건 등을 간단히 알려줘.
3. 다국어 지식 활용: 국내에 키우기 정보가 부족한 희귀 식물이라면, 해외 커뮤니티나 식물학 논문에 기반한 지식을 적극 활용하여 한국어로 쉽게 풀어서 설명해.

# 예외 및 대화 규칙
* 병충해 질문 시: 사용자의 정보가 모호하다면, 잎의 증상이나 해충의 생김새(색깔, 크기 등)를 조금 더 구체적으로 묘사해 달라고 정중히 부탁해.
* 정보 부족 시: 사진이 너무 흐리거나 텍스트 정보가 부족해 정확한 진단이 어렵다면, 무리해서 추측하지 말고 정중하게 추가 사진이나 설명을 요청해.
* 말투: 항상 사용자를 존중하고 다정하며 친절한 전문가의 어조를 유지해.

# 사용자 식물 데이터 활용 지침 (프롬프트 증강)
대화 맥락 앞부분에 "[ 사용자 등록 식물 정보 ]" 섹션이 제공될 수 있어.
이 섹션이 있을 때 반드시 아래 규칙을 따라줘.

* 질문이 특정 식물과 관련되면, 해당 식물의 등록 정보(물 주기, 비료 이력, 메모 등)를 일반 지식보다 우선해서 답변에 반영해.
* "내 식물", "우리 집 애", "얘" 같은 지시어가 나오면 등록 목록과 대화 문맥을 함께 보고 가장 연관된 식물을 추론해.
* 물·비료 주기 질문이라면 제공된 날짜와 주기를 직접 계산해서 "앞으로 N일 후 물이 필요해요" 처럼 구체적인 수치로 안내해.
* 사용자 메모에 증상이 적혀 있다면 그 내용도 진단에 반드시 반영해.
* 등록된 식물이 없거나 질문과 무관한 경우, 섹션을 무시하고 일반 전문 지식으로 답변해.
* 사용자가 물어본 질문의 의도에만 답변하고 질문의 의도와 관계없는 내용은 출력하지 말아줘.
''';

  late GenerativeModel _model;
  ChatSession? _chatSession;

  // ─── 전체 RAG 컨텍스트 캐시 (ALL_PLANTS 인텐트용, 5분 TTL) ───────────────
  String? _cachedRagContext;
  DateTime? _ragCachedAt;
  String? _ragCachedUid;
  static const _ragCacheTtl = Duration(minutes: 5);

  // ─── 식물 이름 캐시 (키워드 매칭용, 10분 TTL) ────────────────────────────
  List<_PlantEntry>? _plantNameCache;
  DateTime? _nameCachedAt;
  String? _nameCachedUid;
  static const _nameCacheTtl = Duration(minutes: 10);

  /// 식물 추가·수정·삭제 후 호출해 RAG 캐시와 이름 캐시를 모두 무효화
  void invalidateRagCache() {
    _cachedRagContext = null;
    _ragCachedAt = null;
    _ragCachedUid = null;
    _plantNameCache = null;
    _nameCachedAt = null;
    _nameCachedUid = null;
    debugPrint('[GeminiService] RAG 캐시 + 이름 캐시 무효화');
  }

  /// ServiceLocator.init() 에서 호출 — Firebase 초기화 이후에 실행되어야 한다.
  void init() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.system(_personaSystemInstruction),
    );
  }

  // ─── STEP 1: 식물 이름 캐시 로드 (이름 + ID만, 초경량) ───────────────────
  // 전체 데이터 대신 이름과 doc ID만 캐싱해 메모리·지연을 최소화한다. (전체 식물 이름 doc ID)
  Future<List<_PlantEntry>> _getPlantNameCache(String uid) async {
    final now = DateTime.now();
    if (_plantNameCache != null &&
        _nameCachedUid == uid &&
        _nameCachedAt != null &&
        now.difference(_nameCachedAt!) < _nameCacheTtl) {
      debugPrint('[GeminiService] 식물 이름 캐시 사용');
      return _plantNameCache!;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plants')
          .get();

      _plantNameCache = snapshot.docs
          .map((doc) => _PlantEntry(
                id: doc.id,
                name: (doc.data()['name'] as String? ?? '').trim(),
              ))
          .where((e) => e.name.isNotEmpty)
          .toList();
      _nameCachedAt = now;
      _nameCachedUid = uid;
      debugPrint('[GeminiService] 식물 이름 캐시 갱신: ${_plantNameCache!.length}개');
      return _plantNameCache!;
    } catch (e) {
      debugPrint('[GeminiService] 식물 이름 캐시 로드 실패: $e');
      return [];
    }
  }

  // ─── STEP 2: 키워드 매칭 (방법 2 — 클라이언트, 추가 비용 없음) ────────────
  // 사용자 질문 텍스트에서 등록된 식물 이름이 포함되어 있는지 탐색한다.
  // 복수 식물이 언급된 경우 모두 반환한다. (dod ID)
  List<String> _matchPlantNames(String text, List<_PlantEntry> plants) {
    final lower = text.toLowerCase();
    final matched = plants
        .where((p) => lower.contains(p.name.toLowerCase()))
        .map((p) => p.id)
        .toList();
    if (matched.isNotEmpty) {
      debugPrint('[GeminiService] 키워드 매칭 성공: ${matched.length}개 식물 ID');
    }
    return matched;
  }

  // ─── STEP 3: Intent 분류 (방법 1 — 폴백, Gemini 경량 호출) ──────────────
  // 키워드 매칭 실패 시에만 호출된다. Gemini에게 한 줄 분류만 요청해 비용·지연을 줄인다.
  // 오류 발생 시 allPlants로 안전하게 폴백한다.(매칭 키워드 못찾을 시 전체 식물 데이터가 필요한지 아닌지)
  Future<_QueryIntent> _classifyIntent(
    String text,
    List<_PlantEntry> plants,
    bool hasImage,
  ) async {
    final plantNameList =
        plants.isEmpty ? '없음' : plants.map((p) => p.name).join(', ');
    final imageNote = hasImage ? '\n(사진이 함께 첨부됨)' : '';

    final classifyPrompt = '''
다음 질문을 분류해. 반드시 "ALL_PLANTS" 또는 "NO_RAG" 중 하나만 출력해. 다른 말은 절대 하지 마.

등록된 식물 목록: $plantNameList
질문: "$text"$imageNote

분류 기준:
- ALL_PLANTS: 사용자가 등록한 전체 식물들의 데이터가 필요한 질문 (예: "내 식물 중 물 줘야 하는 거", "다 어때", "전체 상태")
- NO_RAG: 사용자 식물 데이터 없이 답변 가능 (일반 원예 지식, 모르는 식물 식별, 사진만으로 진단 가능한 경우)
''';

    try {
      final response =
          await _model.generateContent([Content.text(classifyPrompt)]);
      final result = (response.text ?? '').trim().toUpperCase();
      debugPrint('[GeminiService] Intent 분류 결과: $result');
      if (result.contains('NO_RAG')) return _QueryIntent.noRag;
      return _QueryIntent.allPlants;
    } catch (e) {
      debugPrint('[GeminiService] Intent 분류 실패, ALL_PLANTS로 폴백: $e');
      return _QueryIntent.allPlants;
    }
  }

  // ─── RAG: 특정 식물 doc ID 목록만 fetch ───────────────────────────────────
  // 키워드 매칭 성공 시 사용. 해당 식물 문서만 개별 조회한다. (.doc(id).get()으로 Firebase 조회)
  Future<String> _buildRagContextForIds(String uid, List<String> ids) async {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('[ 사용자 등록 식물 정보 ] (기준일: $todayStr)');
    buffer.writeln('아래는 사용자가 앱에 등록한 반려식물 목록입니다. 질문 답변 시 이 정보를 우선 참고하세요.');
    buffer.writeln('');

    int idx = 1;
    for (final id in ids) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('plants')
            .doc(id)
            .get();
        if (!doc.exists) continue;
        _appendPlantData(buffer, doc.data()!, idx, today);
        idx++;
      } catch (e) {
        debugPrint('[GeminiService] 식물 데이터 fetch 실패 (id: $id): $e');
      }
    }

    if (idx == 1) return '';
    buffer.writeln('[ 식물 정보 끝 ]');
    return buffer.toString();
  }

  // ─── RAG: 전체 식물 목록 fetch (집합형 질문용, 5분 캐시) ──────────────────
  Future<String> _buildRagContext(String uid) async {
    final now = DateTime.now();
    if (_cachedRagContext != null &&
        _ragCachedUid == uid &&
        _ragCachedAt != null &&
        now.difference(_ragCachedAt!) < _ragCacheTtl) {
      debugPrint('[GeminiService] 전체 RAG 캐시 사용 (Firestore 조회 생략)');
      return _cachedRagContext!;
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plants')
          .get();
    } catch (e) {
      debugPrint('[GeminiService] RAG Firestore 조회 실패: $e');
      return '';
    }

    if (snapshot.docs.isEmpty) {
      _cachedRagContext = '';
      _ragCachedAt = now;
      _ragCachedUid = uid;
      return '';
    }

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('[ 사용자 등록 식물 정보 ] (기준일: $todayStr)');
    buffer.writeln('아래는 사용자가 앱에 등록한 반려식물 목록입니다. 질문 답변 시 이 정보를 우선 참고하세요.');
    buffer.writeln('');

    for (int i = 0; i < snapshot.docs.length; i++) {
      _appendPlantData(buffer, snapshot.docs[i].data(), i + 1, today);
    }

    buffer.writeln('[ 식물 정보 끝 ]');
    _cachedRagContext = buffer.toString();
    _ragCachedAt = now;
    _ragCachedUid = uid;
    return _cachedRagContext!;
  }

  // ─── 공통: 식물 데이터 Map → 텍스트 블록으로 변환 ───────────────────────
  void _appendPlantData(
    StringBuffer buffer,
    Map<String, dynamic> data,
    int idx,
    DateTime today,
  ) {
    final name = data['name'] as String? ?? '이름 없음';
    final categories = List<String>.from(data['categories'] ?? []);
    final wateringFreq = (data['watering_frequency'] as num?)?.toInt() ?? 0;
    final lastWatered = data['last_watered'] as String? ?? '';
    final fertilizerHistory =
        List<String>.from(data['fertilizer_history'] ?? []);
    final notes = data['notes'] as String? ?? '';

    buffer.writeln('[식물 $idx] $name');
    buffer.writeln(
        '  - 분류: ${categories.isEmpty ? '미지정' : categories.join(', ')}');
    buffer.writeln('  - 물 주기: $wateringFreq일마다');

    if (lastWatered.isNotEmpty) {
      try {
        final lastDate = DateTime.parse(lastWatered);
        final daysSince = today
            .difference(
                DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;
        final daysUntilNext = wateringFreq - daysSince;
        final waterStatus = daysUntilNext <= 0
            ? '⚠️ $daysSince일 전 — 지금 물이 필요해요!'
            : '$daysSince일 전 — $daysUntilNext일 후 물 주세요';
        buffer.writeln('  - 마지막 물 준 날: $lastWatered ($waterStatus)');
      } catch (_) {
        buffer.writeln('  - 마지막 물 준 날: $lastWatered');
      }
    } else {
      buffer.writeln('  - 마지막 물 준 날: 기록 없음');
    }

    if (fertilizerHistory.isNotEmpty) {
      final lastFert = fertilizerHistory.last;
      try {
        final fertDate = DateTime.parse(lastFert);
        final fertDays = today
            .difference(
                DateTime(fertDate.year, fertDate.month, fertDate.day))
            .inDays;
        buffer.writeln('  - 마지막 비료 준 날: $lastFert ($fertDays일 전)');
      } catch (_) {
        buffer.writeln('  - 마지막 비료 준 날: $lastFert');
      }
    } else {
      buffer.writeln('  - 마지막 비료 준 날: 기록 없음');
    }

    buffer.writeln(
        '  - 사용자 메모: ${notes.trim().isEmpty ? '없음' : notes.trim()}');
    buffer.writeln('');
  }

  /// Gemini 모델에 메시지를 전송하고 응답 텍스트를 반환한다.
  ///
  /// [동적 RAG 흐름]
  ///   1) 식물 이름 캐시에서 키워드 매칭 (추가 비용 없음)
  ///      → 성공: 매칭 식물 데이터만 fetch
  ///   2) 매칭 실패 시 Gemini Intent 분류 (경량 호출 1회)
  ///      → ALL_PLANTS : 전체 식물 데이터 fetch
  ///      → NO_RAG     : 데이터 없이 Gemini 자체 지식으로 답변
  ///
  /// [정보 부족 케이스 처리]
  ///   - 사진 흐림/텍스트 부족: 시스템 지침에 따라 Gemini가 추가 정보 요청
  ///   - 등록되지 않은 식물 언급: RAG 없이 Gemini 일반 지식으로 답변
  ///   - Firestore 오류: ragContext = '' 로 폴백, Gemini 호출은 계속 진행
  ///   - Intent 분류 오류: allPlants 로 안전하게 폴백
  Future<String> sendMessage({
    required String uid,
    required String text,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    _chatSession ??= _model.startChat();

    // STEP 1: 전체 식물 이름 캐시 로드(doc ID,이름)
    final plantEntries = await _getPlantNameCache(uid);

    String ragContext;

    // STEP 2: 키워드 매칭(사용자 질문에 해당되는 doc ID 반환)
    final matchedIds = _matchPlantNames(text, plantEntries);

    if (matchedIds.isNotEmpty) {
      // 매칭된 식물 데이터만 fetch (가장 빠른 경로) (doc ID 기반으로 Firebase 조회)
      ragContext = await _buildRagContextForIds(uid, matchedIds);
    } else {
      // STEP 3: Intent 분류 (폴백) (매칭 키워드 못찾을 시 전체 식물 데이터가 필요한지 아닌지)
      final intent =
          await _classifyIntent(text, plantEntries, imageBytes != null);

      if (intent == _QueryIntent.allPlants) {
        debugPrint('[GeminiService] Intent: ALL_PLANTS → 전체 fetch'); //(Gemini intent 분류 호출)
        ragContext = await _buildRagContext(uid);
      } else {
        debugPrint('[GeminiService] Intent: NO_RAG → 데이터 없이 답변'); //(Gemini intent 분류 호출)
        ragContext = '';
      }
    }

    final promptText =
        ragContext.isEmpty ? text : '$ragContext\n사용자 질문: $text';

    // 이미지 유무에 따라 Content 구성 분기
    final Content content;
    if (imageBytes != null) {
      content = Content.multi([
        TextPart(promptText),
        InlineDataPart(mimeType, imageBytes),
      ]);
    } else {
      content = Content.text(promptText);
    }

    debugPrint('[GeminiService] 메시지 전송 (이미지: ${imageBytes != null})');
    final response = await _chatSession!.sendMessage(content);
    debugPrint(
        '[GeminiService] 응답 수신: ${response.text?.substring(0, response.text!.length.clamp(0, 80))}...');
    return response.text ?? '';
  }

  /// 현재 멀티턴 세션을 폐기한다. 다음 sendMessage 호출 시 새 세션이 생성된다.
  void resetSession() {
    _chatSession = null;
  }
}
