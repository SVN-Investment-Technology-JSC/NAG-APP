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
import 'package:nguyenanh/features/application_form/presentation/v2/application_detail_page_v2.dart';
import 'package:nguyenanh/features/application_form/presentation/v2/application_form_page_v2.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

/// "Đơn xin bận" list (v2). Same constructor, state, TabController-driven status filter, provider
/// calls, permissions and navigation as `ApplicationListPage`; only the widget tree is redesigned.
class ApplicationListPageV2 extends StatefulWidget {
  const ApplicationListPageV2({super.key});

  @override
  State<ApplicationListPageV2> createState() => _ApplicationListPageV2State();
}

class _ApplicationListPageV2State extends State<ApplicationListPageV2> with SingleTickerProviderStateMixin {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  late final TabController _tabController;
  String _userRole = '';
  // ignore: unused_field
  String _userFullName = ''; // kept from v1 (read but never displayed there either)
  bool _isLoading = true;
  bool _canCreateRequest = false;

  // ── v2 presentation only ──────────────────────────────────────────────────
  /// Client-side search over the loaded list (driver, vehicle, tag, reason).
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  static const _tabLabels = ['Chờ duyệt', 'Đã duyệt', 'Từ chối', 'Đã hủy'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadUserInfo();
  }

  // ── Logic (verbatim from v1) ──────────────────────────────────────────────

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? 'driver';
    _userRole = role;
    _userFullName = prefs.getString('user_full_name') ?? '';

    try {
      final UserManageService userService = UserManageService();
      final perms = await userService.getPermissions();
      final myPerms = perms[role] ?? [];
      if (mounted) {
        setState(() {
          _canCreateRequest =
              role == 'admin' || role == 'driver' || myPerms.contains('/work-arrangements/lot-tag-requests__create');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _canCreateRequest = role == 'admin' || role == 'driver';
        });
      }
    }

