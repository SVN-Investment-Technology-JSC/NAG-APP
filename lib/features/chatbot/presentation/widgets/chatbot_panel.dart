import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/features/chatbot/presentation/chatbot_provider.dart';

class ChatbotPanel extends StatefulWidget {
  const ChatbotPanel({super.key});

  @override
  State<ChatbotPanel> createState() => _ChatbotPanelState();
}

class _ChatbotPanelState extends State<ChatbotPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _suggested = [
    "Hôm nay có bao nhiêu chuyến?",
    "Xe nào cần bảo trì gấp?",
    "Sản lượng tháng này?",
    "Xe nào chạy nhiều nhất?",
    "Tỷ lệ hoàn thành hôm nay?",
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatbotProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.isOpen && _scrollController.hasClients && 
          _scrollController.position.pixels < _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4DA1FF), Color(0xFF0A7BFF)]),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 18.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trợ lý AI',
                        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      Text(
                        'Nguyên Anh II',
                        style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  iconSize: 20.sp,
                  color: colorScheme.onSurfaceVariant,
                  onPressed: () {
                    provider.reset();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20.sp,
                  color: colorScheme.onSurfaceVariant,
                  onPressed: () {
                    provider.closePanel();
                  },
                ),
              ],
            ),
          ),
          
          // Messages List
          Expanded(
            child: Container(
              color: colorScheme.surfaceContainerLowest,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(12.w),
                itemCount: provider.messages.length,
                itemBuilder: (context, index) {
                  final msg = provider.messages[index];
                  final isUser = msg.role == 'user';
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Row(
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isUser) ...[
                           CircleAvatar(
                            radius: 12.r,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(Icons.smart_toy_rounded, size: 14.sp, color: colorScheme.primary),
                          ),
                          SizedBox(width: 8.w),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // Status / Reasoning steps
                              if (!isUser && msg.toolSteps.isNotEmpty && msg.text.isEmpty)
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  margin: EdgeInsets.only(bottom: 4.h),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: msg.toolSteps.map((step) => Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 12.sp, color: Colors.green),
                                        SizedBox(width: 4.w),
                                        Flexible(
                                          child: Text(
                                            step, 
                                            style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant),
                                          ),
                                        ),
                                      ],
                                    )).toList(),
                                  ),
                                ),
                                
                              if (!isUser && msg.loading && msg.text.isEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: const SizedBox(
                                    width: 20, 
                                    height: 10, 
                                    child: LinearProgressIndicator()
                                  ),
                                )
                              else if (msg.text.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16.r),
                                      topRight: Radius.circular(16.r),
                                      bottomLeft: Radius.circular(isUser ? 16.r : 4.r),
                                      bottomRight: Radius.circular(isUser ? 4.r : 16.r),
                                    ),
                                  ),
                                  child: Text(
                                    msg.text,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isUser) SizedBox(width: 8.w),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Suggested Questions
          if (!provider.loading)
            Container(
              height: 40.h,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                itemCount: _suggested.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: ActionChip(
                      label: Text(_suggested[index], style: TextStyle(fontSize: 12.sp, color: colorScheme.primary)),
                      backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _send(_suggested[index]),
                    ),
                  );
                },
              ),
            ),
            
          // Input Area
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22.r)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        isDense: true,
                      ),
                      style: TextStyle(fontSize: 14.sp),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => _send(_inputController.text),
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: provider.loading ? colorScheme.outline : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_upward_rounded, color: colorScheme.onPrimary, size: 20.sp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}
