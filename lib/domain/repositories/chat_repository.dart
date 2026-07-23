import 'dart:typed_data';
import 'package:plantapp_p/domain/entities/chat_message.dart';

/// AI 챗봇 저장소 추상 인터페이스
abstract class ChatRepository {
  /// Gemini 모델에 메시지를 전송하고 AI 응답 메시지를 반환한다.
  /// [uid] Firebase 인증 UID - RAG에서 사용자 데이터 접근 시 사용
  /// [text] 사용자 입력 텍스트
  /// [imageBytes] 첨부 이미지 바이트 (nullable)
  /// [imageMimeType] 이미지 MIME 타입 (nullable, 기본값 'image/jpeg')
  Future<ChatMessage> sendMessage({
    required String uid,
    required String text,
    Uint8List? imageBytes,
    String? imageMimeType,
  });

  /// Gemini 응답을 청크 단위 Stream으로 반환한다. (스트리밍 전송용)
  Stream<String> sendMessageStream({
    required String uid,
    required String text,
    Uint8List? imageBytes,
    String? imageMimeType,
  });

  /// 현재 멀티턴 대화 세션을 초기화한다.
  void resetSession();
}
