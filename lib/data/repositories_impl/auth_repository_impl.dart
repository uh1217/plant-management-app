import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:plantapp_p/core/result/result.dart';
import 'package:plantapp_p/data/datasources/auth_remote_datasource.dart';
import 'package:plantapp_p/data/datasources/user_remote_datasource.dart';
import 'package:plantapp_p/domain/repositories/auth_repository.dart';

/// AuthRepository Firebase 구현체
// 추상 클래스 구현 - UI나 usecase는 구현체의 본체는 모른체 AuthRepository라는 껍데기(인터페이스)만 보고 소통
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._userRemote);
  //실제 구글/Firebase 서버와 통신
  final AuthRemoteDataSource _remote;
  //탈퇴 시 사용자 데이터(Firestore/Storage) 삭제 담당
  final UserRemoteDataSource _userRemote;

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
  Future<Result<String>> signInWithApple() async {
    try {
      final uid = await _remote.signInWithApple();
      return Success(uid);
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[Auth] Apple sign-in failed: $e');
      return Failure(error: e, message: _mapAppleAuthMessage(e));
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] Apple sign-in failed: $e');
      return Failure(error: e, message: _mapFirebaseAuthMessage(e, 'Apple 로그인'));
    } catch (e) {
      debugPrint('[Auth] Apple sign-in failed: $e');
      return Failure(error: e, message: 'Apple 로그인에 실패했습니다.');
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

  /// 회원 탈퇴 순서가 중요하다:
  /// ① 재인증 (Firebase가 최근 로그인 요구 + Apple revoke용 코드 확보)
  /// ② Firestore/Storage 데이터 삭제 (계정 삭제 후에는 보안 규칙에 막힘)
  /// ③ Apple 토큰 취소 + Auth 계정 삭제
  @override
  Future<Result<void>> deleteAccount() async {
    try {
      final appleAuthorizationCode = await _remote.reauthenticateForDelete();
      await _userRemote.deleteAllUserData();
      await _remote.deleteAuthUser(
        appleAuthorizationCode: appleAuthorizationCode,
      );
      return const Success(null);
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('[Auth] delete-account failed: $e');
      if (e.code == AuthorizationErrorCode.canceled) {
        return Failure(error: e, message: '회원 탈퇴가 취소되었습니다.');
      }
      return Failure(error: e, message: '본인 확인에 실패했습니다. 다시 시도해 주세요.');
    } on GoogleSignInException catch (e) {
      debugPrint('[Auth] delete-account failed: $e');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return Failure(error: e, message: '회원 탈퇴가 취소되었습니다.');
      }
      return Failure(error: e, message: '본인 확인에 실패했습니다. 다시 시도해 주세요.');
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] delete-account failed: $e');
      return Failure(error: e, message: _mapFirebaseAuthMessage(e, '회원 탈퇴'));
    } catch (e) {
      debugPrint('[Auth] delete-account failed: $e');
      return Failure(
        error: e,
        message: '회원 탈퇴 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
      );
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

  /// sign_in_with_apple 전용 예외를 enum 코드 기반으로 매핑
  /// (버전에 따라 코드가 추가될 수 있어 wildcard로 방어)
  String _mapAppleAuthMessage(SignInWithAppleAuthorizationException e) {
    return switch (e.code) {
      AuthorizationErrorCode.canceled => '로그인이 취소되었습니다.',
      AuthorizationErrorCode.notInteractive =>
        '로그인 화면을 표시할 수 없습니다. 잠시 후 다시 시도해 주세요.',
      _ => 'Apple 로그인에 실패했습니다. 잠시 후 다시 시도해 주세요. (${e.code.name})',
    };
  }

  /// FirebaseAuthException 공통 매핑 ([action]: 'Apple 로그인', '회원 탈퇴' 등)
  String _mapFirebaseAuthMessage(FirebaseAuthException e, String action) {
    return switch (e.code) {
      'network-request-failed' => '네트워크 오류로 $action에 실패했습니다. 연결을 확인해 주세요.',
      'requires-recent-login' =>
        '보안을 위해 다시 로그인이 필요합니다. 로그아웃 후 재로그인하여 시도해 주세요.',
      'user-mismatch' => '현재 로그인된 계정과 다른 계정입니다. 같은 계정으로 본인 확인을 해주세요.',
      'user-disabled' => '사용이 중지된 계정입니다.',
      'too-many-requests' => '요청이 많아 잠시 차단되었습니다. 잠시 후 다시 시도해 주세요.',
      _ => '$action에 실패했습니다. (${e.code})',
    };
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