    await _loadData();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    final mine = _userRole == 'driver';
    final status = _getStatusFromIndex(_tabController.index);
    await Provider.of<ApplicationProvider>(context, listen: false).fetchRequests(
      page: 1,
      limit: 100,
      status: status,
      mine: mine,
    );
  }

  String _getStatusFromIndex(int index) {
    switch (index) {
      case 0:
        return 'pending';
      case 1:
        return 'approved';
      case 2:
        return 'rejected';
      case 3:
        return 'canceled';
      default:
        return 'pending';
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

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ApplicationFormPageV2()),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _openDetail(LotTagRequest item) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplicationDetailPageV2(applicationId: item.lotTagRequestId),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final isDriver = _userRole == 'driver';

    if (_isLoading) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: afAppBar(context, title: 'Đơn xin bận', subtitle: 'Đang tải…'),
        body: const _ListSkeleton(withHeader: true),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: afAppBar(
        context,
        title: 'Đơn xin bận',
        subtitle: isDriver ? 'Đơn của tôi' : 'Đơn từ của tài xế',
      ),
      floatingActionButton: _canCreateRequest
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo đơn', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxSegmented<int>(
                  segments: [
                    for (var i = 0; i < _tabLabels.length; i++) FxSegment(i, _tabLabels[i]),
                  ],
                  value: _tabController.index,
                  onChanged: (i) {
                    if (i == _tabController.index) return;
                    // Setting the index fires the v1 listener (indexIsChanging == false) → _loadData().
                    _tabController.index = i;
                    setState(() {});
                  },
                ),
                SizedBox(height: 10.h),
                FxSearchField(
                  controller: _searchController,
                  hint: 'Tìm tài xế, biển số, lý do…',
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<ApplicationProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const _ListSkeleton(withHeader: false);
                }

                return RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildListSection(t, provider.requests),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(LotTagRequest item, String q) {
    if (q.isEmpty) return true;
    final hay = [
      item.requestedByUser?.userFullName,
      item.requestedByUser?.userShortName,
      item.vehicle?.vehicleLicensePlate,
      item.vehicle?.vehicleName,
      item.lotTag?.lotTagName,
      item.lotTagKey,
      item.requestReason,
      '#${item.lotTagRequestId}',
    ].whereType<String>().join(' ').toLowerCase();
    return hay.contains(q);
  }

  Widget _buildListSection(FxTokens t, List<LotTagRequest> all) {
    final q = _query.trim().toLowerCase();
    final items = all.where((e) => _matches(e, q)).toList();
    final statusLabel = _tabLabels[_tabController.index.clamp(0, _tabLabels.length - 1)];

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 80.h),
          FxEmpty(
            icon: q.isEmpty ? Icons.description_outlined : Icons.search_off_rounded,
            title: q.isEmpty ? 'Không có đơn từ nào trong danh sách' : 'Không tìm thấy đơn phù hợp',
            message: q.isEmpty ? 'Mục "$statusLabel" hiện chưa có đơn nào.' : 'Thử từ khóa khác.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, _canCreateRequest ? 96.h : 24.h),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 8.h),
            child: Row(
              children: [
                Text(
                  '${items.length} ĐƠN · ${statusLabel.toUpperCase()}',
                  style: t.overline.copyWith(fontFeatures: FxTokens.tabular),
                ),
                if (q.isNotEmpty) ...[
                  const Spacer(),
                  Text('Lọc từ ${all.length} đơn', style: t.tiny.copyWith(color: t.textFaint, fontFeatures: FxTokens.tabular)),
                ],
              ],
            ),
          );
        }
        return _buildCard(t, items[index - 1]);
      },
    );
  }

  Widget _buildCard(FxTokens t, LotTagRequest item) {
    final tone = AfTone.status(item.requestStatus);
    final dateStr = _formatDate(item.workDate);
    final workDate = DateTime.tryParse(item.workDate);

    final vehiclePlate = item.vehicle?.vehicleLicensePlate;
    final vehicleName = item.vehicle?.vehicleName;
    final vehicleLabel = [vehiclePlate, vehicleName].where((e) => e != null && e.isNotEmpty).join(' · ');
    final tagLabel = item.lotTag?.lotTagName ?? item.lotTagKey;
    final driverName = item.requestedByUser?.userFullName ?? 'Tài xế #${item.requestedBy ?? ''}';

    return FxCard(
      margin: EdgeInsets.only(bottom: 10.h),
      onTap: () => _openDetail(item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfDateBlock(date: workDate, tone: tone),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(driverName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h2),
                    ),
                    SizedBox(width: 8.w),
                    FxPill(label: _getVietnameseStatus(item.requestStatus), tone: tone, dot: true),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(Icons.event_rounded, size: 13.sp, color: t.textFaint),
                    SizedBox(width: 4.w),
                    Text(dateStr, style: t.small.copyWith(color: t.text, fontFeatures: FxTokens.tabular)),
                    if (vehicleLabel.isNotEmpty) ...[
                      SizedBox(width: 10.w),
                      Icon(Icons.local_shipping_outlined, size: 13.sp, color: t.textFaint),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          vehicleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.small.copyWith(fontFeatures: FxTokens.tabular),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Flexible(child: FxPill(label: tagLabel.toUpperCase(), tone: FxTokens.indigo, icon: Icons.label_outline_rounded)),
                    SizedBox(width: 6.w),
                    Text('#${item.lotTagRequestId}', style: t.tiny.copyWith(color: t.textFaint, fontFeatures: FxTokens.tabular)),
                  ],
                ),
                if (item.requestReason != null && item.requestReason!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    item.requestReason!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.small.copyWith(height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  final bool withHeader;
  const _ListSkeleton({required this.withHeader});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, withHeader ? 4.h : 12.h, 16.w, 24.h),
      children: [
        if (withHeader) ...[
          FxSkeleton(height: 40.h),
          SizedBox(height: 10.h),
          FxSkeleton(height: 42.h),
          SizedBox(height: 16.h),
        ],
        for (var i = 0; i < 5; i++) ...[
          FxSkeleton(height: 112.h, radius: 18),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }
}
