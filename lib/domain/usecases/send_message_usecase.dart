import 'dart:typed_data';
import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/entities/chat_message.dart';
import 'package:plantapp_p/domain/repositories/chat_repository.dart';

/// 메시지 전송 유스케이스 파라미터
class SendMessageParams {
  const SendMessageParams({
    required this.uid,
    required this.text,
    this.imageBytes,
    this.imageMimeType,
  });

  /// Firebase 인증 UID (RAG 컨텍스트 조회 시 사용)
  final String uid;
  final String text;
  final Uint8List? imageBytes;
  final String? imageMimeType;
}

/// Gemini 모델에 메시지를 전송하고 AI 응답을 Result로 반환하는 유스케이스
class SendMessageUseCase {
  SendMessageUseCase(this._repository);
  final ChatRepository _repository;

  Future<Result<ChatMessage>> call(SendMessageParams params) async {
    try {
      final message = await _repository.sendMessage(
        uid: params.uid,
        text: params.text,
        imageBytes: params.imageBytes,
        imageMimeType: params.imageMimeType,
      );
      return Success(message);
    } catch (e) {
      return Failure(
        error: e,
        message: 'AI 응답을 받아오는 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// 스트리밍 방식으로 메시지를 전송한다.
  /// ViewModel에서 청크마다 UI를 갱신할 때 사용한다.
  Stream<String> callStream(SendMessageParams params) =>
      _repository.sendMessageStream(
        uid: params.uid,
        text: params.text,
        imageBytes: params.imageBytes,
        imageMimeType: params.imageMimeType,
      );

  /// 멀티턴 대화 세션 초기화 (새 대화 시작 시 호출)
  void resetSession() => _repository.resetSession();
}
