import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/notifications/data/models/notification_model.dart';
import 'package:nguyenanh/features/notifications/presentation/v2/widgets/notification_tile_v2.dart';

/// Notification sheet (v2). Same listener, search, category filter (Tất cả / Bảo trì xe / Khác),
/// unread counts, tap-to-mark-read and mark-all-read as [NotificationBottomSheet]
/// (v1, ../../widgets/notification_bottom_sheet.dart) — only the layout changes.
class NotificationBottomSheetV2 extends StatefulWidget {
  final NotificationSocketService notificationService;

  const NotificationBottomSheetV2({
    super.key,
    required this.notificationService,
  });

  @override
  State<NotificationBottomSheetV2> createState() => _NotificationBottomSheetV2State();
}

class _NotificationBottomSheetV2State extends State<NotificationBottomSheetV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  String _searchQuery = '';
  String _selectedCategory = 'all'; // 'all', 'maintenance', 'other'

  // ── v2 presentation only ──────────────────────────────────────────────────
  /// Lets the clear button also clear the text field (v1 only reset the query).
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.notificationService.addListener(_onNotificationUpdated);
  }

  @override
  void dispose() {
    widget.notificationService.removeListener(_onNotificationUpdated);
    _searchController.dispose();
    super.dispose();
  }

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

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

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  /// Time shown on a row: clock only under "Hôm nay" / "Hôm qua", full date otherwise.
  String _rowTime(NotificationModel item, NotificationDayV2 day) {
    final time = item.getParsedTime();
    if (time == null || day == NotificationDayV2.earlier) return _formatTime(item);
    return DateFormat('HH:mm:ss').format(time.toLocal());
  }

  static String _cap(int n) => n > 99 ? '99+' : '$n';

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final notifications = widget.notificationService.notifications;
    final filteredList = _filteredNotifications;
    final unreadCount = widget.notificationService.unreadCount;

    final totalUnread = notifications.where((n) => !n.read).length;
    final maintenanceUnread = notifications.where((n) => !n.read && _isMaintenance(n)).length;
    final otherUnread = totalUnread - maintenanceUnread;

    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final height = math.min(mq.size.height * 0.85, mq.size.height - keyboard - mq.padding.top - 8);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 6.w, 12.h),
              child: Row(
                children: [
                  const FxIconBadge(icon: Icons.notifications_rounded, tone: FxTokens.blue, size: 40),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thông báo', style: t.h2.copyWith(fontSize: 17.sp)),
                        SizedBox(height: 1.h),
                        Text(
                          unreadCount > 0 ? '$unreadCount chưa đọc' : 'Đã đọc hết',
                          style: t.small.copyWith(
                            color: unreadCount > 0 ? t.ink(FxTokens.blue) : t.textMuted,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(color: FxTokens.red, borderRadius: BorderRadius.circular(12.r)),
                      child: Text(
                        _cap(unreadCount),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                          fontFeatures: FxTokens.tabular,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Đóng',
                    icon: Icon(Icons.close_rounded, color: t.textMuted),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
              child: _searchField(t),
            ),

            // Categories
            SizedBox(
              height: 34.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                children: [
                  _chip('Tất cả', 'all', totalUnread, Icons.all_inbox_rounded),
                  SizedBox(width: 8.w),
                  _chip('Bảo trì xe', 'maintenance', maintenanceUnread, Icons.build_rounded),
                  SizedBox(width: 8.w),
                  _chip('Khác', 'other', otherUnread, Icons.more_horiz_rounded),
                ],
              ),
            ),

            // Summary + mark all as read
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 6.h, 8.w, 2.h),
              child: SizedBox(
                height: 36.h,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'Tìm thấy ${filteredList.length}/${notifications.length} thông báo'
                            : 'Tổng ${notifications.length} thông báo',
                        style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0)
                      TextButton.icon(
                        onPressed: _markAllAsRead,
                        style: TextButton.styleFrom(
                          minimumSize: Size(0, 32.h),
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(Icons.done_all_rounded, size: 17.sp),
                        label: Text('Đánh dấu đã đọc tất cả', style: TextStyle(fontSize: 12.5.sp)),
                      ),
                  ],
                ),
              ),
            ),

            // List
            Expanded(
              child: filteredList.isEmpty
                  ? ListView(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      children: [
                        SizedBox(height: 40.h),
                        FxEmpty(
                          icon: _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.notifications_none_rounded,
                          title: _searchQuery.isNotEmpty ? 'Không tìm thấy thông báo' : 'Chưa có thông báo nào',
                          message: _searchQuery.isNotEmpty
                              ? 'Thử tìm với từ khoá khác.'
                              : 'Thông báo mới sẽ xuất hiện tại đây.',
                        ),
                      ],
                    )
                  : _groupedList(t, filteredList),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupedList(FxTokens t, List<NotificationModel> list) {
    final groups = groupNotificationsV2(list);
    final bottom = MediaQuery.of(context).padding.bottom;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 16.h + bottom),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        final unread = g.items.where((n) => !n.read).length;
        return NotificationGroupV2(
          day: g.day,
          badge: unread > 0 ? '$unread chưa đọc' : null,
          tiles: [
            for (final item in g.items)
              NotificationTileV2(
                key: ValueKey('sheet-${item.id}'),
                notification: item,
                timeLabel: _rowTime(item, g.day),
                onTap: () {
                  if (!item.read) {
                    widget.notificationService.markAsRead(item.id);
                  }
                },
                onMarkRead: () {
                  if (!item.read) {
                    widget.notificationService.markAsRead(item.id);
                  }
                },
              ),
          ],
        );
      },
    );
  }

  Widget _searchField(FxTokens t) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      textInputAction: TextInputAction.search,
      style: t.body,
      decoration: InputDecoration(
        hintText: 'Tìm kiếm thông báo...',
        hintStyle: t.small,
        prefixIcon: Icon(Icons.search_rounded, color: t.textFaint, size: 20.sp),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Xoá tìm kiếm',
                icon: Icon(Icons.close_rounded, color: t.textMuted, size: 18.sp),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: t.card,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
        border: b(t.border),
        enabledBorder: b(t.border),
        focusedBorder: b(FxTokens.blue, 1.4),
      ),
    );
  }

  Widget _chip(String label, String value, int count, IconData icon) {
    final t = FxTokens.of(context);
    final isSelected = _selectedCategory == value;
    final fg = isSelected ? t.ink(FxTokens.blue) : t.textMuted;
    return Material(
      color: isSelected ? t.soft(FxTokens.blue) : t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(color: isSelected ? FxTokens.blue.withValues(alpha: 0.45) : t.border, width: isSelected ? 1.3 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = value),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelected ? Icons.check_rounded : icon, size: 14.sp, color: fg),
              SizedBox(width: 5.w),
              Text(
                label,
                style: TextStyle(fontSize: 12.sp, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: fg),
              ),
              if (count > 0) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(color: FxTokens.red, borderRadius: BorderRadius.circular(8.r)),
                  child: Text(
                    _cap(count),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      fontFeatures: FxTokens.tabular,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// App-bar bell (v2). Same listener, unread count and sheet as [NotificationBadge]
/// (v1, ../../widgets/notification_bottom_sheet.dart); opens [NotificationBottomSheetV2].
class NotificationBadgeV2 extends StatefulWidget {
  final NotificationSocketService notificationService;

  const NotificationBadgeV2({
    super.key,
    required this.notificationService,
  });

  @override
  State<NotificationBadgeV2> createState() => _NotificationBadgeV2State();
}

class _NotificationBadgeV2State extends State<NotificationBadgeV2> {
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
    final t = FxTokens.of(context);
    final count = widget.notificationService.unreadCount;
    final ring = AppBarTheme.of(context).backgroundColor ?? t.bg;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Thông báo',
          icon: Icon(
            count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
            color: t.text,
            size: 24.sp,
          ),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => NotificationBottomSheetV2(
                notificationService: widget.notificationService,
              ),
            );
          },
        ),
        Positioned(
          right: 6.w,
          top: 6.h,
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: count > 0
                  ? Container(
                      key: ValueKey(count > 99 ? 100 : count),
                      constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.w),
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: FxTokens.red,
                        borderRadius: BorderRadius.circular(9.w),
                        border: Border.all(color: ring, width: 2),
                      ),
                      child: Text(
                        count > 99 ? '99+' : count.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          fontFeatures: FxTokens.tabular,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ),
        ),
      ],
    );
  }
}
