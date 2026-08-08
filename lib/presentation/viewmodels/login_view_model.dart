import 'package:flutter/foundation.dart';

import '../../core/result/result.dart';
import '../../domain/usecases/sign_in_with_google_usecase.dart';
import '../../domain/usecases/sign_in_with_apple_usecase.dart';

enum LoginUiStatus { idle, loading, success, error }

/// 로그인 화면 상태 관리 (단일 목적 유스케이스 주입)
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required SignInWithGoogleUseCase signInWithGoogle,
    required SignInWithAppleUseCase signInWithApple,
  })  : _signInWithGoogle = signInWithGoogle,
        _signInWithApple = signInWithApple;

  final SignInWithGoogleUseCase _signInWithGoogle;
  final SignInWithAppleUseCase _signInWithApple;

  LoginUiStatus status = LoginUiStatus.idle;
  String? errorMessage;

  /// SnackBar 표시 후 동일 에러 재표시를 막기 위해 상태를 초기화한다.
  void clearError() {
    if (status != LoginUiStatus.error) return;
    status = LoginUiStatus.idle;
    errorMessage = null;
    notifyListeners();
  }

  /// Google 로그인 (Android 전용)
  Future<bool> signIn() async {
    return _handleSignIn(_signInWithGoogle());
  }

  /// Apple ID 로그인 (iOS 전용)
  Future<bool> signInWithApple() async {
    return _handleSignIn(_signInWithApple());
  }

  /// 로그인 공통 처리 - 로딩 상태 관리 및 결과 처리
  Future<bool> _handleSignIn(Future<Result<String>> signInFuture) async {
    status = LoginUiStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await signInFuture;
    switch (result) {
      case Success():
        status = LoginUiStatus.success;
        notifyListeners();
        return true;
      case Failure(:final message):
        status = LoginUiStatus.error;
        errorMessage = message;
        notifyListeners();
        return false;
    }
  }
}
