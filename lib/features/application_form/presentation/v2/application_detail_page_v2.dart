import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/application_form/data/models/application_model.dart';
import 'package:nguyenanh/features/application_form/presentation/application_provider.dart';
import 'package:nguyenanh/features/application_form/presentation/v2/af_ui_v2.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

/// "Chi tiết đơn" (v2). Same constructor, state, permissions, approve / reject / cancel flows,
/// provider calls and returned result (`true`) as `ApplicationDetailPage`; new layout with a
/// status header, fact tiles and a sticky action bar.
class ApplicationDetailPageV2 extends StatefulWidget {
  final int applicationId;
  const ApplicationDetailPageV2({super.key, required this.applicationId});

  @override
  State<ApplicationDetailPageV2> createState() => _ApplicationDetailPageV2State();
}

class _ApplicationDetailPageV2State extends State<ApplicationDetailPageV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  // ignore: unused_field
  String _userRole = ''; // kept from v1 (assigned, never read there either)
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

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

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
          _canCancel =
              role == 'admin' || role == 'driver' || myPerms.contains('/work-arrangements/lot-tag-requests__cancel');
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

  /// v2 fix: v1 called `DateTime.parse(item.createdAt!)` inside build, which threw (red screen) on a
  /// malformed timestamp. Same output for valid values; falls back to the raw string otherwise.
  String _formatDateTime(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
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
            backgroundColor: approve ? FxTokens.emerald : FxTokens.red,
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
            backgroundColor: FxTokens.red,
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
          scrollable: true,
          title: const AfDialogTitle(icon: Icons.block_rounded, tone: FxTokens.red, title: 'Hủy đơn xin bận'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Bạn có chắc chắn muốn hủy đơn xin bận này không?'),
              SizedBox(height: 14.h),
              TextField(
                controller: reasonController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Lý do hủy',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy bỏ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: FxTokens.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận hủy'),
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

    // v2 safety: the page may have been closed while the dialog was open.
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      final provider = context.read<ApplicationProvider>();
      await provider.cancelRequest(widget.applicationId, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy đơn xin bận thành công!'),
            backgroundColor: FxTokens.slate,
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
            backgroundColor: FxTokens.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: afAppBar(context, title: 'Chi tiết đơn', subtitle: 'Mã đơn: #${widget.applicationId}'),
        body: const _DetailSkeleton(),
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

    final showApprovalActions = _canReview && item.requestStatus == 'pending';
    final showCancelAction = _canCancel && item.requestStatus == 'pending';

    final vehiclePlate = item.vehicle?.vehicleLicensePlate;
    final vehicleName = item.vehicle?.vehicleName;
    final vehicleLabel = [vehiclePlate, vehicleName].where((e) => e != null && e.isNotEmpty).join(' · ');

    final reviewNote = item.reviewNote ?? item.rejectReason;
    final tagLabel = item.lotTag?.lotTagName ?? item.lotTagKey;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: afAppBar(context, title: 'Chi tiết đơn', subtitle: 'Đơn xin bận · ${_getVietnameseStatus(item.requestStatus)}'),
      bottomNavigationBar: (showApprovalActions || showCancelAction)
          ? AfBottomBar(child: _actionBar(t, showApprovalActions, showCancelAction))
          : null,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(t, item, tagLabel),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FxGrid(
                    columns: 2,
                    children: [
                      FxInfoTile(icon: Icons.label_outline_rounded, label: 'Lý do bận (Tag)', value: tagLabel.isEmpty ? '—' : tagLabel),
                      FxInfoTile(
                        icon: Icons.event_rounded,
                        label: 'Ngày đăng ký bận',
                        value: item.workDate.isEmpty ? '—' : _formatDate(item.workDate),
                      ),
                      if (vehicleLabel.isNotEmpty)
                        FxInfoTile(icon: Icons.local_shipping_outlined, label: 'Xe đăng ký', value: vehicleLabel),
                      if (item.createdAt != null)
                        FxInfoTile(icon: Icons.schedule_send_outlined, label: 'Thời gian gửi', value: _formatDateTime(item.createdAt!)),
                    ],
                  ),

                  // Request reason
                  FxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FxSectionHeader(icon: Icons.notes_rounded, title: 'Lý do chi tiết', tone: FxTokens.blue),
                        Text(
                          item.requestReason ?? 'Không có lý do chi tiết',
                          style: item.requestReason == null ? t.small.copyWith(color: t.textFaint) : t.body,
                        ),
                      ],
                    ),
                  ),

                  // Manager response
                  if (item.requestStatus != 'pending' && reviewNote != null && reviewNote.isNotEmpty)
                    _responseCard(t, item, reviewNote),

                  // Approval note for managers (buttons live in the sticky bar)
                  if (showApprovalActions)
                    FxCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FxSectionHeader(
                            icon: Icons.rate_review_outlined,
                            title: 'Phê duyệt đơn từ',
                            subtitle: 'Nhập ghi chú rồi chọn Duyệt hoặc Từ chối bên dưới',
                            tone: FxTokens.emerald,
                          ),
                          Padding(
                            padding: EdgeInsets.only(left: 2.w, bottom: 6.h),
                            child: Text(
                              'Ghi chú phản hồi (nếu từ chối bắt buộc điền)',
                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: t.textMuted),
                            ),
                          ),
                          TextField(
                            controller: _notesController,
                            maxLines: 3,
                            enabled: !_isProcessing,
                            textCapitalization: TextCapitalization.sentences,
                            style: t.body,
                            decoration: const InputDecoration(
                              alignLabelWithHint: true,
                              hintText: 'Nhập ý kiến phê duyệt hoặc từ chối...',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(FxTokens t, LotTagRequest item, String tagLabel) {
    final tone = AfTone.status(item.requestStatus);
    final name = item.requestedByUser?.userFullName ?? 'Tài xế #${item.requestedBy ?? ''}';
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 18.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tone.withValues(alpha: t.dark ? 0.28 : 0.13), t.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AfAvatar(name: item.requestedByUser?.userFullName, tone: tone, size: 48),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.h1.copyWith(fontSize: 20.sp)),
                    SizedBox(height: 3.h),
                    Text(
                      'Mã đơn: #${item.lotTagRequestId}',
                      style: t.small.copyWith(fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              FxPill(
                label: _getVietnameseStatus(item.requestStatus),
                tone: tone,
                solid: true,
                icon: AfTone.statusIcon(item.requestStatus),
              ),
              if (tagLabel.isNotEmpty) FxPill(label: tagLabel.toUpperCase(), tone: FxTokens.indigo, icon: Icons.label_outline_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _responseCard(FxTokens t, LotTagRequest item, String reviewNote) {
    final canceled = item.requestStatus == 'canceled';
    final tone = AfTone.status(item.requestStatus);
    final reviewer = item.reviewedByUser?.userFullName;
    final reviewedAt = item.reviewedAt != null ? _formatDateTime(item.reviewedAt!) : null;
    final meta = [if (reviewer != null && reviewer.isNotEmpty) reviewer, ?reviewedAt].join(' · ');

    return FxCard(
      borderColor: tone.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: canceled ? Icons.block_rounded : Icons.support_agent_rounded,
            title: canceled ? 'Lý do hủy đơn' : 'Phản hồi từ quản lý',
            subtitle: meta.isEmpty ? null : meta,
            tone: tone,
          ),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(color: t.soft(tone), borderRadius: BorderRadius.circular(12.r)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, size: 16.sp, color: t.ink(tone)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    reviewNote,
                    style: TextStyle(fontSize: 13.sp, color: t.text, fontStyle: FontStyle.italic, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(FxTokens t, bool showApprovalActions, bool showCancelAction) {
    final cancelButton = OutlinedButton.icon(
      onPressed: _isProcessing ? null : _handleCancel,
      style: OutlinedButton.styleFrom(foregroundColor: t.textMuted, side: BorderSide(color: t.border)),
      icon: _isProcessing ? AfSpinner(color: t.textMuted) : Icon(Icons.block_rounded, size: 18.sp),
      label: const Text('Hủy Đơn Xin Bận'),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCancelAction && !showApprovalActions) SizedBox(height: 48.h, child: cancelButton),
        if (showApprovalActions)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : () => _handleApproval(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.ink(FxTokens.red),
                      side: BorderSide(color: FxTokens.red.withValues(alpha: 0.5)),
                    ),
                    icon: Icon(Icons.close_rounded, size: 19.sp),
                    label: const Text('Từ Chối'),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: FilledButton.icon(
                    onPressed: _isProcessing ? null : () => _handleApproval(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: FxTokens.emerald,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: FxTokens.emerald.withValues(alpha: 0.5),
                      disabledForegroundColor: Colors.white,
                    ),
                    icon: _isProcessing ? const AfSpinner() : Icon(Icons.check_rounded, size: 19.sp),
                    label: const Text('Duyệt Đơn'),
                  ),
                ),
              ),
            ],
          ),
        // Admins can both review and cancel: cancel becomes a secondary text action under the review buttons.
        if (showCancelAction && showApprovalActions) ...[
          SizedBox(height: 4.h),
          TextButton.icon(
            onPressed: _isProcessing ? null : _handleCancel,
            style: TextButton.styleFrom(foregroundColor: t.textMuted, minimumSize: Size(0, 36.h)),
            icon: Icon(Icons.block_rounded, size: 16.sp),
            label: const Text('Hủy Đơn Xin Bận'),
          ),
        ],
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16.w),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(children: [
          FxSkeleton(height: 48.w, width: 48.w, radius: 24),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FxSkeleton(height: 20.h, width: 170.w, radius: 8),
              SizedBox(height: 6.h),
              FxSkeleton(height: 12.h, width: 90.w, radius: 6),
            ]),
          ),
        ]),
        SizedBox(height: 14.h),
        FxSkeleton(height: 22.h, width: 180.w, radius: 11),
        SizedBox(height: 18.h),
        for (var r = 0; r < 2; r++) ...[
          Row(children: [
            Expanded(child: FxSkeleton(height: 58.h)),
            SizedBox(width: 10.w),
            Expanded(child: FxSkeleton(height: 58.h)),
          ]),
          SizedBox(height: 10.h),
        ],
        SizedBox(height: 4.h),
        FxSkeleton(height: 110.h, radius: 18),
      ],
    );
  }
}
