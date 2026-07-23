import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:plantapp_p/core/di/service_locator.dart';
import 'package:plantapp_p/domain/entities/chat_message.dart';
import 'package:plantapp_p/presentation/app_colors.dart';
import 'package:plantapp_p/presentation/viewmodels/chat_view_model.dart';

// ── 공개 진입점 ──────────────────────────────────────────────────────────────

/// 사이드바 메뉴나 다른 화면에서 호출해 챗봇 다이얼로그를 표시한다.
void showPlantAgentDialog(BuildContext context) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false, // 실수 터치로 대화 기록이 사라지지 않도록 방지
    builder: (_) => _PlantAgentDialog(uid: uid),
  );
}

// ── 다이얼로그 위젯 ───────────────────────────────────────────────────────────

class _PlantAgentDialog extends StatefulWidget {
  const _PlantAgentDialog({required this.uid});
  final String uid;

  @override
  State<_PlantAgentDialog> createState() => _PlantAgentDialogState();
}

class _PlantAgentDialogState extends State<_PlantAgentDialog> {
  late final ChatViewModel _vm;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  XFile? _pendingImage;
  Uint8List? _pendingImageBytes;

  @override
  void initState() {
    super.initState();
    // 챗봇 열 때마다 캐시 무효화 — 물 주기·비료 등 세션 외 변경도 최신 데이터로 반영
    ServiceLocator.instance.geminiService.invalidateRagCache();
    _vm = ServiceLocator.instance.createChatViewModel(widget.uid);
    _vm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});
    // 새 메시지가 추가된 후 맨 아래로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pendingImage = file;
      _pendingImageBytes = bytes;
    });
  }

  void _removePendingImage() {
    setState(() {
      _pendingImage = null;
      _pendingImageBytes = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _pendingImage == null) return;
    if (_vm.isLoading) return;

    _textCtrl.clear();
    final imageToSend = _pendingImage;
    setState(() {
      _pendingImage = null;
      _pendingImageBytes = null;
    });

    await _vm.sendMessage(text, imageFile: imageToSend);
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenSize.width * 0.04,
        vertical: screenSize.height * 0.05,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(colorScheme),
          Expanded(child: _buildMessageList(colorScheme)),
          if (_pendingImageBytes != null) _buildImagePreview(colorScheme),
          _buildInputBar(colorScheme),
        ],
      ),
    );
  }

  // ── 헤더 ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '식물 Agent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Gemini 3.5 Flash • 스마트 원예 진단 에이전트',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // 대화 초기화 버튼
          IconButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('대화 초기화'),
                  content: const Text('현재 대화 내용이 모두 삭제됩니다.\n새 대화를 시작할까요?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _vm.resetChat();
                      },
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen),
                      child: const Text('초기화'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            tooltip: '대화 초기화',
          ),
          // 닫기 버튼
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  // ── 메시지 목록 ───────────────────────────────────────────────────────────

  Widget _buildMessageList(ColorScheme colorScheme) {
    // 웰컴(1) + 메시지들 + 로딩(조건부) + 에러(조건부)
    final hasError =
        _vm.status == ChatUiStatus.error && _vm.errorMessage != null;
    final extraItems = (_vm.isLoading ? 1 : 0) + (hasError ? 1 : 0);

    return Container(
      color: colorScheme.surfaceContainerLowest,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        itemCount: 1 + _vm.messages.length + extraItems,
        itemBuilder: (_, i) {
          // 웰컴 메시지
          if (i == 0) return _buildWelcomeBubble(colorScheme);

          final msgIndex = i - 1;

          // 실제 메시지
          if (msgIndex < _vm.messages.length) {
            return _buildMessageBubble(_vm.messages[msgIndex], colorScheme);
          }

          // 로딩 인디케이터 (실제 메시지 다음)
          if (_vm.isLoading) return _buildLoadingBubble(colorScheme);

          // 에러 버블 (로딩이 끝났을 때만)
          if (hasError) return _buildErrorBubble(colorScheme);

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildErrorBubble(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.red.withOpacity(0.12),
            child: const Icon(Icons.error_outline, size: 17, color: Colors.red),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '응답 오류',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _vm.errorMessage ?? '알 수 없는 오류가 발생했습니다.',
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      // 마지막 사용자 메시지를 다시 전송
                      final lastUserMsg = _vm.messages
                          .lastWhere((m) => m.isUser, orElse: () => _vm.messages.last);
                      if (lastUserMsg.isUser) {
                        _vm.sendMessage(
                          lastUserMsg.text,
                        );
                      }
                    },
                    child: const Text(
                      '다시 시도',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeBubble(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAiAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const Text(
                '안녕하세요! 🌿\n저는 스마트 원예 진단 에이전트입니다.\n\n텍스트로 질문하거나 식물 사진을 첨부하시면 진단 및 관리 팁을 알려드릴게요!\n\n⚠️ AI는 여러분의 식물의 모든 정보를 정확히 파악할 수 없습니다. 해당 기능은 단순 도움을 드릴 뿐 최종 판단은 직접 하시길 권합니다.',
                style: TextStyle(fontSize: 13.5, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, ColorScheme colorScheme) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[_buildAiAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // 첨부 이미지
                if (msg.imageBytes != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    constraints: const BoxConstraints(maxWidth: 220),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(
                      msg.imageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                // 텍스트 말풍선
                if (msg.text.isNotEmpty)
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.primaryGreen
                          : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isUser ? 16 : 4),
                        topRight: Radius.circular(isUser ? 4 : 16),
                        bottomLeft: const Radius.circular(16),
                        bottomRight: const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: isUser ? Colors.white : colorScheme.onSurface,
                      ),
                    ),
                  ),
                // 시간 표시
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const _TypingIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primaryGreen.withOpacity(0.15),
      child: const Icon(Icons.eco, size: 17, color: AppColors.primaryGreen),
    );
  }

  // ── 이미지 미리보기 ───────────────────────────────────────────────────────

  Widget _buildImagePreview(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: colorScheme.surface,
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _pendingImageBytes!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: _removePendingImage,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Text(
            '이미지가 첨부됩니다',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── 입력 바 ──────────────────────────────────────────────────────────────

  Widget _buildInputBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 이미지 첨부 버튼
            IconButton(
              onPressed: _vm.isLoading ? null : _pickImage,
              icon: Icon(
                Icons.add_photo_alternate_outlined,
                color: _pendingImage != null
                    ? AppColors.primaryGreen
                    : colorScheme.onSurface.withOpacity(0.5),
              ),
              tooltip: '이미지 첨부',
            ),
            // 텍스트 입력 필드
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: _textCtrl,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '식물에 대해 질문해 보세요...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  enabled: !_vm.isLoading,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // 전송 버튼
            _SendButton(
              isLoading: _vm.isLoading,
              onTap: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  // ── 유틸 ─────────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── 전송 버튼 ─────────────────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isLoading
              ? AppColors.primaryGreen.withOpacity(0.4)
              : AppColors.primaryGreen,
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── 타이핑 인디케이터 (점 세 개 애니메이션) ──────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            // 각 점마다 위상 차이를 두어 순차적으로 올라오게 함
            final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final offset = phase < 0.5
                ? phase * 2
                : (1.0 - phase) * 2; // 0→1→0 사이클
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              transform: Matrix4.translationValues(0, -offset * 5, 0),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
