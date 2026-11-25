import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/wa_widgets_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/work_assignment_manager_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/work_attendance_manager_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/work_task_manager_v2.dart';

/// "Bố trí công việc" (v2). Same constructor, permission rules, tabs and "Chụp lịch" action as
/// `WorkArrangementPage` (v1, lib/features/work_arrangement/presentation/work_arrangement_page.dart);
/// only the layout changes and the v2 sub-screens are used.
class WorkArrangementPageV2 extends StatefulWidget {
  const WorkArrangementPageV2({super.key});

  @override
  State<WorkArrangementPageV2> createState() => _WorkArrangementPageV2State();
}

class _WorkArrangementPageV2State extends State<WorkArrangementPageV2> with TickerProviderStateMixin {
  TabController? _tabController;
  VoidCallback? _doChupLich;
  bool _isChupLoading = false;

  final UserManageService _userManageService = UserManageService();
  String _userRole = '';
  bool _isLoading = true;
  bool _canViewArrangements = false;
  bool _canViewAttendance = false;
  bool _canUpdateArrangements = false;
  bool _canUpdateAttendance = false;

  final List<String> _activeTabNames = [];

  // ── v2 presentation only ──────────────────────────────────────────────────
  static const Map<String, ({IconData icon, String subtitle})> _tabMeta = {
    'Phân công': (icon: Icons.local_shipping_rounded, subtitle: 'Bố trí nhân sự cho xe bơm & xe trộn'),
    'Công việc': (icon: Icons.assignment_rounded, subtitle: 'Giao công việc cho nhân sự theo ngày'),
    'Chấm công': (icon: Icons.how_to_reg_rounded, subtitle: 'Chấm công ngày & tổng quan tháng'),
  };

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  // ── Logic (verbatim from WorkArrangementPage) ─────────────────────────────

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canViewArrangements = _userRole == 'admin' || myPerms.contains('/work-arrangements__view');
          _canViewAttendance = _userRole == 'admin' || myPerms.contains('/work-attendance__view');
          _canUpdateArrangements = _userRole == 'admin' || myPerms.contains('/work-arrangements__update');
          _canUpdateAttendance = _userRole == 'admin' || myPerms.contains('/work-attendance__update');

          _activeTabNames.clear();
          if (_canViewArrangements) {
            _activeTabNames.add('Phân công');
            _activeTabNames.add('Công việc');
          }
          if (_canViewAttendance) {
            _activeTabNames.add('Chấm công');
          }

          if (_activeTabNames.isNotEmpty) {
            _tabController = TabController(length: _activeTabNames.length, vsync: this);
            _tabController!.addListener(() {
              setState(() {});
            });
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// v2: retry from the "no access" state (only reachable while no tab controller exists).
  void _retryPermissions() {
    setState(() => _isLoading = true);
    _loadPermissions();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _appBar(FxTokens t, {String? subtitle, List<Widget>? actions, PreferredSizeWidget? bottom}) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: canPop ? 0 : 16.w,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bố trí công việc',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.h1.copyWith(fontSize: 19.sp),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 1.h),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
          ],
        ],
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: _appBar(t, subtitle: 'Đang kiểm tra quyền truy cập…'),
        body: const _PageSkeleton(),
      );
    }

    if (_activeTabNames.isEmpty) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: _appBar(t),
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: FxEmpty(
              icon: Icons.lock_outline_rounded,
              title: 'Bạn không có quyền truy cập chức năng này',
              message: 'Liên hệ quản trị viên để được cấp quyền xem phân công hoặc chấm công.',
              action: FilledButton.tonalIcon(
                onPressed: _retryPermissions,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ),
          ),
        ),
      );
    }

    final tabChildren = <Widget>[];

    if (_canViewArrangements) {
      tabChildren.add(
        WorkAssignmentManagerV2(
          onRegisterChup: (fn) {
            _doChupLich = fn;
          },
          onChupLoadingChange: (loading) {
            setState(() {
              _isChupLoading = loading;
            });
          },
          readOnly: !_canUpdateArrangements,
        ),
      );

      tabChildren.add(WorkTaskManagerV2(readOnly: !_canUpdateArrangements));
    }

    if (_canViewAttendance) {
      tabChildren.add(WorkAttendanceManagerV2(readOnly: !_canUpdateAttendance));
    }

    // Determine if we show the camera snapshot icon
    final isPhanCongTabActive = _canViewArrangements && _tabController != null && _tabController!.index == 0;

    final activeIndex = (_tabController?.index ?? 0).clamp(0, _activeTabNames.length - 1);
    final activeMeta = _tabMeta[_activeTabNames[activeIndex]];

    return Scaffold(
      backgroundColor: t.bg,
      appBar: _appBar(
        t,
        subtitle: activeMeta?.subtitle,
        actions: [
          if (isPhanCongTabActive && _canUpdateArrangements)
            Center(
              child: WaToolButton(
                icon: Icons.photo_camera_outlined,
                tooltip: 'Chụp lịch',
                tone: FxTokens.blue,
                loading: _isChupLoading,
                onTap: _isChupLoading ? null : _doChupLich,
              ),
            ),
          SizedBox(width: 12.w),
        ],
        // A single tab needs no tab bar (it is still hosted by the same TabController / TabBarView).
        bottom: _activeTabNames.length < 2
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(54.h),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 8.h),
                  child: WaPillTabBar(
                    controller: _tabController,
                    onTap: (index) {
                      setState(() {});
                    },
                    tabs: [
                      for (final name in _activeTabNames)
                        (icon: _tabMeta[name]?.icon ?? Icons.circle_outlined, label: name),
                    ],
                  ),
                ),
              ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: tabChildren,
      ),
    );
  }
}

class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FxSkeleton(height: 42.h, radius: 13),
        SizedBox(height: 14.h),
        Row(
          children: [
            FxSkeleton(height: 38.h, width: 100.w, radius: 12),
            SizedBox(width: 8.w),
            FxSkeleton(height: 38.h, width: 38.h, radius: 12),
            SizedBox(width: 10.w),
            Expanded(child: FxSkeleton(height: 38.h, radius: 13)),
          ],
        ),
        SizedBox(height: 14.h),
        FxSkeleton(height: 70.h, radius: 18),
        SizedBox(height: 12.h),
        for (var i = 0; i < 3; i++) ...[FxSkeleton(height: 150.h, radius: 18), SizedBox(height: 10.h)],
      ],
    );
  }
}
