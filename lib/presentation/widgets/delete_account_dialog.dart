import 'package:flutter/material.dart';

import 'package:plantapp_p/presentation/viewmodels/home_view_model.dart';

/// 회원 탈퇴 확인 → 진행 → 결과 안내까지 담당하는 다이얼로그 헬퍼
///
/// 확인 후 본인 확인(재인증) 창이 한 번 더 뜨고,
/// 성공하면 authStateChanges 스트림이 로그인 화면으로 전환한다.
Future<void> showDeleteAccountDialog(
  BuildContext context,
  HomeViewModel viewModel,
) async {
  final colorScheme = Theme.of(context).colorScheme;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 8),
          const Text('회원 탈퇴', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('탈퇴 시 아래 데이터가 영구 삭제되며 복구할 수 없습니다.'),
          const SizedBox(height: 12),
          const _DeleteItem(
            icon: Icons.local_florist_outlined,
            text: '등록한 모든 식물과 케어 기록',
          ),
          const _DeleteItem(
            icon: Icons.photo_library_outlined,
            text: '성장 앨범의 모든 사진',
          ),
          const _DeleteItem(icon: Icons.person_outline, text: '계정 정보'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '다음 계정 선택 창에서 탈퇴할 계정을 선택해 주세요.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('탈퇴하기'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  // 계정 삭제가 끝나면 auth 스트림이 홈을 내려서 이 context는 unmount 된다.
  // 로딩 다이얼로그는 root Navigator에 남아 있으므로, await 전에 Navigator를 잡아 둔다.
  final navigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  var success = false;
  try {
    success = await viewModel.deleteAccount();
  } finally {
    if (navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
  }

  // 성공 시에는 authStateChanges가 로그인 화면으로 전환하므로 별도 안내 불필요
  if (!success && context.mounted) {
    final message = viewModel.errorMessage ?? '회원 탈퇴에 실패했습니다.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _DeleteItem extends StatelessWidget {
  const _DeleteItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: outline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: outline)),
          ),
        ],
      ),
    );
  }
}
