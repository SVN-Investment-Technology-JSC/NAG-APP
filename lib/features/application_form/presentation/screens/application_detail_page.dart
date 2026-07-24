import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:nguyenanh/features/application_form/data/models/application_model.dart';
import 'package:nguyenanh/features/application_form/presentation/application_provider.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

class ApplicationDetailPage extends StatefulWidget {
  final int applicationId;
  const ApplicationDetailPage({super.key, required this.applicationId});

  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  String _userRole = '';
  bool _isLoading = true;
  bool _isProcessing = false;
  final _notesController = TextEditingController();
  bool _canReview = false;
  bool _canCancel = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'driver';
    _userRole = role;
    
    try {
      final UserManageService userService = UserManageService();
      final perms = await userService.getPermissions();
      final myPerms = perms[role] ?? [];
      if (mounted) {
        setState(() {
          _canReview = role == 'admin' || myPerms.contains('/work-arrangements/lot-tag-requests__review');
          _canCancel = role == 'admin' || role == 'driver' || myPerms.contains('/work-arrangements/lot-tag-requests__cancel');
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _canReview = role == 'admin';
          _canCancel = role == 'admin' || role == 'driver';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'canceled':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _getVietnameseStatus(String status) {
    switch (status) {
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'canceled':
        return 'Đã hủy';
      default:
        return 'Chờ duyệt';
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _handleApproval(bool approve) async {
    final note = _notesController.text.trim();
    if (!approve && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do từ chối')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final provider = context.read<ApplicationProvider>();
      if (approve) {
        await provider.approveRequest(widget.applicationId, note.isEmpty ? null : note);
      } else {
        await provider.rejectRequest(widget.applicationId, note);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve ? 'Đã duyệt đơn từ thành công!' : 'Đã từ chối đơn từ!'),
            backgroundColor: approve ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (e is DioException) {
          final serverData = e.response?.data;
          if (serverData is Map && serverData['message'] != null) {
            errMsg = serverData['message'].toString();
          } else if (serverData is Map && serverData['error'] != null) {
            errMsg = serverData['error'].toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thao tác thất bại: $errMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleCancel() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hủy đơn xin bận'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bạn có chắc chắn muốn hủy đơn xin bận này không?'),
              SizedBox(height: 12.h),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do hủy',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy bỏ'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận hủy', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập lý do hủy đơn')),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final provider = context.read<ApplicationProvider>();
      await provider.cancelRequest(widget.applicationId, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy đơn xin bận thành công!'),
            backgroundColor: Color(0xFF64748B),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (e is DioException) {
          final serverData = e.response?.data;
          if (serverData is Map && serverData['message'] != null) {
            errMsg = serverData['message'].toString();
          } else if (serverData is Map && serverData['error'] != null) {
            errMsg = serverData['error'].toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thao tác thất bại: $errMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final provider = context.watch<ApplicationProvider>();
    final item = provider.requests.firstWhere(
      (app) => app.lotTagRequestId == widget.applicationId,
      orElse: () => LotTagRequest(
        lotTagRequestId: widget.applicationId,
        workDate: '',
        lotTagKey: '',
        requestStatus: 'pending',
      ),
    );
    
    final statusColor = _getStatusColor(item.requestStatus);
    final showApprovalActions = _canReview && item.requestStatus == 'pending';
    final showCancelAction = _canCancel && item.requestStatus == 'pending';

    final vehiclePlate = item.vehicle?.vehicleLicensePlate;
    final vehicleName = item.vehicle?.vehicleName;
    final vehicleLabel = [vehiclePlate, vehicleName].where((e) => e != null && e.isNotEmpty).join(' · ');

    final reviewNote = item.reviewNote ?? item.rejectReason;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Chi tiết Đơn',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Driver Profile Header Card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24.r,
                    backgroundColor: const Color(0xFFF1F5F9),
                    child: Icon(Icons.person, color: const Color(0xFF94A3B8), size: 30.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.requestedByUser?.userFullName ?? 'Tài xế #${item.requestedBy ?? ''}',
                          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Mã đơn: #${item.lotTagRequestId}',
                          style: TextStyle(fontSize: 12.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      _getVietnameseStatus(item.requestStatus),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Request details card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin chi tiết đơn',
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                  ),
                  const Divider(height: 24),

                  _buildDetailRow('Lý do bận (Tag)', item.lotTag?.lotTagName ?? item.lotTagKey),
                  if (vehicleLabel.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    _buildDetailRow('Xe đăng ký', vehicleLabel),
                  ],
                  SizedBox(height: 12.h),
                  _buildDetailRow('Ngày đăng ký bận', _formatDate(item.workDate)),
                  if (item.createdAt != null) ...[
                    SizedBox(height: 12.h),
                    _buildDetailRow('Thời gian gửi', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item.createdAt!))),
                  ],
                  
                  const Divider(height: 24),
                  
                  Text(
                    'Lý do chi tiết:',
                    style: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    item.requestReason ?? 'Không có lý do chi tiết',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF1E293B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Manager response section
            if (item.requestStatus != 'pending' && reviewNote != null && reviewNote.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.requestStatus == 'canceled' ? 'Lý do hủy đơn' : 'Phản hồi từ quản lý',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      reviewNote,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF334155),
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],

            // Driver cancel action
            if (showCancelAction) ...[
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _handleCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFF64748B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _isProcessing
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF64748B)),
                        )
                      : const Text('Hủy Đơn Xin Bận', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            // Approval form for managers
            if (showApprovalActions) ...[
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phê duyệt đơn từ',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú phản hồi (nếu từ chối bắt buộc điền)',
                        labelStyle: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B)),
                        alignLabelWithHint: true,
                        hintText: 'Nhập ý kiến phê duyệt hoặc từ chối...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isProcessing ? null : () => _handleApproval(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: const Text('Từ Chối', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isProcessing ? null : () => _handleApproval(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                            ),
                            child: const Text('Duyệt Đơn', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF1E293B), fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
