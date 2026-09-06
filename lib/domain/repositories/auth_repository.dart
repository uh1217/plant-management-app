import 'package:plantapp_p/core/result/result.dart';

/// 인증 데이터 접근 설계도
abstract class AuthRepository {
  Future<Result<String>> signInWithGoogle();
  Future<Result<String>> signInWithApple(); // iOS 전용 Apple ID 로그인
  Future<Result<void>> signOut();

  /// 회원 탈퇴: 재인증 → 사용자 데이터 삭제 → (Apple) 토큰 취소 → 계정 삭제
  Future<Result<void>> deleteAccount();

  Stream<String?> get authStateChanges;
}