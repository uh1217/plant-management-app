import 'package:plantapp_p/domain/repositories/auth_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// Google 로그인 유스케이스
class SignInWithGoogleUseCase {
  SignInWithGoogleUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<String>> call() => _repository.signInWithGoogle();
}
