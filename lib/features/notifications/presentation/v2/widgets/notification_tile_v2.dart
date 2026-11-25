import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/notifications/data/models/notification_model.dart';

/// Presentation helpers shared by the v2 notification sheet and panel (no logic here).

/// Day bucket of a notification.
enum NotificationDayV2 { today, yesterday, earlier }

extension NotificationDayV2Label on NotificationDayV2 {
  String get label => switch (this) {
        NotificationDayV2.today => 'Hôm nay',
        NotificationDayV2.yesterday => 'Hôm qua',
        NotificationDayV2.earlier => 'Trước đó',
      };
}

NotificationDayV2 notificationDayV2(NotificationModel n, {DateTime? now}) {
  final dt = n.getParsedTime()?.toLocal();
  if (dt == null) return NotificationDayV2.earlier;
  final ref = now ?? DateTime.now();
  final today = DateTime(ref.year, ref.month, ref.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (!day.isBefore(today)) return NotificationDayV2.today;
  if (day == today.subtract(const Duration(days: 1))) return NotificationDayV2.yesterday;
  return NotificationDayV2.earlier;
}

/// Groups [list] into Hôm nay / Hôm qua / Trước đó, keeping the given order inside each group.
List<({NotificationDayV2 day, List<NotificationModel> items})> groupNotificationsV2(List<NotificationModel> list) {
  final now = DateTime.now();
  final buckets = {for (final d in NotificationDayV2.values) d: <NotificationModel>[]};
  for (final n in list) {
    buckets[notificationDayV2(n, now: now)]!.add(n);
  }
  return [
    for (final d in NotificationDayV2.values)
      if (buckets[d]!.isNotEmpty) (day: d, items: buckets[d]!),
  ];
}

/// Icon / tone / label of a notification by its event (display only).
({IconData icon, Color tone, String label}) notificationKindV2(NotificationModel n) {
  final e = n.event ?? '';
  switch (e) {
    case 'station_check_in':
      return (icon: Icons.login_rounded, tone: FxTokens.emerald, label: 'Vào trạm');
    case 'station_check_out':
      return (icon: Icons.logout_rounded, tone: FxTokens.amber, label: 'Rời trạm');
    case 'vehicle_check_in':
      return (icon: Icons.local_parking_rounded, tone: FxTokens.blue, label: 'Vào bãi');
    case 'vehicle_check_out':
      return (icon: Icons.exit_to_app_rounded, tone: FxTokens.cyan, label: 'Rời bãi');
  }
  if (e.contains('maintenance') || n.getText().toLowerCase().contains('bảo trì')) {
    return (icon: Icons.build_rounded, tone: FxTokens.orange, label: 'Bảo trì xe');
  }
  return (icon: Icons.notifications_rounded, tone: FxTokens.indigo, label: 'Thông báo');
}

/// One notification row. Unread rows are tinted, bold and carry a blue dot.
class NotificationTileV2 extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final String timeLabel;

  /// Swipe-left action "Đã đọc" (only offered while the row is unread).
  final VoidCallback? onMarkRead;

  /// Optional "Đã đọc / Chưa đọc" pill (labels passed in so callers keep their l10n strings).
  final String? statusLabel;

  const NotificationTileV2({
    super.key,
    required this.notification,
    required this.onTap,
    required this.timeLabel,
    this.onMarkRead,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final unread = !notification.read;
    final kind = notificationKindV2(notification);
    final tint = Color.alphaBlend(FxTokens.blue.withValues(alpha: t.dark ? 0.10 : 0.045), t.card);

    final tile = Material(
      color: unread ? tint : t.card,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.w, 11.h, 12.w, 11.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FxIconBadge(icon: kind.icon, tone: kind.tone, size: 36),
              SizedBox(width: 11.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            kind.label.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.overline.copyWith(color: t.ink(kind.tone), letterSpacing: 0.6),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(Icons.schedule_rounded, size: 11.sp, color: t.textFaint),
                        SizedBox(width: 3.w),
                        Text(timeLabel, style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      notification.getText(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(
                        fontSize: 13.5.sp,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        color: unread ? t.text : t.textMuted,
                      ),
                    ),
                    if (statusLabel != null) ...[
                      SizedBox(height: 6.h),
                      FxPill(
                        label: statusLabel!,
                        tone: unread ? FxTokens.emerald : FxTokens.slate,
                        icon: unread ? Icons.notifications_active_rounded : Icons.visibility_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unread ? FxTokens.blue : Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Slidable(
      key: ValueKey('notif-${notification.id}'),
      enabled: unread && onMarkRead != null,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => onMarkRead?.call(),
            backgroundColor: FxTokens.blue,
            foregroundColor: Colors.white,
            icon: Icons.done_rounded,
            label: 'Đã đọc',
          ),
        ],
      ),
      child: tile,
    );
  }
}

/// Group header + card holding the rows of one day.
class NotificationGroupV2 extends StatelessWidget {
  final NotificationDayV2 day;
  final List<Widget> tiles;

  /// Optional pill at the right of the header (e.g. "3 chưa đọc").
  final String? badge;

  const NotificationGroupV2({super.key, required this.day, required this.tiles, this.badge});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, color: t.divider, indent: 59.w));
      rows.add(tiles[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 8.h),
          child: Row(
            children: [
              Text(day.label.toUpperCase(), style: t.overline),
              SizedBox(width: 6.w),
              Text('${tiles.length}', style: t.overline.copyWith(color: t.textMuted, fontFeatures: FxTokens.tabular)),
              const Spacer(),
              if (badge != null) FxPill(label: badge!, tone: FxTokens.blue, dot: true),
            ],
          ),
        ),
        FxCard(
          padding: EdgeInsets.zero,
          margin: EdgeInsets.only(bottom: 14.h),
          child: SlidableAutoCloseBehavior(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
          ),
        ),
      ],
    );
  }
}
