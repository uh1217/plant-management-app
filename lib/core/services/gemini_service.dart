import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Gemini 모델 초기화·세션 관리·API 호출을 담당하는 서비스
///
/// [페르소나]  _personaSystemInstruction 에 정의 (모델 생성 시 systemInstruction으로 고정)
/// [RAG]       _buildRagContext(uid) 가 Firestore 식물 목록을 읽어 매 요청 프롬프트 앞에 주입
class GeminiService {
  static const String _modelName = 'gemini-2.0-flash';

  // ─── 페르소나 + 프롬프트 증강 지침 ───────────────────────────────────────
  // [페르소나] 모델의 역할·말투·대화 규칙
  // [프롬프트 증강] RAG 컨텍스트 블록을 어떻게 활용할지 모델에게 명시
  static const String _personaSystemInstruction = '''
# 역할
너는 한국의 식물 환경에 정통한 '전문 원예학자'이자 친절한 '반려식물 관리사'야. 사용자가 텍스트나 사진으로 식물에 대해 질문하면, 다음 지침에 따라 전문가적이고 다정한 팁을 제공해.

# 주요 지침
1. 식별 및 추론: 처음 보는 식물의 사진이나 특징이 주어지면, 가장 확률이 높은 식물명과 그 근거를 제시해.
2. 맞춤형 정보 제공: 해당 식물의 야생 서식 환경을 기반으로 추천 흙 배합, 영양 정보, 적정 빛의 세기, 통풍 조건 등을 꼼꼼히 알려줘.
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

  /// ServiceLocator.init() 에서 호출 — Firebase 초기화 이후에 실행되어야 한다.
  void init() {
    _model = FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.system(_personaSystemInstruction),
    );
  }

  // ─── RAG: 사용자 식물 목록 전체 주입 (Full Context Injection) ────────────
  // users/{uid}/plants 컬렉션 전체를 읽어 텍스트 블록으로 변환한다.
  // 반환된 문자열은 sendMessage 내부에서 사용자 질문 앞에 자동으로 삽입된다.
  // Firestore 오류 발생 시 빈 문자열을 반환해 Gemini 호출 자체는 계속 진행한다.
  Future<String> _buildRagContext(String uid) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('plants')
          .get();
    } catch (e) {
      // Firestore 권한 오류 등이 발생해도 RAG 없이 진행
      debugPrint('[GeminiService] RAG Firestore 조회 실패: $e');
      return '';
    }

    if (snapshot.docs.isEmpty) return '';

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln('[ 사용자 등록 식물 정보 ] (기준일: $todayStr)');
    buffer.writeln('아래는 사용자가 앱에 등록한 반려식물 목록입니다. 질문 답변 시 이 정보를 우선 참고하세요.');
    buffer.writeln('');

    for (int i = 0; i < snapshot.docs.length; i++) {
      final data = snapshot.docs[i].data();

      final name = data['name'] as String? ?? '이름 없음';
      final categories =
          List<String>.from(data['categories'] ?? []);
      final wateringFreq =
          (data['watering_frequency'] as num?)?.toInt() ?? 0;
      final lastWatered = data['last_watered'] as String? ?? '';
      final fertilizerHistory =
          List<String>.from(data['fertilizer_history'] ?? []);
      final notes = data['notes'] as String? ?? '';

      buffer.writeln('[식물 ${i + 1}] $name');

      // 분류
      buffer.writeln(
          '  - 분류: ${categories.isEmpty ? '미지정' : categories.join(', ')}');

      // 물 주기 및 다음 물 주기 계산
      buffer.writeln('  - 물 주기: ${wateringFreq}일마다');
      if (lastWatered.isNotEmpty) {
        try {
          final lastDate = DateTime.parse(lastWatered);
          final daysSince = today
              .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
              .inDays;
          final daysUntilNext = wateringFreq - daysSince;

          final waterStatus = daysUntilNext <= 0
              ? '⚠️ ${daysSince}일 전 — 지금 물이 필요해요!'
              : '${daysSince}일 전 — ${daysUntilNext}일 후 물 주세요';

          buffer.writeln('  - 마지막 물 준 날: $lastWatered ($waterStatus)');
        } catch (_) {
          buffer.writeln('  - 마지막 물 준 날: $lastWatered');
        }
      } else {
        buffer.writeln('  - 마지막 물 준 날: 기록 없음');
      }

      // 비료 이력 (가장 최근 날짜만 표시)
      if (fertilizerHistory.isNotEmpty) {
        final lastFert = fertilizerHistory.last;
        try {
          final fertDate = DateTime.parse(lastFert);
          final fertDays = today
              .difference(
                  DateTime(fertDate.year, fertDate.month, fertDate.day))
              .inDays;
          buffer.writeln('  - 마지막 비료 준 날: $lastFert (${fertDays}일 전)');
        } catch (_) {
          buffer.writeln('  - 마지막 비료 준 날: $lastFert');
        }
      } else {
        buffer.writeln('  - 마지막 비료 준 날: 기록 없음');
      }

      // 사용자 메모 (증상·특이사항 등 진단에 중요)
      buffer.writeln(
          '  - 사용자 메모: ${notes.trim().isEmpty ? '없음' : notes.trim()}');

      buffer.writeln('');
    }

    buffer.writeln('[ 식물 정보 끝 ]');
    return buffer.toString();
  }

  /// Gemini 모델에 메시지를 전송하고 응답 텍스트를 반환한다.
  /// 세션이 없으면 새 멀티턴 세션을 시작한다.
  Future<String> sendMessage({
    required String uid,
    required String text,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    _chatSession ??= _model.startChat();

    // RAG: 사용자 식물 목록을 컨텍스트로 앞에 삽입
    final ragContext = await _buildRagContext(uid);
    final promptText =
        ragContext.isEmpty ? text : '$ragContext\n사용자 질문: $text';

    // 이미지 유무에 따라 Content 구성 분기
    // 텍스트만: Content.text()  /  이미지 포함: Content.multi([텍스트, 이미지])
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
    debugPrint('[GeminiService] 응답 수신: ${response.text?.substring(0, response.text!.length.clamp(0, 80))}...');
    return response.text ?? '';
  }

  /// 현재 멀티턴 세션을 폐기한다. 다음 sendMessage 호출 시 새 세션이 생성된다.
  void resetSession() {
    _chatSession = null;
  }
}
