import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/features/notifications/data/models/notification_model.dart';

class NotificationBottomSheet extends StatefulWidget {
  final NotificationSocketService notificationService;

  const NotificationBottomSheet({
    super.key,
    required this.notificationService,
  });

  @override
  State<NotificationBottomSheet> createState() => _NotificationBottomSheetState();
}

class _NotificationBottomSheetState extends State<NotificationBottomSheet> {
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'maintenance', 'other'

  @override
  void initState() {
    super.initState();
    widget.notificationService.addListener(_onNotificationUpdated);
  }

  @override
  void dispose() {
    widget.notificationService.removeListener(_onNotificationUpdated);
    super.dispose();
  }

  void _onNotificationUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isMaintenance(NotificationModel item) {
    if (item.event != null && item.event!.contains('maintenance')) return true;
    final text = item.getText().toLowerCase();
    return text.contains('bảo trì');
  }

  List<NotificationModel> get _filteredNotifications {
    final query = _searchQuery.trim().toLowerCase();
    final list = widget.notificationService.notifications.where((item) {
      if (_selectedCategory == 'maintenance' && !_isMaintenance(item)) return false;
      if (_selectedCategory == 'other' && _isMaintenance(item)) return false;
      return true;
    }).toList();
    
    if (query.isEmpty) return list;

    return list.where((item) {
      final text = item.getText().toLowerCase();
      return text.contains(query);
    }).toList();
  }

  String _formatTime(NotificationModel item) {
    final time = item.getParsedTime();
    if (time == null) return '--:--:--';
    return DateFormat('HH:mm:ss dd/MM/yyyy').format(time.toLocal());
  }

  void _markAllAsRead() {
    widget.notificationService.markAllAsRead();
  }

  Widget _buildChip(String label, String value, int count, ColorScheme colorScheme) {
    final isSelected = _selectedCategory == value;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = value),
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white, // indigo-50
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0), // indigo-500 / slate-200
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 14.sp, color: const Color(0xFF4F46E5)), // indigo-600
              SizedBox(width: 4.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B), // indigo-600 / slate-500
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.red.shade500,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifications = widget.notificationService.notifications;
    final filteredList = _filteredNotifications;
    final unreadCount = widget.notificationService.unreadCount;
    
    final totalUnread = notifications.where((n) => !n.read).length;
    final maintenanceUnread = notifications.where((n) => !n.read && _isMaintenance(n)).length;
    final otherUnread = totalUnread - maintenanceUnread;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)], // slate-800 to slate-700
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.notifications_rounded, color: Colors.white, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Thông báo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        unreadCount > 0 ? '$unreadCount chưa đọc' : 'Đã đọc hết',
                        style: TextStyle(
                          color: const Color(0xFFCBD5E1), // slate-300
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Search Bar & Categories
          Container(
            color: const Color(0xFFF8FAFC), // slate-50
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm thông báo...',
                      hintStyle: TextStyle(color: const Color(0xFF94A3B8), fontSize: 13.sp),
                      prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF94A3B8), size: 18.sp),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: const Color(0xFF64748B), size: 16.sp),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)), // slate-200
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8)), // sky-400
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
                  child: Row(
                    children: [
                      _buildChip('Tất cả', 'all', totalUnread, colorScheme),
                      SizedBox(width: 8.w),
                      _buildChip('Bảo trì xe', 'maintenance', maintenanceUnread, colorScheme),
                      SizedBox(width: 8.w),
                      _buildChip('Khác', 'other', otherUnread, colorScheme),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mark all as read
          if (unreadCount > 0)
            InkWell(
              onTap: _markAllAsRead,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F9FF), // sky-50
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.done_all_rounded, color: const Color(0xFF0369A1), size: 16.sp), // sky-700
                    SizedBox(width: 8.w),
                    Text(
                      'ĐÁNH DẤU TẤT CẢ ĐÃ ĐỌC',
                      style: TextStyle(
                        color: const Color(0xFF0369A1),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9), // slate-100
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _searchQuery.isNotEmpty ? Icons.search_rounded : Icons.notifications_none_rounded,
                            color: const Color(0xFFCBD5E1), // slate-300
                            size: 24.sp,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          _searchQuery.isNotEmpty ? 'Không tìm thấy thông báo' : 'Chưa có thông báo nào',
                          style: TextStyle(
                            color: const Color(0xFF94A3B8), // slate-400
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return InkWell(
                        onTap: () {
                          if (!item.read) {
                            widget.notificationService.markAsRead(item.id);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: item.read ? Colors.white : const Color(0xFFF0F9FF).withValues(alpha: 0.7),
                            border: Border(
                              bottom: const BorderSide(color: Color(0xFFF1F5F9)),
                              left: BorderSide(
                                color: item.read ? Colors.transparent : const Color(0xFF0EA5E9), // sky-500
                                width: 3.w,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 4.h),
                                child: Icon(
                                  Icons.circle,
                                  size: 10.sp,
                                  color: item.read ? const Color(0xFFE2E8F0) : const Color(0xFF0EA5E9),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.getText(),
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: item.read ? FontWeight.normal : FontWeight.w600,
                                        color: item.read ? const Color(0xFF475569) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time_rounded, size: 12.sp, color: const Color(0xFF64748B)),
                                        SizedBox(width: 4.w),
                                        Text(
                                          _formatTime(item),
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Footer
          if (notifications.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC), // slate-50
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Tìm thấy ${filteredList.length}/${notifications.length} thông báo'
                    : 'Tổng ${notifications.length} thông báo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF94A3B8), // slate-400
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NotificationBadge extends StatefulWidget {
  final NotificationSocketService notificationService;
  
  const NotificationBadge({
    super.key, 
    required this.notificationService,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  @override
  void initState() {
    super.initState();
    widget.notificationService.addListener(_onUpdate);
  }

  @override
  void dispose() {
    widget.notificationService.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.notificationService.unreadCount;
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(
            count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, 
            color: Theme.of(context).colorScheme.primary
          ),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => NotificationBottomSheet(
                notificationService: widget.notificationService,
              ),
            );
          },
        ),
        if (count > 0)
          Positioned(
            right: 8.w,
            top: 8.h,
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
