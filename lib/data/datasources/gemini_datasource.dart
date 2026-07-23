import 'dart:typed_data';
import 'package:plantapp_p/core/services/gemini_service.dart';
import 'package:plantapp_p/domain/entities/chat_message.dart';

/// GeminiService를 호출하고 응답을 ChatMessage 엔티티로 변환하는 데이터 소스
class GeminiDataSource {
  GeminiDataSource(this._geminiService);
  final GeminiService _geminiService;

  Future<ChatMessage> sendMessage({
    required String uid,
    required String text,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    final responseText = await _geminiService.sendMessage(
      uid: uid,
      text: text,
      imageBytes: imageBytes,
      mimeType: imageMimeType ?? 'image/jpeg',
    );

    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: responseText,
      isUser: false,
      createdAt: DateTime.now(),
    );
  }

  /// GeminiService의 스트리밍 메서드를 그대로 노출한다.
  /// 청크 텍스트를 그대로 전달하며 엔티티 변환은 Repository 레이어에서 처리한다.
  Stream<String> sendMessageStream({
    required String uid,
    required String text,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) =>
      _geminiService.sendMessageStream(
        uid: uid,
        text: text,
        imageBytes: imageBytes,
        mimeType: imageMimeType ?? 'image/jpeg',
      );

  void resetSession() => _geminiService.resetSession();
}
