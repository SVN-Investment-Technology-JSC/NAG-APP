import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/theme/app_colors.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_history_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/services/vehicle_maintenance_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/screens/vehicle_maintenance_form_page.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/widgets/vehicle_maintenance_discussion_widget.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/widgets/vehicle_maintenance_history_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class VehicleMaintenanceDetailPage extends StatefulWidget {
  final int maintenanceId;

  const VehicleMaintenanceDetailPage({super.key, required this.maintenanceId});

  @override
  State<VehicleMaintenanceDetailPage> createState() => _VehicleMaintenanceDetailPageState();
}

class _VehicleMaintenanceDetailPageState extends State<VehicleMaintenanceDetailPage> {
  final VehicleMaintenanceService _service = VehicleMaintenanceService(ApiClient.dio);
  
  bool _isLoading = true;
  bool _isHistoryLoading = true;
  VehicleMaintenance? _maintenance;
  List<VehicleMaintenanceHistory> _histories = [];

  final UserManageService _userManageService = UserManageService();
  String _userRole = '';
  bool _canUpdate = false;
  bool _canDelete = false;
  bool _canSubmit = false;
  bool _canDispatchReview = false;
  bool _canProductionApprove = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchDetail();
    _fetchHistory();
  }

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canUpdate = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__update');
          _canDelete = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__delete');
          _canSubmit = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__submit');
          _canDispatchReview = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__dispatch_review');
          _canProductionApprove = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__production_approve');
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getById(widget.maintenanceId);
      if (mounted) {
        setState(() {
          _maintenance = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi tải chi tiết phiếu bảo trì')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => _isHistoryLoading = true);
    try {
      final data = await _service.getHistory(widget.maintenanceId);
      if (mounted) {
        setState(() {
          _histories = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      if (mounted) {
        setState(() => _isHistoryLoading = false);
      }
    }
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

  String _getWorkflowActionLabel(String action) {
    const labels = {
      'submit': 'Gửi phiếu',
      'dispatch_approve': 'Kiểm tra đạt',
      'dispatch_reject': 'Từ chối kiểm tra',
      'production_approve': 'Phê duyệt',
      'production_reject': 'Từ chối phê duyệt',
      'delete': 'Xóa phiếu',
    };
    return labels[action] ?? action;
  }

  bool _actionRequiresReason(String action) {
    return action.contains('reject');
  }

  void _showWorkflowDialog(String action) {
    final requiresReason = _actionRequiresReason(action);
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận ${_getWorkflowActionLabel(action).toLowerCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bạn có chắc chắn muốn thực hiện hành động này?'),
            if (requiresReason) ...[
              SizedBox(height: 16.h),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Lý do (bắt buộc)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                maxLines: 3,
              )
            ] else ...[
              SizedBox(height: 16.h),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Ghi chú (tùy chọn)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                maxLines: 3,
              )
            ]
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final note = noteController.text.trim();
              if (requiresReason && note.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập lý do')));
                return;
              }
              Navigator.pop(ctx);
              _handleWorkflowAction(action, note.isNotEmpty ? note : null);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleWorkflowAction(String action, String? note) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      if (action == 'delete') {
        await _service.delete(widget.maintenanceId);
        if (mounted) {
          Navigator.pop(context); // close loading
          Navigator.pop(context, true); // go back and refresh
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa phiếu')));
        }
      } else {
        await _service.runWorkflowAction(widget.maintenanceId, action, note: note, reason: _actionRequiresReason(action) ? note : null);
        if (mounted) {
          Navigator.pop(context); // close loading
          _fetchDetail();
          _fetchHistory();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật trạng thái')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thao tác thất bại')));
      }
    }
  }

  bool _canPerformAction(String action) {
    if (_userRole == 'admin') return true;
    if (action == 'submit') return _canSubmit;
    if (action == 'dispatch_approve' || action == 'dispatch_reject') return _canDispatchReview;
    if (action == 'production_approve' || action == 'production_reject') return _canProductionApprove;
    return false;
  }

  Widget _buildInfoRow(String label, String value, {bool isHtml = false, Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
          SizedBox(height: 4.h),
          Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              fontSize: 14.sp, 
              color: valueColor ?? Colors.black87,
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_maintenance == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết phiếu bảo trì')),
        body: const Center(child: Text('Không tìm thấy phiếu')),
      );
    }

    final m = _maintenance!;
    final vehicleLabel = m.vehicle != null 
        ? '${m.vehicle!.vehicleLicensePlate}${m.vehicle!.vehicleName != null ? ' | ${m.vehicle!.vehicleName}' : ''}'
        : '#${m.vehicleId}';

    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: m.currency ?? 'VND');
    final isDraftOrRejected = ['draft', 'rejected'].contains(m.vehicleMaintenanceStatus);
    // Determine if the user can edit this maintenance (typically only creators can edit drafts, but let's allow it if workflow permits or status is draft)
    final canEdit = isDraftOrRejected && (_canUpdate || _userRole == 'admin');

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Phiếu Bảo Trì #${m.vehicleMaintenanceId}'),
        centerTitle: true,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Chỉnh sửa',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => VehicleMaintenanceFormPage(maintenance: m)),
                );
                if (result == true) {
                  _fetchDetail();
                  _fetchHistory();
                }
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
            ],
          ),
          child: Builder(
            builder: (context) {
              final showDelete = canEdit && (_canDelete || _userRole == 'admin');
              final activeActions = m.workflowAvailableActions != null
                  ? m.workflowAvailableActions!.where((a) => a != 'delete' && _canPerformAction(a)).toList()
                  : <String>[];

              return Row(
                children: [
                  if (showDelete)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        onPressed: () => _showWorkflowDialog('delete'),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Xóa'),
                      ),
                    ),
                  if (showDelete && activeActions.isNotEmpty)
                    SizedBox(width: 12.w),
                  ...activeActions.map((action) {
                    final isDanger = action.contains('reject');
                    IconData iconData = Icons.check_circle_outline;
                    if (isDanger) iconData = Icons.cancel_outlined;
                    if (action == 'submit') iconData = Icons.send;

                    final isFirst = activeActions.first == action;
                    final leftPadding = isFirst && !showDelete ? 0.0 : 12.w;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: leftPadding),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDanger ? Colors.red : theme.colorScheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                          ),
                          onPressed: () => _showWorkflowDialog(action),
                          icon: Icon(iconData, size: 20),
                          label: Text(_getWorkflowActionLabel(action)),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _getStatusColor(m.vehicleMaintenanceStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _getStatusColor(m.vehicleMaintenanceStatus).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: _getStatusColor(m.vehicleMaintenanceStatus)),
                  SizedBox(width: 8.w),
                  Text(
                    'Trạng thái: ${_getStatusLabel(m.vehicleMaintenanceStatus)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(m.vehicleMaintenanceStatus),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.mdH),

            // Card 1: Thông tin chung
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.directions_car, 'Thông tin phương tiện'),
                    _buildInfoRow('Phương tiện', vehicleLabel, valueColor: theme.colorScheme.primary),
                    _buildInfoRow('Thời gian bảo trì', '${DateFormat('dd/MM/yyyy').format(m.vehicleMaintenanceFromDatetime.toLocal())}${m.vehicleMaintenanceToDatetime != null ? ' - ${DateFormat('dd/MM/yyyy').format(m.vehicleMaintenanceToDatetime!.toLocal())}' : ''}'),
                    _buildInfoRow('Địa điểm sửa chữa', m.vehicleMaintenanceLocation ?? ''),
                    _buildInfoRow('Số KM hiện tại', m.vehicleDistanceCovered?.toString() ?? ''),
                    _buildInfoRow('Loại bảo trì', m.vehicleMaintenanceType == 'repair' ? 'Sửa chữa' : 'Bảo dưỡng'),
                    _buildInfoRow('Mức độ', 'Cấp ${m.vehicleMaintenanceRank ?? 1}'),
                    _buildInfoRow('Mô tả công việc', m.vehicleMaintenanceDescription ?? ''),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.mdH),

            // Card 2: Hóa đơn & Thanh toán
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.receipt_long, 'Hóa đơn & Thanh toán'),
                    _buildInfoRow('Đơn vị sửa chữa', m.serviceProviderName ?? ''),
                    _buildInfoRow('Số hóa đơn', m.invoiceNo ?? ''),
                    _buildInfoRow('Ngày hóa đơn', m.invoiceDate != null ? DateFormat('dd/MM/yyyy').format(m.invoiceDate!.toLocal()) : ''),
                    _buildInfoRow('Tổng tiền', m.totalAmount != null ? formatter.format(m.totalAmount) : ''),
                    _buildInfoRow('Trạng thái thanh toán', m.paymentStatus == 'paid' ? 'Đã thanh toán' : (m.paymentStatus == 'partial' ? 'Thanh toán 1 phần' : 'Chưa thanh toán')),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.mdH),

            // Card 3: Tài liệu đính kèm
            if (m.documents != null && m.documents!.isNotEmpty) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(Icons.attach_file, 'Tài liệu đính kèm'),
                      ...m.documents!.map((doc) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(Icons.insert_drive_file, color: Colors.blue.shade400),
                          ),
                          title: Text((doc.media is Map ? doc.media['media_name'] : null) ?? 'Tài liệu #${doc.vehicleMaintenanceDocumentId}'),
                          subtitle: Text(doc.documentType),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            onPressed: () {
                              final mediaUrl = doc.media is Map ? doc.media['media_url'] : null;
                              if (mediaUrl != null) {
                                launchUrl(Uri.parse(mediaUrl));
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.mdH),
            ],

            // History Widget
            VehicleMaintenanceHistoryWidget(histories: _histories, isLoading: _isHistoryLoading),
            SizedBox(height: AppSpacing.mdH),

            // Discussion Widget
            VehicleMaintenanceDiscussionWidget(maintenanceId: widget.maintenanceId),
            SizedBox(height: AppSpacing.mdH),
          ],
        ),
      ),
    );
  }
}
