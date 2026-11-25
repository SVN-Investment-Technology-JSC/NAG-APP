import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/features/chatbot/presentation/chatbot_provider.dart';
import 'package:nguyenanh/features/chatbot/presentation/v2/widgets/chatbot_panel_v2.dart';

/// Floating AI-assistant bubble (v2). Same visibility rule, drag / clamp / edge-snap, drag-to-dismiss
/// zone, tap-to-toggle and panel placement as [ChatbotBubble] (v1, ../../widgets/chatbot_bubble.dart);
/// opens [ChatbotPanelV2].
class ChatbotBubbleV2 extends StatefulWidget {
  final Widget child; // The main app content over which the bubble floats

  const ChatbotBubbleV2({super.key, required this.child});

  @override
  State<ChatbotBubbleV2> createState() => _ChatbotBubbleV2State();
}

class _ChatbotBubbleV2State extends State<ChatbotBubbleV2> with SingleTickerProviderStateMixin {
  // ── State + logic (verbatim from v1) ──────────────────────────────────────
  late Offset _position;
  bool _isDragging = false;
  bool _isInDismissZone = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Default position: bottom right
    _position = Offset(300.w, 600.h);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Adjust position if it's off-screen after init
    final size = MediaQuery.of(context).size;
    if (_position.dx > size.width) _position = Offset(size.width - 70.w, _position.dy);
    if (_position.dy > size.height) _position = Offset(_position.dx, size.height - 100.h);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatbotProvider>();
    final size = MediaQuery.of(context).size;

    if (!provider.isBubbleVisible) {
      return widget.child;
    }

    final viewInsets = MediaQuery.of(context).viewInsets;
    final t = FxTokens.of(context);

    return Stack(
      children: [
        // Main App Content
        widget.child,

        // The Panel
        if (provider.isOpen)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: viewInsets.bottom > 0
                ? (size.height * 0.12) // Expand upwards when keyboard is open
                : (_position.dy + 60.w + 10.h).clamp(0.0, size.height * 0.4), // Normal top
            left: 12.w,
            right: 12.w,
            bottom: 12.h + viewInsets.bottom, // Avoid keyboard
            child: const ChatbotPanelV2(),
          ),

        // Dismiss Area (same position / size as v1; the hit-test rect is computed in onPanUpdate)
        if (_isDragging && !provider.isOpen) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 60.h + 78.w,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _isInDismissZone ? 1 : 0.85,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(FxTokens.rPill),
                    ),
                    child: Text(
                      _isInDismissZone ? 'Thả để ẩn trợ lý' : 'Kéo vào đây để ẩn',
                      style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60.h,
            left: (size.width - 60.w) / 2,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isInDismissZone ? 70.w : 60.w,
                height: _isInDismissZone ? 70.w : 60.w,
                decoration: BoxDecoration(
                  color: _isInDismissZone ? FxTokens.red : Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: _isInDismissZone ? 0.9 : 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (_isInDismissZone ? FxTokens.red : Colors.black).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: _isInDismissZone ? 32.sp : 24.sp,
                ),
              ),
            ),
          ),
        ],

        // The Draggable Bubble
        AnimatedPositioned(
          duration: Duration(milliseconds: _isDragging ? 0 : 300),
          curve: Curves.easeOutCubic,
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() => _isDragging = true);
            },
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
                // Clamp to screen bounds
                _position = Offset(
                  _position.dx.clamp(0.0, size.width - 60.w),
                  _position.dy.clamp(0.0, size.height - 100.h),
                );

                // Check dismiss zone
                final dismissZoneRect = Rect.fromLTWH(
                  (size.width - 80.w) / 2,
                  size.height - 120.h,
                  80.w,
                  80.h
                );

                final bubbleRect = Rect.fromLTWH(
                  _position.dx,
                  _position.dy,
                  56.w,
                  56.w
                );

                _isInDismissZone = dismissZoneRect.overlaps(bubbleRect);
              });
            },
            onPanEnd: (details) {
              if (_isInDismissZone) {
                provider.toggleBubbleVisibility();
                _isInDismissZone = false;
              } else {
                // Snap to nearest edge
                final middle = size.width / 2;
                final newX = _position.dx + 28.w < middle ? 6.w : size.width - 62.w;
                _position = Offset(newX, _position.dy);
              }
              setState(() => _isDragging = false);
            },
            onTap: () {
              if (!provider.isOpen) {
                // Snap to top right when opening
                setState(() {
                  _position = Offset(size.width - 70.w, MediaQuery.of(context).padding.top + 10.h);
                });
              }
              provider.togglePanel();
            },
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: _bubble(t, provider.isOpen),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(FxTokens t, bool isOpen) {
    return SizedBox(
      width: 56.w,
      height: 56.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [FxTokens.blue, FxTokens.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: t.dark ? 0.18 : 0.85), width: 2),
              boxShadow: [
                BoxShadow(
                  color: FxTokens.indigo.withValues(alpha: _isDragging ? 0.45 : 0.32),
                  blurRadius: _isDragging ? 22 : 14,
                  spreadRadius: _isDragging ? 2 : 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: child.key == const ValueKey('icon_close')
                    ? Tween<double>(begin: 0.5, end: 1.0).animate(animation)
                    : Tween<double>(begin: -0.5, end: 0.0).animate(animation),
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: isOpen
                  ? Icon(Icons.close_rounded, key: const ValueKey('icon_close'), color: Colors.white, size: 26.sp)
                  : Icon(Icons.auto_awesome_rounded, key: const ValueKey('icon_chat'), color: Colors.white, size: 26.sp),
            ),
          ),
          if (!isOpen)
            Positioned(
              right: 1.w,
              top: 1.w,
              child: Container(
                width: 13.w,
                height: 13.w,
                decoration: BoxDecoration(
                  color: FxTokens.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
