import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/notifications/data/models/notification_model.dart';
import 'package:nguyenanh/features/notifications/presentation/v2/widgets/notification_tile_v2.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// Mở notification panel (v2) dưới dạng BottomSheet — same sheet options as [showNotificationPanel] (v1).
void showNotificationPanelV2(
  BuildContext context,
  NotificationSocketService service,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NotificationPanelV2(service: service),
  );
}

/// Notification panel (v2). Same listener, refresh (reconnect), unread count and tap-to-mark-read as
/// [NotificationPanel] (v1, ../notification_panel.dart) — only the layout changes.
class NotificationPanelV2 extends StatefulWidget {
  final NotificationSocketService service;

  const NotificationPanelV2({super.key, required this.service});

  @override
  State<NotificationPanelV2> createState() => _NotificationPanelV2State();
}

class _NotificationPanelV2State extends State<NotificationPanelV2> {
  // ── Logic (verbatim from v1) ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _formatTimestamp(NotificationModel item) {
    final dt = item.getParsedTime();
    if (dt == null) return '--:--';
    return DateFormat('HH:mm:ss dd/MM/yyyy').format(dt.toLocal());
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  String _rowTime(NotificationModel item, NotificationDayV2 day) {
    final dt = item.getParsedTime();
    if (dt == null || day == NotificationDayV2.earlier) return _formatTimestamp(item);
    return DateFormat('HH:mm:ss').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = FxTokens.of(context);
    final notifications = widget.service.notifications;
    final unread = widget.service.unreadCount;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 12.w, 12.h),
                child: Row(
                  children: [
                    const FxIconBadge(icon: Icons.notifications_rounded, tone: FxTokens.blue, size: 40),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.notifications, style: t.h2.copyWith(fontSize: 17.sp)),
                          SizedBox(height: 1.h),
                          Text(
                            '${notifications.length} · $unread ${l10n.notificationUnread.toLowerCase()}',
                            style: t.small.copyWith(fontFeatures: FxTokens.tabular),
                          ),
                        ],
                      ),
                    ),
                    // Refresh button
                    IconButton(
                      tooltip: 'Làm mới',
                      onPressed: () => widget.service.connect(),
                      icon: Icon(Icons.refresh_rounded, color: t.textMuted, size: 20.sp),
                    ),
                    // Unread badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: unread > 0 ? FxTokens.red : t.cardAlt,
                        borderRadius: BorderRadius.circular(20.r),
                        border: unread > 0 ? null : Border.all(color: t.border),
                      ),
                      child: Text(
                        '$unread',
                        style: TextStyle(
                          color: unread > 0 ? Colors.white : t.textMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.sp,
                          fontFeatures: FxTokens.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: t.divider),

              // ── List ────────────────────────────────────────────────────
              Expanded(
                child: notifications.isEmpty
                    ? ListView(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        children: [
                          SizedBox(height: 56.h),
                          FxEmpty(
                            icon: Icons.notifications_off_outlined,
                            title: l10n.notificationsEmpty,
                          ),
                        ],
                      )
                    : _groupedList(l10n, notifications, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _groupedList(AppLocalizations l10n, List<NotificationModel> notifications, ScrollController scrollController) {
    final groups = groupNotificationsV2(notifications);
    final bottom = MediaQuery.of(context).padding.bottom;
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h + bottom),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        final unread = g.items.where((n) => !n.read).length;
        return NotificationGroupV2(
          day: g.day,
          badge: unread > 0 ? '$unread ${l10n.notificationUnread.toLowerCase()}' : null,
          tiles: [
            for (final item in g.items)
              NotificationTileV2(
                key: ValueKey('panel-${item.id}'),
                notification: item,
                timeLabel: _rowTime(item, g.day),
                statusLabel: item.read ? l10n.notificationRead : l10n.notificationUnread,
                onTap: () => widget.service.markAsRead(item.id),
                onMarkRead: () => widget.service.markAsRead(item.id),
              ),
          ],
        );
      },
    );
  }
}
