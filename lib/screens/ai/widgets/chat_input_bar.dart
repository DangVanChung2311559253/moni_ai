import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool canSend;
  final bool loading;
  final bool listening;
  final VoidCallback onSend;
  final VoidCallback onMicrophone;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.canSend,
    required this.loading,
    required this.listening,
    required this.onSend,
    required this.onMicrophone,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.navyMid,
          border: const Border(top: BorderSide(color: AppColors.navyBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(45),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (listening)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    const _ListeningDot(),
                    const SizedBox(width: 8),
                    Text(
                      'Đang nghe tiếng Việt... Bấm micro để dừng',
                      style: GoogleFonts.outfit(
                        color: AppColors.roseAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: AppColors.navyCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: listening
                            ? AppColors.roseAccent.withAlpha(150)
                            : AppColors.navyBorder,
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      enabled: !loading,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: listening
                            ? 'Hãy nói nội dung giao dịch...'
                            : 'Nhập giao dịch hoặc câu hỏi tài chính...',
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.fromLTRB(
                          15,
                          12,
                          12,
                          12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: canSend && !loading && !listening
                        ? AppColors.tealGradient
                        : null,
                    color: listening
                        ? AppColors.roseAccent
                        : canSend && !loading
                        ? null
                        : AppColors.tealPrimary.withAlpha(45),
                    shape: BoxShape.circle,
                    border: canSend || listening
                        ? null
                        : Border.all(
                            color: AppColors.tealPrimary.withAlpha(90),
                          ),
                    boxShadow: canSend && !loading || listening
                        ? [
                            BoxShadow(
                              color:
                                  (listening
                                          ? AppColors.roseAccent
                                          : AppColors.tealPrimary)
                                      .withAlpha(65),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    tooltip: listening
                        ? 'Dừng nghe'
                        : canSend
                        ? 'Gửi'
                        : 'Nhập bằng giọng nói',
                    onPressed: loading
                        ? null
                        : listening
                        ? onMicrophone
                        : canSend
                        ? onSend
                        : onMicrophone,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        listening
                            ? AppIcons.stopRounded
                            : canSend
                            ? AppIcons.arrowUpwardRounded
                            : AppIcons.micRounded,
                        key: ValueKey('$canSend-$listening'),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningDot extends StatelessWidget {
  const _ListeningDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.roseAccent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.roseAccent.withAlpha(100),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}
