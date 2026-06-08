import 'dart:typed_data';

/// AI 챗봇 메시지 엔티티
/// isUser: true → 사용자 메시지 / false → AI 응답 메시지
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.createdAt,
    this.imageBytes,
    this.imageMimeType,
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime createdAt;

  /// 사용자가 첨부한 이미지 (UI 미리보기 + Gemini 전달용, nullable)
  final Uint8List? imageBytes;
  final String? imageMimeType;
}
