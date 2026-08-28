import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:plantapp_p/presentation/viewmodels/login_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.viewModel});

  final LoginViewModel viewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  LoginViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    viewModel.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    viewModel.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    if (viewModel.status != LoginUiStatus.error ||
        viewModel.errorMessage == null) {
      return;
    }
    final message = viewModel.errorMessage!;
    // ChangeNotifier 알림 중 재진입을 피하기 위해 다음 프레임에서 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 제스처/3버튼 네비게이션 바 높이만큼 위로 올려 시스템 UI와 겹치지 않게 함
      final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          ),
        );
      // 동일 에러로 SnackBar가 반복 표시되지 않도록 idle로 되돌림
      viewModel.clearError();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final isLoading = viewModel.status == LoginUiStatus.loading;

          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/PlantApp_Icon.png',
                      width: 96,
                      height: 96,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '배춧잎',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '내 식물들을 체계적으로 관리하세요',
                    style: TextStyle(
                      fontSize: 14,
                          color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (isLoading)
                    const CircularProgressIndicator()
                  else if (Platform.isIOS)
                    // ── iOS: Apple ID 로그인 버튼 ──────────────────────────
                    // Apple 가이드라인 준수 공식 버튼 위젯 사용 (임의 디자인 불가)
                    SignInWithAppleButton(
                      onPressed: () => viewModel.signInWithApple(),
                      style: SignInWithAppleButtonStyle.black,
                      borderRadius: BorderRadius.circular(12),
                    )
                  else
                    // ── Android: Google 로그인 버튼 ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => viewModel.signIn(),
                        icon: const Icon(Icons.login),
                        label: const Text(
                          '구글 계정으로 시작하기',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
