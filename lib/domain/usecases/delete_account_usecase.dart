import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/repositories/auth_repository.dart';

/// 회원 탈퇴 유스케이스
/// App Store 심사 가이드라인 5.1.1(v): 계정 생성이 가능한 앱은
/// 앱 내에서 계정 삭제 기능을 반드시 제공해야 한다.
class DeleteAccountUseCase {
  DeleteAccountUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.deleteAccount();
}
