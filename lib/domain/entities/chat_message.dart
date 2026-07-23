import 'dart:typed_data';

/// AI 챗봇 메시지 엔티티
/// isUser: true → 사용자 메시지 / false → AI 응답 메시지
// const 제거: 스트리밍 중 text를 copyWith로 갱신하기 위해 불변 제약 해제
class ChatMessage {
  ChatMessage({
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

  /// 스트리밍 청크가 도착할 때마다 text만 교체하기 위한 복사 생성자
  ChatMessage copyWith({String? text}) => ChatMessage(
        id: id,
        text: text ?? this.text,
        isUser: isUser,
        createdAt: createdAt,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
      );
}
