import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/services/vehicle_maintenance_service.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vehicle_maintenance_detail_page_v2.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vehicle_maintenance_form_page_v2.dart';
import 'package:nguyenanh/features/vehicle_maintenance/presentation/v2/vm_ui_v2.dart';

/// "Bảo trì & Bảo dưỡng xe" list (v2). Same constructor, state, filters, search debounce, sort,
/// permissions, swipe actions, delete flow and navigation as `VehicleMaintenanceListPage`.
class VehicleMaintenanceListPageV2 extends StatefulWidget {
  const VehicleMaintenanceListPageV2({super.key});

  @override
  State<VehicleMaintenanceListPageV2> createState() => _VehicleMaintenanceListPageV2State();
}

class _VehicleMaintenanceListPageV2State extends State<VehicleMaintenanceListPageV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  final VehicleMaintenanceService _service = VehicleMaintenanceService(ApiClient.dio);

  List<VehicleMaintenance> _items = [];
  bool _isLoading = true;
  String? _error;
  String? _searchQuery;
  String _sortBy = '-created_at';
  String _currentTab = 'all';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final List<Map<String, String>> _tabs = [
    {'value': 'all', 'label': 'Tất cả'},
    {'value': 'mine', 'label': 'Của tôi'},
    {'value': 'submitted', 'label': 'Chờ kiểm tra'},
    {'value': 'reviewing', 'label': 'Chờ phê duyệt'},
    {'value': 'approved', 'label': 'Đã duyệt'},
    {'value': 'rejected', 'label': 'Từ chối'},
  ];
  final UserManageService _userManageService = UserManageService();
  String _userRole = '';
  bool _canCreate = false;
  bool _canUpdate = false;
  bool _canDelete = false;

  // Same sort options as the v1 popup menu.
  static const _sortOptions = <(String, String)>[
    ('-created_at', 'Mới nhất'),
    ('created_at', 'Cũ nhất'),
    ('-vehicle_maintenance_from_datetime', 'Ngày bảo trì (Mới -> Cũ)'),
    ('vehicle_maintenance_from_datetime', 'Ngày bảo trì (Cũ -> Mới)'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadData();
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
          _canCreate = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__create');
          _canUpdate = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__update');
          _canDelete = _userRole == 'admin' || myPerms.contains('/vehicle-maintenances__delete');
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? status;
      bool mine = false;
      if (_currentTab == 'mine') {
        mine = true;
      } else if (_currentTab != 'all') {
        status = _currentTab;
      }

      final items = await _service.getVehicleMaintenances(
        limit: 50,
        search: _searchQuery,
        sort: _sortBy,
        status: status,
        mine: mine,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'draft':
        return 'Nháp';
      case 'submitted':
        return 'Đã gửi';
      case 'reviewing':
        return 'Đang duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'completed':
        return 'Hoàn tất';
      case 'canceled':
        return 'Đã hủy';
      default:
        return status ?? 'Nháp';
    }
  }

  Future<void> _deleteMaintenance(int id) async {
    try {
      final success = await _service.delete(id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa phiếu bảo trì')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xóa thất bại: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmDialog(VehicleMaintenance item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const VmDialogTitle(icon: Icons.delete_outline_rounded, tone: FxTokens.red, title: 'Xóa phiếu bảo trì?'),
        content: const Text('Phiếu bảo trì và tài liệu liên quan sẽ được xóa mềm. Bạn có chắc chắn muốn xóa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FxTokens.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMaintenance(item.vehicleMaintenanceId);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  String _getRankLabel(int? rank) {
    switch (rank) {
      case 1:
        return 'Thấp';
      case 2:
        return 'Trung bình';
      case 3:
        return 'Cao';
      case 4:
        return 'Khẩn cấp';
      default:
        return 'Không xác định';
    }
  }

  String _getPaymentStatusLabel(String? status) {
    switch (status) {
      case 'unpaid':
        return 'Chưa thanh toán';
      case 'partial':
        return 'Thanh toán 1 phần';
      case 'paid':
        return 'Đã thanh toán';
      default:
        return 'Chưa thanh toán';
    }
  }

  // Navigation (same targets & result handling as v1, pointing at the v2 pages).
  Future<void> _openDetail(VehicleMaintenance item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VehicleMaintenanceDetailPageV2(maintenanceId: item.vehicleMaintenanceId)),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _openEdit(VehicleMaintenance item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VehicleMaintenanceFormPageV2(maintenance: item)),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _openCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VehicleMaintenanceFormPageV2()),
    );
    if (result == true) {
      _loadData();
    }
  }

  // Search handlers (verbatim v1 behaviour: 500 ms debounce, submit, clear).
  void _onSearchChanged(String val) {
    setState(() {});
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = val);
      _loadData();
    });
  }

  void _onSearchSubmitted(String val) {
    setState(() => _searchQuery = val);
    _loadData();
  }

  void _onSearchCleared() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _loadData();
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final tabLabel = _tabs.firstWhere((e) => e['value'] == _currentTab, orElse: () => _tabs.first)['label']!;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: vmAppBar(
        context,
        title: 'Bảo trì & Bảo dưỡng xe',
        subtitle: _isLoading && _items.isEmpty ? 'Đang tải…' : '${_items.length} phiếu · $tabLabel',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
            onPressed: _loadData,
          ),
          SizedBox(width: 4.w),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo phiếu', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 10.h),
            child: Row(
              children: [
                Expanded(child: _searchField(t)),
                SizedBox(width: 8.w),
                _sortButton(t),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: VmFilterTrack<String>(
              items: [
                for (final tab in _tabs)
                  VmFilterItem(
                    tab['value']!,
                    tab['label']!,
                    icon: tab['value'] == 'all'
                        ? Icons.apps_rounded
                        : (tab['value'] == 'mine' ? Icons.person_outline_rounded : null),
                    dot: (tab['value'] == 'all' || tab['value'] == 'mine') ? null : VmTone.status(tab['value']),
                  ),
              ],
              value: _currentTab,
              count: _isLoading ? null : _items.length,
              onChanged: (v) {
                if (v == _currentTab) return;
                setState(() => _currentTab = v);
                _loadData();
              },
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 2,
            child: (_isLoading && _items.isNotEmpty) ? const LinearProgressIndicator(minHeight: 2) : null,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildBody(t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(FxTokens t) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: c, width: w));
    return TextField(
      controller: _searchController,
      style: t.body,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm kiếm phương tiện...',
        hintStyle: t.small,
        prefixIcon: Icon(Icons.search_rounded, color: t.textFaint, size: 20.sp),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, size: 18.sp, color: t.textMuted),
                onPressed: _onSearchCleared,
              )
            : null,
        filled: true,
        fillColor: t.card,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
        border: border(t.border),
        enabledBorder: border(t.border),
        focusedBorder: border(FxTokens.blue, 1.4),
      ),
      onChanged: _onSearchChanged,
      onSubmitted: _onSearchSubmitted,
    );
  }

  Widget _sortButton(FxTokens t) {
    final isDefault = _sortBy == '-created_at';
    return Material(
      color: t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: isDefault ? t.border : FxTokens.blue.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<String>(
        tooltip: 'Sắp xếp',
        initialValue: _sortBy,
        onSelected: (val) {
          setState(() => _sortBy = val);
          _loadData();
        },
        itemBuilder: (context) => [
          for (final o in _sortOptions)
            PopupMenuItem(
              value: o.$1,
              child: Row(
                children: [
                  Icon(
                    o.$1 == _sortBy ? Icons.check_rounded : Icons.sort_rounded,
                    size: 18.sp,
                    color: o.$1 == _sortBy ? t.ink(FxTokens.blue) : t.textFaint,
                  ),
                  SizedBox(width: 10.w),
                  Flexible(child: Text(o.$2)),
                ],
              ),
            ),
        ],
        child: SizedBox(
          width: 44.w,
          height: 42.h,
          child: Icon(Icons.sort_rounded, size: 20.sp, color: isDefault ? t.textMuted : t.ink(FxTokens.blue)),
        ),
      ),
    );
  }

  Widget _buildBody(FxTokens t) {
    if (_isLoading && _items.isEmpty) {
      return const _ListSkeleton();
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 60.h),
          FxEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Lỗi tải dữ liệu',
            message: _error,
            action: FilledButton.tonalIcon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      final filtered = _currentTab != 'all' || (_searchQuery?.isNotEmpty ?? false);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 60.h),
          FxEmpty(
            icon: Icons.car_repair_outlined,
            title: 'Không có dữ liệu',
            message: filtered ? 'Thử đổi bộ lọc hoặc từ khóa tìm kiếm.' : 'Chưa có phiếu bảo trì nào.',
          ),
        ],
      );
    }

    final sortLabel = _sortOptions.firstWhere((o) => o.$1 == _sortBy, orElse: () => _sortOptions.first).$2;

    return SlidableAutoCloseBehavior(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, _canCreate ? 96.h : 24.h),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${_items.length} PHIẾU', style: t.overline.copyWith(fontFeatures: FxTokens.tabular)),
                  ),
                  Icon(Icons.sort_rounded, size: 13.sp, color: t.textFaint),
                  SizedBox(width: 4.w),
                  Text(sortLabel, maxLines: 1, style: t.tiny.copyWith(color: t.textFaint)),
                ],
              ),
            );
          }
          return _buildCard(context, t, _items[index - 1]);
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, FxTokens t, VehicleMaintenance item) {
    final vehicleLabel = item.vehicle?.vehicleLicensePlate ?? '#${item.vehicleId}';
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final fromDate = formatter.format(item.vehicleMaintenanceFromDatetime);
    final status = item.vehicleMaintenanceStatus;
    final tone = VmTone.status(status);
    final vehicleName = item.vehicle?.vehicleName ?? '';
    final location = item.vehicleMaintenanceLocation ?? '';
    final docs = item.documents?.length ?? 0;

    final actions = <Widget>[
      SlidableAction(
        onPressed: (_) => _openDetail(item),
        backgroundColor: t.soft(FxTokens.blue),
        foregroundColor: t.ink(FxTokens.blue),
        icon: Icons.info_outline_rounded,
        label: 'Chi tiết',
      ),
      if (_canUpdate)
        SlidableAction(
          onPressed: (_) => _openEdit(item),
          backgroundColor: t.soft(FxTokens.amber),
          foregroundColor: t.ink(FxTokens.amber),
          icon: Icons.edit_outlined,
          label: 'Sửa',
        ),
      if (_canDelete)
        SlidableAction(
          onPressed: (_) {
            _showDeleteConfirmDialog(item);
          },
          backgroundColor: t.soft(FxTokens.red),
          foregroundColor: t.ink(FxTokens.red),
          icon: Icons.delete_outline_rounded,
          label: 'Xóa',
        ),
    ];

    return FxCard(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.zero,
      child: Slidable(
        key: ValueKey(item.vehicleMaintenanceId),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: (0.22 * actions.length).clamp(0.22, 0.66),
          children: actions,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _openDetail(item),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.w, 8.w, 12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FxIconBadge(icon: VmTone.typeIcon(item.vehicleMaintenanceType), tone: tone, size: 40),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicleLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.h2.copyWith(fontFeatures: FxTokens.tabular),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              [
                                if (vehicleName.isNotEmpty && vehicleName != vehicleLabel) vehicleName,
                                VmTone.typeLabel(item.vehicleMaintenanceType),
                                '#${item.vehicleMaintenanceId}',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      FxPill(label: _getStatusLabel(status), tone: tone, dot: true),
                      if (_canUpdate || _canDelete) _moreMenu(t, item) else SizedBox(width: 6.w),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Icon(Icons.event_rounded, size: 14.sp, color: t.textFaint),
                            SizedBox(width: 5.w),
                            Text(fromDate, style: t.small.copyWith(color: t.text, fontFeatures: FxTokens.tabular)),
                            if (location.isNotEmpty) ...[
                              SizedBox(width: 12.w),
                              Icon(Icons.place_outlined, size: 14.sp, color: t.textFaint),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.small),
                              ),
                            ],
                          ],
                        ),
                        if (item.vehicleMaintenanceDescription?.isNotEmpty == true) ...[
                          SizedBox(height: 8.h),
                          Text(
                            item.vehicleMaintenanceDescription!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.small.copyWith(height: 1.4),
                          ),
                        ],
                        SizedBox(height: 12.h),
                        Container(height: 1, color: t.divider),
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6.w,
                                runSpacing: 6.h,
                                children: [
                                  FxPill(
                                    label: _getRankLabel(item.vehicleMaintenanceRank),
                                    tone: VmTone.rank(item.vehicleMaintenanceRank),
                                    icon: Icons.flag_rounded,
                                  ),
                                  FxPill(
                                    label: _getPaymentStatusLabel(item.paymentStatus),
                                    tone: VmTone.payment(item.paymentStatus),
                                    icon: Icons.payments_outlined,
                                  ),
                                  if (docs > 0) FxPill(label: '$docs', tone: FxTokens.slate, icon: Icons.attach_file_rounded),
                                ],
                              ),
                            ),
                            if (item.totalAmount != null) ...[
                              SizedBox(width: 8.w),
                              Text(
                                '${NumberFormat('#,##0', 'vi').format(item.totalAmount)} ${item.currency ?? 'VND'}',
                                style: t.num(13.5.sp),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Same actions as the swipe pane, for users who don't discover the swipe.
  Widget _moreMenu(FxTokens t, VehicleMaintenance item) {
    return SizedBox(
      width: 32.w,
      height: 32.w,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        tooltip: 'Thao tác',
        icon: Icon(Icons.more_vert_rounded, size: 19.sp, color: t.textMuted),
        onSelected: (v) {
          if (v == 'detail') _openDetail(item);
          if (v == 'edit') _openEdit(item);
          if (v == 'delete') _showDeleteConfirmDialog(item);
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'detail',
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 18.sp, color: t.ink(FxTokens.blue)),
              SizedBox(width: 10.w),
              const Text('Chi tiết'),
            ]),
          ),
          if (_canUpdate)
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 18.sp, color: t.ink(FxTokens.amber)),
                SizedBox(width: 10.w),
                const Text('Sửa'),
              ]),
            ),
          if (_canDelete)
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded, size: 18.sp, color: t.ink(FxTokens.red)),
                SizedBox(width: 10.w),
                Text('Xóa', style: TextStyle(color: t.ink(FxTokens.red))),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      children: [
        for (var i = 0; i < 5; i++) ...[
          FxSkeleton(height: 148.h, radius: 18),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}
