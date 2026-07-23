import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plantapp_p/domain/entities/chat_message.dart';
import 'package:plantapp_p/domain/usecases/send_message_usecase.dart';

/// 채팅 화면 UI 상태
enum ChatUiStatus { idle, loading, error }

/// AI 챗봇 화면 상태 관리 ViewModel
///
/// - [uid] FirebaseAuth에서 받아온 사용자 고유 ID
///          ServiceLocator.createChatViewModel(uid) 호출 시 주입된다.
/// - 사용자 메시지 전송 → Gemini 응답 수신 → messages 리스트 갱신 흐름을 담당한다.
class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required SendMessageUseCase sendMessageUseCase,
    required this.uid,
  }) : _sendMessageUseCase = sendMessageUseCase;

  final SendMessageUseCase _sendMessageUseCase;

  /// Firebase 인증 UID - RAG에서 이 uid로 Firestore 사용자 데이터를 조회한다.
  final String uid;

  final List<ChatMessage> messages = [];
  ChatUiStatus status = ChatUiStatus.idle;
  String? errorMessage;

  bool get isLoading => status == ChatUiStatus.loading;

  /// 메시지 전송 (스트리밍 방식)
  /// [text] 사용자 입력 텍스트
  /// [imageFile] image_picker로 선택한 이미지 (nullable)
  Future<void> sendMessage(String text, {XFile? imageFile}) async {
    if (text.trim().isEmpty && imageFile == null) return;

    Uint8List? imageBytes;
    String? mimeType;

    if (imageFile != null) {
      imageBytes = await imageFile.readAsBytes();
      mimeType = imageFile.mimeType ?? 'image/jpeg';
    }

    // 사용자 메시지를 즉시 리스트에 추가해 UI 반응성 확보
    final userMessage = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_user',
      text: text,
      isUser: true,
      createdAt: DateTime.now(),
      imageBytes: imageBytes,
      imageMimeType: mimeType,
    );
    messages.add(userMessage);
    status = ChatUiStatus.loading;
    errorMessage = null;
    notifyListeners();

    // 빈 AI 메시지 플레이스홀더를 먼저 추가 — 청크가 오면 이 자리를 채운다
    final aiMsgId = '${DateTime.now().millisecondsSinceEpoch}_ai';
    messages.add(ChatMessage(
      id: aiMsgId,
      text: '',
      isUser: false,
      createdAt: DateTime.now(),
    ));
    notifyListeners();

    final buffer = StringBuffer();

    try {
      final stream = _sendMessageUseCase.callStream(
        SendMessageParams(
          uid: uid,
          text: text,
          imageBytes: imageBytes,
          imageMimeType: mimeType,
        ),
      );

      // 청크가 도착할 때마다 플레이스홀더 메시지의 text를 누적 갱신
      await for (final chunk in stream) {
        buffer.write(chunk);
        final idx = messages.indexWhere((m) => m.id == aiMsgId);
        if (idx != -1) {
          messages[idx] = messages[idx].copyWith(text: buffer.toString());
        }
        notifyListeners();
      }

      status = ChatUiStatus.idle;
    } catch (e) {
      // 스트리밍 중 오류 발생 시 플레이스홀더 제거 후 에러 상태로 전환
      messages.removeWhere((m) => m.id == aiMsgId);
      status = ChatUiStatus.error;
      errorMessage = 'AI 응답을 받아오는 중 오류가 발생했습니다: $e';
    }

    notifyListeners();
  }

  /// 대화 초기화 - 메시지 목록과 Gemini 세션을 모두 비운다.
  void resetChat() {
    messages.clear();
    _sendMessageUseCase.resetSession();
    status = ChatUiStatus.idle;
    errorMessage = null;
    notifyListeners();
  }
}
