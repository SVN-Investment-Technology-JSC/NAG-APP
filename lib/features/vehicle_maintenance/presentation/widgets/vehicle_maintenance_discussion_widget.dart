import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/auth/data/services/auth_storage_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_comment_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/services/multi_service.dart';

class VehicleMaintenanceDiscussionWidget extends StatefulWidget {
  final int maintenanceId;

  const VehicleMaintenanceDiscussionWidget({
    super.key,
    required this.maintenanceId,
  });

  @override
  State<VehicleMaintenanceDiscussionWidget> createState() => _VehicleMaintenanceDiscussionWidgetState();
}

class _VehicleMaintenanceDiscussionWidgetState extends State<VehicleMaintenanceDiscussionWidget> {
  final _service = MultiService(ApiClient.dio);
  final _controller = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  List<VehicleMaintenanceComment> _comments = [];
  int? _multiId;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
    _fetchComments();
  }

  Future<void> _fetchCurrentUser() async {
    final authStorage = AuthStorageService();
    final userId = await authStorage.getUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }
  }

  Future<void> _fetchComments() async {
    setState(() => _isLoading = true);
    try {
      final result = await _service.getVehicleMaintenanceDiscussComments(widget.maintenanceId);
      if (mounted) {
        setState(() {
          _comments = result?['comments'] as List<VehicleMaintenanceComment>? ?? [];
          _multiId = result?['multiId'] as int?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _createCommentId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${(1000 + (DateTime.now().microsecond % 9000))}';
  }

  Future<void> _handleSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final authStorage = AuthStorageService();
    final userId = await authStorage.getUserId();
    final userFullName = await authStorage.getUserFullName();
    
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn chưa đăng nhập')));
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final newComment = VehicleMaintenanceComment(
        id: _createCommentId(),
        userId: userId,
        userName: userFullName ?? 'User',
        content: text,
        createdAt: DateTime.now(),
      );

      final nextComments = [..._comments, newComment];
      final newMultiId = await _service.saveVehicleMaintenanceDiscussComments(
        widget.maintenanceId,
        nextComments,
        _multiId,
      );

      if (mounted) {
        setState(() {
          _comments = nextComments;
          if (newMultiId != null) {
            _multiId = newMultiId;
          }
        });
        _controller.clear();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi gửi bình luận')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleDelete(String commentId) async {
    setState(() => _isSubmitting = true);
    try {
      final nextComments = _comments.where((c) => c.id != commentId && c.parentId != commentId).toList();
      await _service.saveVehicleMaintenanceDiscussComments(
        widget.maintenanceId,
        nextComments,
        _multiId,
      );
      if (mounted) {
        setState(() {
          _comments = nextComments;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bình luận')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi xóa bình luận')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'U';
    return parts.last[0].toUpperCase();
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes < 0 ? 0 : diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return '${diff.inDays} ngày';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // We can't synchronously get user here in build, but we don't strictly need it to display comments.
    // If we want to check ownership, we should fetch userId in initState.

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      'Thảo luận chung',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _isLoading ? null : _fetchComments,
                  tooltip: 'Tải lại',
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Trao đổi công khai giữa các thành viên liên quan đến phiếu bảo trì.',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey),
            ),
            SizedBox(height: AppSpacing.mdH),
            
            // Input
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  radius: 18.r,
                  child: Icon(Icons.person, color: Colors.grey.shade600, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _controller,
                          enabled: !_isSubmitting,
                          decoration: InputDecoration(
                            hintText: 'Viết bình luận công khai...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          maxLines: null,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        icon: _isSubmitting 
                          ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, size: 16),
                        label: const Text('Gửi'),
                      )
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.mdH),

            // Comments List
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_comments.isEmpty)
              Padding(
                padding: EdgeInsets.all(32.h),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48.sp, color: Colors.grey.shade300),
                      SizedBox(height: 8.h),
                      Text('Chưa có thảo luận nào', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final sortedComments = List<VehicleMaintenanceComment>.from(_comments)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedComments.length,
                    separatorBuilder: (_, __) => SizedBox(height: 16.h),
                    itemBuilder: (context, index) {
                      final comment = sortedComments[index];
                      // The actual owner check needs async ID, defaulting to false to hide delete button if not fetched
                      final isOwner = _currentUserId == comment.userId;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: isOwner ? Colors.blue : Colors.green,
                        radius: 16.r,
                        child: Text(
                          _getInitials(comment.userName),
                          style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.userName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    comment.content,
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Text(
                                  _formatRelativeTime(comment.createdAt),
                                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                                ),
                                if (isOwner) ...[
                                  SizedBox(width: 16.w),
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Xóa bình luận'),
                                          content: const Text('Bạn có chắc muốn xóa bình luận này?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _handleDelete(comment.id);
                                              },
                                              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Xóa',
                                      style: TextStyle(fontSize: 12.sp, color: Colors.red.shade400, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ]
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ); // closes ListView.separated
            },
          ), // closes Builder
          ],
        ),
      ),
    );
  }
}
