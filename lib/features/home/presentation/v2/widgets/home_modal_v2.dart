import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// Shared building blocks of the v2 home dialogs (check-log, queue history, sync slots).

/// "LỊCH SỬ LỐT XE" -> "Lịch sử lốt xe" (some l10n strings are upper case).
String homeSentenceV2(String s) {
  if (s.isEmpty || s != s.toUpperCase()) return s;
  final l = s.toLowerCase();
  return l[0].toUpperCase() + l.substring(1);
}

/// Frame of a v2 home dialog: rounded 24 card, header (icon badge + title + subtitle + close),
/// optional toolbar under the header, body on the page background, optional sticky footer.
/// Shrinks with the keyboard (no overflow).
class HomeModalFrameV2 extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String? subtitle;
  final List<Widget> pills;
  final Widget? toolbar;
  final Widget body;
  final Widget? footer;
  final double maxHeightFactor;
  final bool closeEnabled;

  const HomeModalFrameV2({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    this.subtitle,
    this.pills = const [],
    this.toolbar,
    required this.body,
    this.footer,
    this.maxHeightFactor = 0.9,
    this.closeEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    // read outside the Dialog (which strips view insets from its child): compact layout while typing
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Dialog(
      backgroundColor: t.bg,
      insetPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 20.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeightFactor.sh),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 10.w, 14.h),
              decoration: BoxDecoration(
                color: t.card,
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FxIconBadge(icon: icon, tone: tone, size: 42),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 1.h),
                            Text(title, style: t.h1.copyWith(fontSize: 18.sp), maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              Text(subtitle!, style: t.small, maxLines: keyboard ? 1 : 3, overflow: TextOverflow.ellipsis),
                            ],
                            if (pills.isNotEmpty && !keyboard) ...[
                              SizedBox(height: 8.h),
                              Wrap(spacing: 6.w, runSpacing: 6.h, children: pills),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 6.w),
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: closeEnabled ? () => Navigator.of(context).pop() : null,
                        icon: Icon(Icons.close_rounded, color: t.text, size: 20.sp),
                        style: IconButton.styleFrom(backgroundColor: t.cardAlt, side: BorderSide(color: t.border)),
                      ),
                    ],
                  ),
                  if (toolbar != null) ...[SizedBox(height: 12.h), toolbar!],
                ],
              ),
            ),
            Expanded(child: body),
            if (footer != null && !keyboard)
              Container(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
                decoration: BoxDecoration(
                  color: t.card,
                  border: Border(top: BorderSide(color: t.border)),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// ‹  Thứ Ba · 25/11/2026  › date navigator. [onNext] null disables the forward arrow.
class HomeDateNavV2 extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  const HomeDateNavV2({super.key, required this.date, required this.onPrev, required this.onNext, required this.onPick});

  static const _days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(date, now);
    final isYesterday = DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)));

    Widget arrow(IconData icon, String tip, VoidCallback? onTap) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon, size: 22.sp, color: onTap == null ? t.textFaint : t.text),
        );

    return Container(
      height: 46.h,
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          arrow(Icons.chevron_left_rounded, 'Ngày trước', onPrev),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10.r),
                onTap: onPick,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 15.sp, color: t.ink(FxTokens.blue)),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Text(
                          isToday ? 'Hôm nay' : (isYesterday ? 'Hôm qua' : _days[date.weekday - 1]),
                          style: t.small,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(DateFormat('dd/MM/yyyy').format(date), style: t.h3.copyWith(fontFeatures: FxTokens.tabular)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          arrow(Icons.chevron_right_rounded, 'Ngày sau', onNext),
        ],
      ),
    );
  }
}

/// Skeleton list for dialog bodies.
class HomeListSkeletonV2 extends StatelessWidget {
  final int count;
  final double height;
  const HomeListSkeletonV2({super.key, this.count = 6, required this.height});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(12.w),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < count; i++) ...[
          FxSkeleton(height: height, radius: 14),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}
