import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_history_model.dart';

class VehicleMaintenanceHistoryWidget extends StatelessWidget {
  final List<VehicleMaintenanceHistory> histories;
  final bool isLoading;

  const VehicleMaintenanceHistoryWidget({
    super.key,
    required this.histories,
    this.isLoading = false,
  });

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

  Color _getStatusColor(String? status) {
    if (status == 'approved' || status == 'completed') return Colors.green;
    if (status == 'rejected' || status == 'canceled') return Colors.red;
    if (status == 'submitted') return Colors.blue;
    if (status == 'reviewing') return Colors.purple;
    if (status == 'draft') return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Lịch sử xử lý',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.mdH),
            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (histories.isEmpty)
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: const Text('Chưa có lịch sử xử lý.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...histories.map((item) {
                final isLast = histories.last == item;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline line
                      SizedBox(
                        width: 24.w,
                        child: Column(
                          children: [
                            Container(
                              width: 12.w,
                              height: 12.w,
                              margin: EdgeInsets.only(top: 4.h),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.primary, width: 2),
                                color: Colors.white,
                              ),
                              child: Center(
                                child: Container(
                                  width: 4.w,
                                  height: 4.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 1,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Content
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.only(bottom: AppSpacing.mdH, left: 8.w),
                          padding: EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getActionLabel(item.action),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        if (item.fromStatus != null || item.toStatus != null) ...[
                                          SizedBox(height: 6.h),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (item.fromStatus != null)
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(item.fromStatus).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4.r),
                                                    border: Border.all(color: _getStatusColor(item.fromStatus).withOpacity(0.3)),
                                                  ),
                                                  child: Text(
                                                    _getStatusLabel(item.fromStatus),
                                                    style: TextStyle(fontSize: 10.sp, color: _getStatusColor(item.fromStatus)),
                                                  ),
                                                ),
                                              if (item.fromStatus != null && item.toStatus != null)
                                                Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                                                  child: const Icon(Icons.arrow_forward_outlined, size: 12, color: Colors.grey),
                                                ),
                                              if (item.toStatus != null)
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(item.toStatus).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4.r),
                                                    border: Border.all(color: _getStatusColor(item.toStatus).withOpacity(0.3)),
                                                  ),
                                                  child: Text(
                                                    _getStatusLabel(item.toStatus),
                                                    style: TextStyle(fontSize: 10.sp, color: _getStatusColor(item.toStatus)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt.toLocal()),
                                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Text(
                                    item.actor.name ?? 'User #${item.actor.id}',
                                    style: TextStyle(fontSize: 13.sp, color: Colors.black87),
                                  ),
                                  if (item.actor.roleLabel != null) ...[
                                    SizedBox(width: 8.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4.r),
                                      ),
                                      child: Text(
                                        item.actor.roleLabel!,
                                        style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                              if (item.note != null && item.note!.isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    item.note!,
                                    style: TextStyle(fontSize: 13.sp, color: Colors.red.shade900),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
