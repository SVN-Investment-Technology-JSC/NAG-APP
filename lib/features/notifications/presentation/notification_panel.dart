import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:vehicle_management/core/network/notification_socket_service.dart';
import 'package:vehicle_management/features/notifications/data/models/notification_model.dart';
import 'package:vehicle_management/l10n/app_localizations.dart';

/// Mở notification panel dưới dạng BottomSheet
void showNotificationPanel(
  BuildContext context,
  NotificationSocketService service,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NotificationPanel(service: service),
  );
}

class NotificationPanel extends StatefulWidget {
  final NotificationSocketService service;

  const NotificationPanel({super.key, required this.service});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifications = widget.service.notifications;
    final unread = widget.service.unreadCount;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // ── Header ──────────────────────────────────────────────────
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_rounded,
                        color: colorScheme.primary, size: 22.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.notifications,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${notifications.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Refresh button
                    IconButton(
                      onPressed: () => widget.service.connect(),
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 20.sp,
                      ),
                    ),
                    // Unread badge
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: unread > 0
                            ? Colors.red
                            : colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '$unread',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── List ────────────────────────────────────────────────────
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 48.sp,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              l10n.notificationsEmpty,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: EdgeInsets.all(12.w),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8.h),
                        itemBuilder: (context, index) {
                          return _NotificationItem(
                            notification: notifications[index],
                            onTap: () => widget.service
                                .markAsRead(notifications[index].id),
                            formatTimestamp: _formatTimestamp,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final String Function(NotificationModel) formatTimestamp;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUnread = !notification.read;

    final bgColor = isUnread
        ? const Color(0xFFECFDF5) // emerald-50
        : colorScheme.surface;
    final borderColor = isUnread
        ? const Color(0xFF6EE7B7) // emerald-300
        : colorScheme.outlineVariant;
    final barColor = isUnread
        ? const Color(0xFF10B981) // emerald-500
        : colorScheme.onSurface.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: borderColor),
          boxShadow: isUnread
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left colour bar (giống web)
              Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    bottomLeft: Radius.circular(12.r),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.w, vertical: 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timestamp + badge row
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12.sp,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              formatTimestamp(notification),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Read / Unread chip
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? const Color(0xFFECFDF5)
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20.r),
                              border: isUnread
                                  ? Border.all(
                                      color: const Color(0xFF6EE7B7),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUnread
                                      ? Icons.notifications_active_rounded
                                      : Icons.visibility_rounded,
                                  size: 11.sp,
                                  color: isUnread
                                      ? const Color(0xFF059669)
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  isUnread
                                      ? l10n.notificationUnread
                                      : l10n.notificationRead,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isUnread
                                        ? const Color(0xFF059669)
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8.h),

                      // Message
                      Text(
                        notification.getText(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isUnread
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
