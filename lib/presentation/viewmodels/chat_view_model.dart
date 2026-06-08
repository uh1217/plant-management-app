import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/Domain/entities/chat_message.dart';
import 'package:plantapp_p/Domain/usecases/send_message_usecase.dart';

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

  /// 메시지 전송
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

    final result = await _sendMessageUseCase(
      SendMessageParams(
        uid: uid,
        text: text,
        imageBytes: imageBytes,
        imageMimeType: mimeType,
      ),
    );

    switch (result) {
      case Success(:final data):
        messages.add(data);
        status = ChatUiStatus.idle;
      case Failure(:final message):
        status = ChatUiStatus.error;
        errorMessage = message;
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
