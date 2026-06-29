import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/features/chatbot/presentation/chatbot_provider.dart';
import 'package:nguyenanh/features/chatbot/presentation/widgets/chatbot_panel.dart';

class ChatbotBubble extends StatefulWidget {
  final Widget child; // The main app content over which the bubble floats

  const ChatbotBubble({super.key, required this.child});

  @override
  State<ChatbotBubble> createState() => _ChatbotBubbleState();
}

class _ChatbotBubbleState extends State<ChatbotBubble> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatbotProvider>();
    final size = MediaQuery.of(context).size;
    
    if (!provider.isBubbleVisible) {
      return widget.child;
    }

    final viewInsets = MediaQuery.of(context).viewInsets;

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
            child: const ChatbotPanel(),
          ),

        // Dismiss Area
        if (_isDragging && !provider.isOpen)
          Positioned(
            bottom: 60.h,
            left: (size.width - 60.w) / 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isInDismissZone ? 70.w : 60.w,
              height: _isInDismissZone ? 70.w : 60.w,
              decoration: BoxDecoration(
                color: _isInDismissZone ? Colors.red : Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: _isInDismissZone ? 32.sp : 24.sp,
              ),
            ),
          ),

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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4DA1FF), Color(0xFF0A7BFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0A7BFF).withValues(alpha: 0.4),
                      blurRadius: _isDragging ? 20 : 12,
                      spreadRadius: _isDragging ? 2 : 0,
                      offset: const Offset(0, 4),
                    )
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
                  child: provider.isOpen
                      ? Icon(Icons.close, key: const ValueKey('icon_close'), color: Colors.white, size: 28.sp)
                      : Icon(Icons.smart_toy_outlined, key: const ValueKey('icon_chat'), color: Colors.white, size: 28.sp),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
