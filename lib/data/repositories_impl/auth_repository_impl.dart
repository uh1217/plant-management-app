import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/domain/repositories/auth_repository.dart';
import 'package:plantapp_p/data/datasources/auth_remote_datasource.dart';

/// AuthRepository Firebase 구현체
// 추상 클래스 구현 - UI나 usecase는 구현체의 본체는 모른체 AuthRepository라는 껍데기(인터페이스)만 보고 소통
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);
  //실제 구글/Firebase 서버와 통신
  final AuthRemoteDataSource _remote;

  //실시간 상태 파이프라인 연결 -> 현재는 main에서 구현(FirebaseAuth.instance를 직접 구독)
  @override
  Stream<String?> get authStateChanges => _remote.authStateChanges;

  //중간에 인터넷으 끊기는 에러 처리 (Result 활용)
  // AuthRemoteDataSource는 실패 시 예외(Exception)를 던짐 -> try-catch로 잡아 처리
  @override
  Future<Result<String>> signInWithGoogle() async {
    try {
      final uid = await _remote.signInWithGoogle();
      return Success(uid);
    } catch (e) {
      return Failure(error: e, message: 'Google 로그인에 실패했습니다.');
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _remote.signOut();
      return const Success(null);
    } catch (e) {
      return Failure(error: e, message: '로그아웃에 실패했습니다.');
    }
  }
}
