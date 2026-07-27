import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    } on GoogleSignInException catch (e) {
      debugPrint('[Auth] sign-in failed: $e');
      return Failure(error: e, message: _mapGoogleSignInMessage(e));
    } catch (e) {
      debugPrint('[Auth] sign-in failed: $e');
      return Failure(error: e, message: _mapGenericSignInMessage(e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _remote.signOut();
      return const Success(null);
    } catch (e) {
      debugPrint('[Auth] sign-out failed: $e');
      return Failure(error: e, message: '로그아웃에 실패했습니다.');
    }
  }

  /// 계정 선택 직후 canceled는 사용자 취소와 설정 오류(SHA 등)를 구분할 수 없다.
  String _mapGoogleSignInMessage(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return '로그인이 취소되었거나, 앱 서명(SHA) 설정이 맞지 않을 수 있습니다. '
            'Play Console 앱 서명 인증서 SHA-1을 Firebase에 등록했는지 확인해 주세요.';
      case GoogleSignInExceptionCode.interrupted:
        return '로그인이 중단되었습니다. 다시 시도해 주세요.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Google 로그인 설정 오류입니다. '
            'package name / SHA / Web client ID(serverClientId)를 확인해 주세요.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google 로그인 제공자 설정 오류입니다. Firebase Authentication에서 '
            'Google 로그인이 활성화돼 있는지 확인해 주세요.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return '로그인 화면을 표시할 수 없습니다. 잠시 후 다시 시도해 주세요.';
      case GoogleSignInExceptionCode.userMismatch:
        return '다른 Google 계정으로 이미 로그인되어 있습니다. 로그아웃 후 다시 시도해 주세요.';
      case GoogleSignInExceptionCode.unknownError:
        return 'Google 로그인에 실패했습니다. (${e.description ?? e.code.name})';
    }
  }

  String _mapGenericSignInMessage(Object e) {
    final text = e.toString();
    if (text.contains('idToken')) {
      return 'Google 인증 토큰을 받지 못했습니다. '
          'Play 앱 서명 SHA와 google-services.json(Web OAuth client)을 확인해 주세요.';
    }
    if (text.contains('network') || text.contains('Network')) {
      return '네트워크 오류로 로그인하지 못했습니다. 연결을 확인해 주세요.';
    }
    return 'Google 로그인에 실패했습니다.';
  }
}
