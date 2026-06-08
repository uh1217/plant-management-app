import 'dart:typed_data';
import 'package:plantapp_p/core/services/gemini_service.dart';
import 'package:plantapp_p/Domain/entities/chat_message.dart';

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

  void resetSession() => _geminiService.resetSession();
}
