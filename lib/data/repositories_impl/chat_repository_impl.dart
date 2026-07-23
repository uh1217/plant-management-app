import 'dart:typed_data';
import 'package:plantapp_p/data/datasources/gemini_datasource.dart';
import 'package:plantapp_p/domain/entities/chat_message.dart';
import 'package:plantapp_p/domain/repositories/chat_repository.dart';

/// ChatRepository 구현체 - GeminiDataSource에 위임한다.
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl(this._dataSource);
  final GeminiDataSource _dataSource;

  @override
  Future<ChatMessage> sendMessage({
    required String uid,
    required String text,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) =>
      _dataSource.sendMessage(
        uid: uid,
        text: text,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
      );

  /// DataSource의 스트리밍 메서드에 위임한다.
  @override
  Stream<String> sendMessageStream({
    required String uid,
    required String text,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) =>
      _dataSource.sendMessageStream(
        uid: uid,
        text: text,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
      );

  @override
  void resetSession() => _dataSource.resetSession();
}
