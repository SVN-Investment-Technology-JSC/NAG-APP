import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/user_manage/presentation/v2/permissions_page_v2.dart';
import 'package:nguyenanh/features/user_manage/presentation/v2/user_list_page_v2.dart';

/// "Quản lý người dùng" (v2). Same permission check ('/role-permissions__view' shows the
/// "Quyền hạn" tab) as [UserManageMainPage] (v1, ../user_manage_main_page.dart); opens the v2 tabs.
class UserManageMainPageV2 extends StatefulWidget {
  const UserManageMainPageV2({super.key});

  @override
  State<UserManageMainPageV2> createState() => _UserManageMainPageV2State();
}

class _UserManageMainPageV2State extends State<UserManageMainPageV2> {
  // ── State + logic (verbatim from v1) ──────────────────────────────────────
  final UserManageService _userService = UserManageService();
  bool _canViewPermissions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userService.getPermissions();
      final myPerms = perms[role] ?? [];
      if (mounted) {
        setState(() {
          _canViewPermissions = role == 'admin' || myPerms.contains('/role-permissions__view');
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  PreferredSizeWidget _appBar(FxTokens t, double side, {PreferredSizeWidget? bottom}) {
    return AppBar(
      backgroundColor: t.bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 4.w,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Quản lý người dùng', style: t.h1.copyWith(fontSize: 19.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('Tài khoản & phân quyền', style: t.tiny),
        ],
      ),
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 760 ? (width - 720) / 2 : 14.w;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: t.bg,
        appBar: _appBar(t, side),
        body: _LoadingList(side: side),
      );
    }

    return DefaultTabController(
      length: _canViewPermissions ? 2 : 1,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return Scaffold(
            backgroundColor: t.bg,
            appBar: _appBar(
              t,
              side,
              bottom: _canViewPermissions
                  ? PreferredSize(
                      preferredSize: Size.fromHeight(52.h),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(side, 2.h, side, 10.h),
                        child: AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) => FxSegmented<int>(
                            value: controller.index,
                            onChanged: (i) => controller.animateTo(i),
                            segments: const [
                              FxSegment(0, 'Tất cả người dùng', icon: Icons.groups_rounded),
                              FxSegment(1, 'Quyền hạn', icon: Icons.admin_panel_settings_rounded),
                            ],
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            body: TabBarView(
              children: [
                const UserListPageV2(isTab: true),
                if (_canViewPermissions) const PermissionsPageV2(isTab: true),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  final double side;
  const _LoadingList({required this.side});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, 8.h, side, 8.h),
      children: [
        FxSkeleton(height: 40.h, radius: 12),
        SizedBox(height: 14.h),
        FxSkeleton(height: 42.h, radius: 12),
        SizedBox(height: 10.h),
        Row(children: [
          FxSkeleton(height: 30.h, width: 90.w, radius: 10),
          SizedBox(width: 8.w),
          FxSkeleton(height: 30.h, width: 80.w, radius: 10),
          SizedBox(width: 8.w),
          FxSkeleton(height: 30.h, width: 70.w, radius: 10),
        ]),
        for (var i = 0; i < 5; i++) ...[
          SizedBox(height: 10.h),
          FxSkeleton(height: 96.h, radius: 18),
        ],
      ],
    );
  }
}
