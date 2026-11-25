import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_history_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/services/vehicle_maintenance_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vehicle_maintenance_form_page_v2.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vm_ui_v2.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/widgets/vehicle_maintenance_discussion_widget_v2.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/widgets/vehicle_maintenance_history_widget_v2.dart';

/// "Phiếu bảo trì" detail (v2). Same constructor, state, permissions, workflow actions, dialogs,
/// navigation and results as `VehicleMaintenanceDetailPage`; only the widget tree is redesigned.
class VehicleMaintenanceDetailPageV2 extends StatefulWidget {
  final int maintenanceId;

  const VehicleMaintenanceDetailPageV2({super.key, required this.maintenanceId});

  @override
  State<VehicleMaintenanceDetailPageV2> createState() => _VehicleMaintenanceDetailPageV2State();
}

class _VehicleMaintenanceDetailPageV2State extends State<VehicleMaintenanceDetailPageV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
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

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

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
    final tone = VmTone.action(action);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: VmDialogTitle(
          icon: VmTone.actionIcon(action),
          tone: tone == FxTokens.slate ? FxTokens.blue : tone,
          title: 'Xác nhận ${_getWorkflowActionLabel(action).toLowerCase()}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Bạn có chắc chắn muốn thực hiện hành động này?'),
            SizedBox(height: 16.h),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: requiresReason ? 'Lý do (bắt buộc)' : 'Ghi chú (tùy chọn)',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tone == FxTokens.red ? FxTokens.red : FxTokens.blue,
              foregroundColor: Colors.white,
            ),
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
      builder: (ctx) => const VmLoadingCard(),
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
        await _service.runWorkflowAction(widget.maintenanceId, action,
            note: note, reason: _actionRequiresReason(action) ? note : null);
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

  Future<void> _openEdit(VehicleMaintenance m) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VehicleMaintenanceFormPageV2(maintenance: m)),
    );
    if (result == true) {
      _fetchDetail();
      _fetchHistory();
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    // First load: skeleton. (A later reload keeps the content on screen with a progress bar.)
    if (_isLoading && _maintenance == null) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: vmAppBar(context, title: 'Chi tiết phiếu bảo trì', subtitle: 'Đang tải…'),
        body: const _DetailSkeleton(),
      );
    }

    if (_maintenance == null) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: vmAppBar(context, title: 'Chi tiết phiếu bảo trì'),
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: FxEmpty(
              icon: Icons.search_off_rounded,
              title: 'Không tìm thấy phiếu',
              message: 'Phiếu có thể đã bị xóa hoặc không tải được.',
              action: FilledButton.tonalIcon(
                onPressed: () {
                  _fetchDetail();
                  _fetchHistory();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
              ),
            ),
          ),
        ),
      );
    }

    final m = _maintenance!;
    final vehicleLabel = m.vehicle != null ? '${m.vehicle!.vehicleLicensePlate} | ${m.vehicle!.vehicleName}' : '#${m.vehicleId}';

    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: m.currency ?? 'VND');
    final isDraftOrRejected = ['draft', 'rejected'].contains(m.vehicleMaintenanceStatus);
    // Same rule as v1: only drafts / rejected tickets can be edited.
    final canEdit = isDraftOrRejected && (_canUpdate || _userRole == 'admin');

    final showDelete = canEdit && (_canDelete || _userRole == 'admin');
    final activeActions = m.workflowAvailableActions != null
        ? m.workflowAvailableActions!.where((a) => a != 'delete' && _canPerformAction(a)).toList()
        : <String>[];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: vmAppBar(
        context,
        title: 'Phiếu bảo trì #${m.vehicleMaintenanceId}',
        subtitle: vehicleLabel,
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Chỉnh sửa',
              onPressed: () => _openEdit(m),
            ),
          SizedBox(width: 4.w),
        ],
      ),
      bottomNavigationBar: (showDelete || activeActions.isNotEmpty)
          ? VmBottomBar(child: _actionBar(t, showDelete, activeActions))
          : null,
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([_fetchDetail(), _fetchHistory()]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(t, m),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _facts(m),
                          _descriptionCard(t, m),
                          _invoiceCard(t, m, formatter),
                          if (m.documents != null && m.documents!.isNotEmpty) _documentsCard(t, m),
                          VehicleMaintenanceHistoryWidgetV2(histories: _histories, isLoading: _isHistoryLoading),
                          // Re-created with every fetched detail, like v1 (which rebuilt it after each reload).
                          VehicleMaintenanceDiscussionWidgetV2(key: ObjectKey(m), maintenanceId: widget.maintenanceId),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Status header band
  Widget _header(FxTokens t, VehicleMaintenance m) {
    final status = m.vehicleMaintenanceStatus;
    final tone = VmTone.status(status);
    final plate = m.vehicle?.vehicleLicensePlate ?? '#${m.vehicleId}';
    final name = m.vehicle?.vehicleName ?? '';
    final rank = m.vehicleMaintenanceRank;

    // Latest rejection note from the history (shown on rejected tickets).
    String? rejectNote;
    if (status == 'rejected') {
      final rejects = _histories.where((h) => h.action.contains('reject') && (h.note?.isNotEmpty ?? false)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (rejects.isNotEmpty) rejectNote = rejects.last.note;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tone.withValues(alpha: t.dark ? 0.28 : 0.13), t.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FxIconBadge(icon: VmTone.typeIcon(m.vehicleMaintenanceType), tone: tone, size: 46),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.h1.copyWith(fontSize: 21.sp, fontFeatures: FxTokens.tabular),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      [if (name.isNotEmpty && name != plate) name, VmTone.typeLabel(m.vehicleMaintenanceType)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.small,
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
              FxPill(label: _getStatusLabel(status), tone: tone, solid: true, icon: VmTone.statusIcon(status)),
              FxPill(label: 'Cấp ${rank ?? 1}', tone: VmTone.rank(rank), icon: Icons.flag_rounded),
              FxPill(
                label: m.paymentStatus == 'paid'
                    ? 'Đã thanh toán'
                    : (m.paymentStatus == 'partial' ? 'Thanh toán 1 phần' : 'Chưa thanh toán'),
                tone: VmTone.payment(m.paymentStatus),
                icon: Icons.payments_outlined,
              ),
              if (m.documents != null && m.documents!.isNotEmpty)
                FxPill(label: '${m.documents!.length} tài liệu', tone: FxTokens.slate, icon: Icons.attach_file_rounded),
            ],
          ),
          SizedBox(height: 14.h),
          if (status == 'rejected' || status == 'canceled')
            FxBanner(
              tone: FxTokens.red,
              icon: status == 'rejected' ? Icons.cancel_outlined : Icons.block_rounded,
              title: status == 'rejected' ? 'Phiếu bị từ chối' : 'Phiếu đã hủy',
              text: rejectNote ??
                  (status == 'rejected'
                      ? 'Chỉnh sửa phiếu theo góp ý rồi gửi lại.'
                      : 'Phiếu không còn được xử lý.'),
            )
          else
            Container(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(FxTokens.rTile),
                border: Border.all(color: t.border.withValues(alpha: 0.7)),
              ),
              child: VmWorkflowSteps(status: status),
            ),
        ],
      ),
    );
  }

  Widget _facts(VehicleMaintenance m) {
    final df = DateFormat('dd/MM/yyyy');
    final km = m.vehicleDistanceCovered;
    return FxGrid(
      columns: 2,
      children: [
        FxInfoTile(
          icon: Icons.event_rounded,
          label: 'Từ ngày',
          value: df.format(m.vehicleMaintenanceFromDatetime.toLocal()),
        ),
        FxInfoTile(
          icon: Icons.event_available_rounded,
          label: 'Đến ngày',
          value: m.vehicleMaintenanceToDatetime != null ? df.format(m.vehicleMaintenanceToDatetime!.toLocal()) : '—',
        ),
        FxInfoTile(
          icon: Icons.speed_rounded,
          label: 'Số KM hiện tại',
          value: km != null ? '${NumberFormat('#,##0', 'vi').format(km)} km' : '—',
        ),
        FxInfoTile(
          icon: Icons.category_outlined,
          label: 'Loại bảo trì',
          value: VmTone.typeLabel(m.vehicleMaintenanceType),
        ),
        FxInfoTile(
          icon: Icons.flag_outlined,
          label: 'Mức độ',
          value: 'Cấp ${m.vehicleMaintenanceRank ?? 1}',
        ),
        FxInfoTile(
          icon: Icons.place_outlined,
          label: 'Địa điểm sửa chữa',
          value: (m.vehicleMaintenanceLocation ?? '').isEmpty ? '—' : m.vehicleMaintenanceLocation!,
        ),
      ],
    );
  }

  Widget _descriptionCard(FxTokens t, VehicleMaintenance m) {
    final desc = m.vehicleMaintenanceDescription ?? '';
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxSectionHeader(icon: Icons.handyman_outlined, title: 'Mô tả công việc', tone: FxTokens.amber),
          Text(
            desc.isEmpty ? 'Chưa có mô tả công việc.' : desc,
            style: desc.isEmpty ? t.small.copyWith(color: t.textFaint) : t.body,
          ),
        ],
      ),
    );
  }

  Widget _invoiceCard(FxTokens t, VehicleMaintenance m, NumberFormat formatter) {
    final df = DateFormat('dd/MM/yyyy');
    final rows = <VmKeyValue>[
      VmKeyValue(label: 'Đơn vị sửa chữa', value: m.serviceProviderName ?? ''),
      if ((m.serviceProviderAddress ?? '').isNotEmpty) VmKeyValue(label: 'Địa chỉ đơn vị', value: m.serviceProviderAddress!),
      VmKeyValue(label: 'Số hóa đơn', value: m.invoiceNo ?? ''),
      VmKeyValue(label: 'Ngày hóa đơn', value: m.invoiceDate != null ? df.format(m.invoiceDate!.toLocal()) : ''),
      if (m.deadlinePay != null) VmKeyValue(label: 'Hạn thanh toán', value: df.format(m.deadlinePay!.toLocal())),
      VmKeyValue(
        label: 'Trạng thái thanh toán',
        value: '',
        trailing: FxPill(
          label: m.paymentStatus == 'paid'
              ? 'Đã thanh toán'
              : (m.paymentStatus == 'partial' ? 'Thanh toán 1 phần' : 'Chưa thanh toán'),
          tone: VmTone.payment(m.paymentStatus),
          dot: true,
        ),
        last: true,
      ),
    ];

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxSectionHeader(icon: Icons.receipt_long_outlined, title: 'Hóa đơn & Thanh toán', tone: FxTokens.emerald),
          // Total amount highlight
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: t.cardAlt,
              borderRadius: BorderRadius.circular(FxTokens.rTile),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                Expanded(child: Text('TỔNG TIỀN', style: t.overline)),
                Flexible(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      m.totalAmount != null ? formatter.format(m.totalAmount) : '—',
                      style: t.num(19.sp, color: m.totalAmount != null ? t.ink(FxTokens.emerald) : t.textFaint),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          ...rows,
        ],
      ),
    );
  }

  Widget _documentsCard(FxTokens t, VehicleMaintenance m) {
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.attach_file_rounded,
            title: 'Tài liệu đính kèm',
            subtitle: '${m.documents!.length} tệp',
            tone: FxTokens.cyan,
          ),
          for (var i = 0; i < m.documents!.length; i++) ...[
            if (i > 0) SizedBox(height: 8.h),
            Builder(builder: (context) {
              final doc = m.documents![i];
              void open() {
                final mediaUrl = doc.media is Map ? doc.media['media_url'] : null;
                if (mediaUrl != null) {
                  launchUrl(Uri.parse(mediaUrl));
                }
              }

              return Material(
                color: t.cardAlt,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r), side: BorderSide(color: t.border)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: open,
                  child: Padding(
                    padding: EdgeInsets.all(10.w),
                    child: Row(
                      children: [
                        const FxIconBadge(icon: Icons.insert_drive_file_outlined, tone: FxTokens.blue, size: 36),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(doc.media is Map ? doc.media['media_name'] : null) ?? 'Tài liệu #${doc.vehicleMaintenanceDocumentId}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.h3,
                              ),
                              if (doc.documentType.isNotEmpty) ...[
                                SizedBox(height: 2.h),
                                Text(doc.documentType, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.open_in_new_rounded, size: 19.sp, color: t.ink(FxTokens.blue)),
                          onPressed: open,
                          tooltip: 'Mở tài liệu',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // Sticky action bar: delete (draft / rejected) + the workflow actions the user may run.
  Widget _actionBar(FxTokens t, bool showDelete, List<String> activeActions) {
    final busy = _isLoading;
    final compactDelete = showDelete && activeActions.isNotEmpty;

    Widget deleteButton() => compactDelete
        ? SizedBox(
            width: 48.w,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size(48.w, 46),
                foregroundColor: t.ink(FxTokens.red),
                side: BorderSide(color: FxTokens.red.withValues(alpha: 0.5)),
              ),
              onPressed: busy ? null : () => _showWorkflowDialog('delete'),
              child: Icon(Icons.delete_outline_rounded, size: 20.sp),
            ),
          )
        : Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: t.ink(FxTokens.red),
                side: BorderSide(color: FxTokens.red.withValues(alpha: 0.5)),
              ),
              onPressed: busy ? null : () => _showWorkflowDialog('delete'),
              icon: Icon(Icons.delete_outline_rounded, size: 20.sp),
              label: const Text('Xóa'),
            ),
          );

    return Row(
      children: [
        if (showDelete) deleteButton(),
        for (var i = 0; i < activeActions.length; i++)
          Builder(builder: (context) {
            final action = activeActions[i];
            final isDanger = action.contains('reject');
            IconData iconData = Icons.check_circle_outline_rounded;
            if (isDanger) iconData = Icons.cancel_outlined;
            if (action == 'submit') iconData = Icons.send_rounded;
            final gap = (i == 0 && !showDelete) ? 0.0 : 10.w;

            final label = Text(
              _getWorkflowActionLabel(action),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: gap),
                child: isDanger
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: t.ink(FxTokens.red),
                          side: BorderSide(color: FxTokens.red.withValues(alpha: 0.5)),
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                        ),
                        onPressed: busy ? null : () => _showWorkflowDialog(action),
                        icon: Icon(iconData, size: 19.sp),
                        label: label,
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: action.contains('approve') ? FxTokens.emerald : FxTokens.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                        ),
                        onPressed: busy ? null : () => _showWorkflowDialog(action),
                        icon: Icon(iconData, size: 19.sp),
                        label: label,
                      ),
              ),
            );
          }),
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
          FxSkeleton(height: 46.w, width: 46.w, radius: 15),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FxSkeleton(height: 20.h, width: 150.w, radius: 8),
              SizedBox(height: 6.h),
              FxSkeleton(height: 12.h, width: 110.w, radius: 6),
            ]),
          ),
        ]),
        SizedBox(height: 14.h),
        FxSkeleton(height: 22.h, width: 220.w, radius: 11),
        SizedBox(height: 14.h),
        FxSkeleton(height: 62.h, radius: 14),
        SizedBox(height: 14.h),
        for (var r = 0; r < 3; r++) ...[
          Row(children: [
            Expanded(child: FxSkeleton(height: 58.h)),
            SizedBox(width: 10.w),
            Expanded(child: FxSkeleton(height: 58.h)),
          ]),
          SizedBox(height: 10.h),
        ],
        SizedBox(height: 4.h),
        FxSkeleton(height: 110.h, radius: 18),
        SizedBox(height: 12.h),
        FxSkeleton(height: 200.h, radius: 18),
      ],
    );
  }
}
