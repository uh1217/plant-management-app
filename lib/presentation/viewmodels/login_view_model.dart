import 'package:flutter/foundation.dart';

import '../../core/result/result.dart';
import '../../domain/usecases/sign_in_with_google_usecase.dart';

enum LoginUiStatus { idle, loading, success, error }

/// 로그인 화면 상태 관리 (단일 목적 유스케이스 주입)
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required SignInWithGoogleUseCase signInWithGoogle})
      : _signInWithGoogle = signInWithGoogle;

  final SignInWithGoogleUseCase _signInWithGoogle;

  LoginUiStatus status = LoginUiStatus.idle;
  String? errorMessage;

  Future<bool> signIn() async {
    status = LoginUiStatus.loading;
    errorMessage = null;
    notifyListeners();

    final result = await _signInWithGoogle();
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
