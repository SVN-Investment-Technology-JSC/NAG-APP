import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/auth/data/services/auth_storage_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_comment_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/services/multi_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vm_ui_v2.dart';

/// "Thảo luận chung" (v2). Same constructor, state, loading, posting and deleting as
/// `VehicleMaintenanceDiscussionWidget`; comments are shown as chat bubbles.
class VehicleMaintenanceDiscussionWidgetV2 extends StatefulWidget {
  final int maintenanceId;

  const VehicleMaintenanceDiscussionWidgetV2({
    super.key,
    required this.maintenanceId,
  });

  @override
  State<VehicleMaintenanceDiscussionWidgetV2> createState() => _VehicleMaintenanceDiscussionWidgetV2State();
}

class _VehicleMaintenanceDiscussionWidgetV2State extends State<VehicleMaintenanceDiscussionWidgetV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
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

  // v2: the v1 widget never disposed its controller.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

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
    // v2 fix: v1 threw a RangeError for an empty / blank user name (''.split → [''] → ''[0]).
    if (parts.isEmpty || parts.last.isEmpty) return 'U';
    return parts.last[0].toUpperCase();
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes < 0 ? 0 : diff.inMinutes} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return '${diff.inDays} ngày';
  }

  void _confirmDelete(VehicleMaintenanceComment comment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const VmDialogTitle(icon: Icons.delete_outline_rounded, tone: FxTokens.red, title: 'Xóa bình luận'),
        content: const Text('Bạn có chắc muốn xóa bình luận này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FxTokens.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _handleDelete(comment.id);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
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
            icon: Icons.forum_outlined,
            title: 'Thảo luận chung',
            subtitle: 'Trao đổi công khai giữa các thành viên liên quan đến phiếu bảo trì.',
            tone: FxTokens.violet,
            trailing: IconButton(
              icon: Icon(Icons.refresh_rounded, size: 20.sp),
              color: t.textMuted,
              onPressed: _isLoading ? null : _fetchComments,
              tooltip: 'Tải lại',
              visualDensity: VisualDensity.compact,
            ),
          ),

          // Comments
          if (_isLoading)
            ..._skeleton()
          else if (_comments.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(14.r)),
              child: const FxEmpty(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chưa có thảo luận nào',
                message: 'Hãy là người đầu tiên trao đổi về phiếu này.',
              ),
            )
          else
            Builder(builder: (context) {
              // Oldest first, like a chat thread (the composer sits underneath).
              final sorted = List<VehicleMaintenanceComment>.from(_comments)
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in sorted) _bubble(t, c),
                ],
              );
            }),

          SizedBox(height: 12.h),
          _composer(t),
        ],
      ),
    );
  }

  List<Widget> _skeleton() => [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Row(
              mainAxisAlignment: i.isOdd ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (i.isEven) ...[FxSkeleton(height: 30.w, width: 30.w, radius: 15), SizedBox(width: 8.w)],
                FxSkeleton(height: 46.h, width: (i.isOdd ? 170 : 210).w, radius: 16),
              ],
            ),
          ),
      ];

  Widget _bubble(FxTokens t, VehicleMaintenanceComment comment) {
    // Same ownership rule as v1 (delete only on own comments once the user id is known).
    final isOwner = _currentUserId == comment.userId;
    final time = '${_formatRelativeTime(comment.createdAt)} · ${DateFormat('dd/MM HH:mm').format(comment.createdAt.toLocal())}';
    final radius = Radius.circular(16.r);

    final bubble = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: isOwner ? FxTokens.blue : t.cardAlt,
        border: isOwner ? null : Border.all(color: t.border),
        borderRadius: BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: isOwner ? radius : Radius.circular(4.r),
          bottomRight: isOwner ? Radius.circular(4.r) : radius,
        ),
      ),
      child: Text(
        comment.content,
        style: TextStyle(fontSize: 13.5.sp, height: 1.4, color: isOwner ? Colors.white : t.text),
      ),
    );

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.tiny.copyWith(fontFeatures: FxTokens.tabular, color: t.textFaint),
          ),
        ),
        if (isOwner) ...[
          SizedBox(width: 10.w),
          InkWell(
            borderRadius: BorderRadius.circular(6.r),
            onTap: _isSubmitting ? null : () => _confirmDelete(comment),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Text(
                'Xóa',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: t.ink(FxTokens.red)),
              ),
            ),
          ),
        ],
      ],
    );

    if (isOwner) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h, left: 48.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            bubble,
            SizedBox(height: 4.h),
            meta,
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, right: 36.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(color: t.soft(FxTokens.emerald), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              _getInitials(comment.userName),
              style: TextStyle(color: t.ink(FxTokens.emerald), fontSize: 12.sp, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 2.w, bottom: 3.h),
                  child: Text(
                    comment.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: t.textMuted),
                  ),
                ),
                bubble,
                SizedBox(height: 4.h),
                meta,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(FxTokens t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextFormField(
            controller: _controller,
            enabled: !_isSubmitting,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: t.body,
            decoration: InputDecoration(
              hintText: 'Viết bình luận công khai...',
              hintStyle: t.small,
              prefixIcon: Icon(Icons.chat_outlined, size: 18.sp, color: t.textFaint),
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22.r), borderSide: BorderSide(color: t.border)),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(22.r), borderSide: BorderSide(color: t.border)),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22.r),
                borderSide: BorderSide(color: t.border.withValues(alpha: 0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22.r),
                borderSide: const BorderSide(color: FxTokens.blue, width: 1.4),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 44.w,
          height: 44.w,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size(44.w, 44.w),
              shape: const CircleBorder(),
              backgroundColor: FxTokens.blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: FxTokens.blue.withValues(alpha: 0.5),
            ),
            child: _isSubmitting ? const VmButtonSpinner() : Icon(Icons.send_rounded, size: 18.sp),
          ),
        ),
      ],
    );
  }
}
