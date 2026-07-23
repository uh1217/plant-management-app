import 'package:plantapp_p/domain/repositories/auth_repository.dart';
import 'package:plantapp_p/core/result/result.dart';

/// 로그아웃 유스케이스
class SignOutUseCase {
  SignOutUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.signOut();
}
