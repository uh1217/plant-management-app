import 'package:plantapp_p/domain/repositories/auth_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// Apple ID 로그인 유스케이스 (iOS 전용)
/// SignInWithGoogleUseCase와 동일한 구조 - repository 호출을 위임
class SignInWithAppleUseCase {
  SignInWithAppleUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<String>> call() => _repository.signInWithApple();
}
