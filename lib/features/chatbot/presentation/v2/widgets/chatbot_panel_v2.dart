import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/features/chatbot/presentation/chatbot_provider.dart';

/// Chat panel of the AI assistant (v2). Same [ChatbotProvider] calls (send / reset / closePanel),
/// suggested questions, send rules and auto-scroll as [ChatbotPanel]
/// (v1, ../../widgets/chatbot_panel.dart) — only the layout changes.
class ChatbotPanelV2 extends StatefulWidget {
  const ChatbotPanelV2({super.key});

  @override
  State<ChatbotPanelV2> createState() => _ChatbotPanelV2State();
}

class _ChatbotPanelV2State extends State<ChatbotPanelV2> {
  // ── State + logic (verbatim from v1) ──────────────────────────────────────
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _suggested = [
    'Hôm nay có bao nhiêu chuyến?',
    'Xe nào cần bảo trì gấp?',
    'Sản lượng tháng này?',
    'Xe nào chạy nhiều nhất?',
    'Tỷ lệ hoàn thành hôm nay?',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200, // Extra space
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final provider = context.read<ChatbotProvider>();
    if (provider.loading) return;

    provider.send(text);
    _inputController.clear();
    FocusScope.of(context).unfocus();

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatbotProvider>();
    final t = FxTokens.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.isOpen && _scrollController.hasClients &&
          _scrollController.position.pixels < _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Material(
      type: MaterialType.transparency,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: t.dark ? 0.45 : 0.16),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        // When the panel opens it grows out of the bubble's rect (the AnimatedPositioned in the bubble
        // widget, as in v1). The content is laid out at a usable minimum size, anchored bottom-right
        // like the panel itself, and clipped by the rounded card meanwhile — no overflow while growing.
        child: LayoutBuilder(
          builder: (context, c) {
            final w = math.max(c.maxWidth, 280.0);
            final h = math.max(c.maxHeight, 200.0);
            return OverflowBox(
              alignment: Alignment.bottomRight,
              minWidth: w,
              maxWidth: w,
              minHeight: h,
              maxHeight: h,
              child: Column(
                children: [
                  _header(t, provider),
                  Expanded(
                    child: ColoredBox(
                      color: t.bg,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 10.h),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, index) => _message(t, provider.messages[index]),
                      ),
                    ),
                  ),
                  if (!provider.loading) _suggestions(t),
                  _inputBar(t, provider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(FxTokens t, ChatbotProvider provider) {
    final c1 = t.dark ? Color.lerp(FxTokens.blue, t.bg, 0.30)! : FxTokens.blue;
    final c2 = t.dark ? Color.lerp(FxTokens.indigo, t.bg, 0.30)! : FxTokens.indigo;
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 10.h, 4.w, 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 19.sp),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: provider.loading ? FxTokens.amber : FxTokens.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: c2, width: 2),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý AI',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2),
                ),
                SizedBox(height: 1.h),
                Text(
                  provider.loading ? 'Nguyên Anh II · Đang trả lời…' : 'Nguyên Anh II',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cuộc trò chuyện mới',
            icon: const Icon(Icons.refresh_rounded),
            iconSize: 20.sp,
            color: Colors.white,
            onPressed: () {
              provider.reset();
            },
          ),
          IconButton(
            tooltip: 'Đóng',
            icon: const Icon(Icons.close_rounded),
            iconSize: 20.sp,
            color: Colors.white,
            onPressed: () {
              provider.closePanel();
            },
          ),
        ],
      ),
    );
  }

  Widget _botAvatar() {
    return Container(
      width: 26.w,
      height: 26.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [FxTokens.blue, FxTokens.indigo]),
      ),
      child: Icon(Icons.smart_toy_rounded, size: 14.sp, color: Colors.white),
    );
  }

  Widget _message(FxTokens t, UIMessage msg) {
    final isUser = msg.role == 'user';
    final isError = !isUser && msg.text.startsWith('⚠️');

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isUser) SizedBox(width: 44.w),
          if (!isUser) ...[
            _botAvatar(),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Status / Reasoning steps
                if (!isUser && msg.toolSteps.isNotEmpty && msg.text.isEmpty) _steps(t, msg),

                if (!isUser && msg.loading && msg.text.isEmpty)
                  const _TypingBubble()
                else if (msg.text.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 9.h),
                    decoration: BoxDecoration(
                      gradient: isUser
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [FxTokens.blue, FxTokens.indigo],
                            )
                          : null,
                      color: isUser ? null : (isError ? Color.alphaBlend(t.soft(FxTokens.red), t.card) : t.card),
                      border: isUser
                          ? null
                          : Border.all(color: isError ? FxTokens.red.withValues(alpha: 0.3) : t.border),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(18.r),
                        topRight: Radius.circular(18.r),
                        bottomLeft: Radius.circular(isUser ? 18.r : 5.r),
                        bottomRight: Radius.circular(isUser ? 5.r : 18.r),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        height: 1.45,
                        color: isUser ? Colors.white : (isError ? t.ink(FxTokens.red) : t.text),
                      ),
                    ),
                  ),
                if (msg.time.isNotEmpty && msg.text.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 3.h, left: 4.w, right: 4.w),
                    child: Text(msg.time, style: t.tiny.copyWith(color: t.textFaint, fontFeatures: FxTokens.tabular)),
                  ),
              ],
            ),
          ),
          if (!isUser) SizedBox(width: 28.w),
        ],
      ),
    );
  }

  Widget _steps(FxTokens t, UIMessage msg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      margin: EdgeInsets.only(bottom: 6.h),
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < msg.toolSteps.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.loading && i == msg.toolSteps.length - 1)
                    SizedBox(
                      width: 11.sp,
                      height: 11.sp,
                      child: const CircularProgressIndicator(strokeWidth: 1.6, color: FxTokens.blue),
                    )
                  else
                    Icon(Icons.check_circle_rounded, size: 12.sp, color: FxTokens.emerald),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(msg.toolSteps[i], style: t.tiny.copyWith(color: t.textMuted)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _suggestions(FxTokens t) {
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        itemCount: _suggested.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          return Material(
            color: t.soft(FxTokens.blue),
            shape: StadiumBorder(side: BorderSide(color: FxTokens.blue.withValues(alpha: 0.22))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _send(_suggested[index]),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 11.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 12.sp, color: t.ink(FxTokens.blue)),
                    SizedBox(width: 5.w),
                    Text(
                      _suggested[index],
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: t.ink(FxTokens.blue)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _inputBar(FxTokens t, ChatbotProvider provider) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: t.cardAlt,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: t.border),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: t.small.copyWith(fontSize: 13.sp),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 14.sp, color: t.text),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _inputController,
            builder: (context, value, _) {
              final ready = !provider.loading && value.text.trim().isNotEmpty;
              return Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _send(_inputController.text),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: ready
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [FxTokens.blue, FxTokens.indigo],
                            )
                          : null,
                      color: ready ? null : t.track,
                    ),
                    child: provider.loading
                        ? Padding(
                            padding: EdgeInsets.all(11.w),
                            child: CircularProgressIndicator(strokeWidth: 2, color: t.textMuted),
                          )
                        : Icon(Icons.arrow_upward_rounded, color: ready ? Colors.white : t.textMuted, size: 20.sp),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "Đang soạn" bubble with three bouncing dots.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18.r),
          topRight: Radius.circular(18.r),
          bottomLeft: Radius.circular(5.r),
          bottomRight: Radius.circular(18.r),
        ),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: 4.w),
                Builder(builder: (_) {
                  // Each dot peaks a third of a cycle after the previous one.
                  final phase = (_c.value - i * 0.18) % 1.0;
                  final lift = phase < 0.5 ? (phase < 0.25 ? phase * 4 : (0.5 - phase) * 4) : 0.0;
                  return Transform.translate(
                    offset: Offset(0, -3 * lift),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(t.textFaint, FxTokens.blue, lift),
                      ),
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}
