import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_history_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vm_ui_v2.dart';

/// "Lịch sử xử lý" (v2). Same constructor and data as `VehicleMaintenanceHistoryWidget`; timeline layout.
class VehicleMaintenanceHistoryWidgetV2 extends StatelessWidget {
  final List<VehicleMaintenanceHistory> histories;
  final bool isLoading;

  const VehicleMaintenanceHistoryWidgetV2({
    super.key,
    required this.histories,
    this.isLoading = false,
  });

  // ── Labels (verbatim from v1) ─────────────────────────────────────────────

  String _getActionLabel(String action) {
    const labels = {
      'create': 'Tạo phiếu',
      'update': 'Cập nhật phiếu',
      'submit': 'Gửi phiếu',
      'dispatch_approve': 'Kiểm tra bảo trì đạt',
      'dispatch_reject': 'Kiểm tra bảo trì từ chối',
      'production_approve': 'Phê duyệt bảo trì',
      'production_reject': 'Phê duyệt bảo trì từ chối',
      'delete': 'Xóa phiếu',
    };
    return labels[action] ?? action;
  }

  String _getStatusLabel(String? status) {
    if (status == null) return '-';
    const labels = {
      'draft': 'Nháp',
      'submitted': 'Đã gửi',
      'reviewing': 'Đang duyệt',
      'approved': 'Đã duyệt',
      'rejected': 'Từ chối',
      'completed': 'Hoàn tất',
      'canceled': 'Đã hủy',
    };
    return labels[status] ?? status;
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.history_rounded,
            title: 'Lịch sử xử lý',
            subtitle: isLoading
                ? 'Đang tải…'
                : (histories.isEmpty ? 'Các bước xử lý của phiếu' : '${histories.length} sự kiện'),
            tone: FxTokens.indigo,
          ),
          if (isLoading)
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FxSkeleton(height: 24.w, width: 24.w, radius: 12),
                    SizedBox(width: 10.w),
                    Expanded(child: FxSkeleton(height: 58.h)),
                  ],
                ),
              )
          else if (histories.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
              decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(12.r)),
              child: Row(
                children: [
                  Icon(Icons.timeline_rounded, size: 18.sp, color: t.textFaint),
                  SizedBox(width: 10.w),
                  Expanded(child: Text('Chưa có lịch sử xử lý.', style: t.small)),
                ],
              ),
            )
          else
            for (var i = 0; i < histories.length; i++)
              _HistoryItem(
                item: histories[i],
                last: i == histories.length - 1,
                actionLabel: _getActionLabel(histories[i].action),
                fromLabel: _getStatusLabel(histories[i].fromStatus),
                toLabel: _getStatusLabel(histories[i].toStatus),
              ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final VehicleMaintenanceHistory item;
  final bool last;
  final String actionLabel;
  final String fromLabel;
  final String toLabel;

  const _HistoryItem({
    required this.item,
    required this.last,
    required this.actionLabel,
    required this.fromLabel,
    required this.toLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final tone = VmTone.action(item.action);
    final isReject = item.action.contains('reject');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail
          SizedBox(
            width: 26.w,
            child: Column(
              children: [
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    color: t.soft(tone),
                    shape: BoxShape.circle,
                    border: Border.all(color: tone.withValues(alpha: 0.45)),
                  ),
                  child: Icon(VmTone.actionIcon(item.action), size: 13.sp, color: t.ink(tone)),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: EdgeInsets.symmetric(vertical: 3.h),
                      decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16.h, top: 2.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(actionLabel, style: t.h3)),
                      SizedBox(width: 8.w),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt.toLocal()),
                        style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                      ),
                    ],
                  ),
                  if (item.fromStatus != null || item.toStatus != null) ...[
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 4.w,
                      runSpacing: 4.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.fromStatus != null) FxPill(label: fromLabel, tone: VmTone.status(item.fromStatus)),
                        if (item.fromStatus != null && item.toStatus != null)
                          Icon(Icons.arrow_forward_rounded, size: 13.sp, color: t.textFaint),
                        if (item.toStatus != null) FxPill(label: toLabel, tone: VmTone.status(item.toStatus), dot: true),
                      ],
                    ),
                  ],
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 14.sp, color: t.textFaint),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          item.actor.name ?? 'User #${item.actor.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.small.copyWith(color: t.text, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (item.actor.roleLabel != null) ...[
                        SizedBox(width: 6.w),
                        Flexible(child: FxPill(label: item.actor.roleLabel!, tone: FxTokens.slate)),
                      ],
                    ],
                  ),
                  if (item.note != null && item.note!.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 8.h),
                      decoration: BoxDecoration(
                        color: t.soft(isReject ? FxTokens.red : FxTokens.slate),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: 15.sp,
                            color: isReject ? t.ink(FxTokens.red) : t.textFaint,
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              item.note!,
                              style: TextStyle(
                                fontSize: 12.5.sp,
                                height: 1.4,
                                color: isReject ? t.ink(FxTokens.red) : t.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
