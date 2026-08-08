import 'package:plantapp_p/core/result/result.dart';

/// 인증 데이터 접근 설계도
abstract class AuthRepository {
  Future<Result<String>> signInWithGoogle();
  Future<Result<String>> signInWithApple(); // iOS 전용 Apple ID 로그인
  Future<Result<void>> signOut();
  Stream<String?> get authStateChanges;
}
