import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/user_manage/data/models/user_manage_model.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/user_manage/presentation/v2/widgets/user_form_modal_v2.dart';
import 'package:nguyenanh/features/user_manage/presentation/v2/widgets/user_manage_ui_v2.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Tất cả người dùng" (v2). Same paging, search, permissions (create / update / delete) and service
/// calls as [UserListPage] (v1, ../user_list_page.dart) — only the layout changes.
class UserListPageV2 extends StatefulWidget {
  final bool isTab;
  const UserListPageV2({super.key, this.isTab = false});

  @override
  State<UserListPageV2> createState() => _UserListPageV2State();
}

class _UserListPageV2State extends State<UserListPageV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  final UserManageService _userService = UserManageService();

  List<UserManageModel> _users = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;
  String _searchQuery = '';

  bool _canCreate = false;
  bool _canUpdate = false;
  bool _canDelete = false;

  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final Map<String, String> _roleNames = {
    'admin': 'Quản trị viên',
    'manager': 'Quản lý',
    'dispatcher': 'Điều phối xe',
    'driver': 'Tài xế',
    'user': 'Người dùng',
  };

  // ── v2 presentation only ──────────────────────────────────────────────────
  /// Role filter applied to the rows already loaded (null = all). Does not change what is fetched.
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchUsers();
    _scrollController.addListener(_onScroll);
  }

  // ── Logic (verbatim from v1; `mounted` guards added after awaits) ────────

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userService.getPermissions();
      final myPerms = perms[role] ?? [];
      if (mounted) {
        setState(() {
          _canCreate = role == 'admin' || myPerms.contains('/user-manage__create');
          _canUpdate = role == 'admin' || myPerms.contains('/user-manage__update');
          _canDelete = role == 'admin' || myPerms.contains('/user-manage__delete');
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _page++;
        _fetchUsers(isLoadMore: true);
      }
    }
  }

  /// Same as the scroll trigger in [_onScroll]; used by the "Tải thêm" button when the list is too
  /// short to scroll (e.g. a role filter hides most rows, or a tall screen).
  void _loadMore() {
    if (!_isLoading && _hasMore) {
      _page++;
      _fetchUsers(isLoadMore: true);
    }
  }

  Future<void> _fetchUsers({bool isLoadMore = false}) async {
    if (!mounted) return;
    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _users = [];
        _hasMore = true;
      });
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _userService.getUsers(
        page: _page,
        limit: 15,
        search: _searchQuery,
      );

      final List<UserManageModel> newUsers = data['users'];
      final int total = data['total'];

      if (!mounted) return;
      setState(() {
        if (isLoadMore) {
          _users.addAll(newUsers);
        } else {
          _users = newUsers;
        }
        _total = total;
        _hasMore = _users.length < total;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _fetchUsers();
    });
  }

  Future<void> _deleteUser(UserManageModel user) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = FxTokens.of(ctx);
        return AlertDialog(
          icon: FxIconBadge(icon: Icons.person_remove_rounded, tone: FxTokens.red, size: 44),
          title: Text(l10n.confirm, textAlign: TextAlign.center),
          content: Text(
            'Bạn có chắc chắn muốn xóa người dùng ${user.userFullName}?',
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: t.textMuted),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: FxTokens.red, foregroundColor: Colors.white),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _userService.deleteUser(user.userId);
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xóa thành công ${user.userFullName}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi xóa: $e')),
          );
        }
      }
    }
  }

  void _showUserModal({UserManageModel? user}) {
    final t = FxTokens.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: t.bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: UserFormModalV2(
          user: user,
          onSuccess: _fetchUsers,
        ),
      ),
    );
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  /// Roles present in the loaded rows, known roles first.
  List<String> get _rolesInList {
    final present = _users.map((u) => u.role).toSet();
    final ordered = [
      for (final r in _roleNames.keys)
        if (present.contains(r)) r,
      for (final r in present)
        if (!_roleNames.containsKey(r)) r,
    ];
    if (_roleFilter != null && !ordered.contains(_roleFilter)) ordered.add(_roleFilter!);
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 760 ? (width - 720) / 2 : 14.w;
    final visible = _roleFilter == null ? _users : _users.where((u) => u.role == _roleFilter).toList();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: widget.isTab
          ? null
          : AppBar(
              backgroundColor: t.bg,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              centerTitle: false,
              title: Text('Quản lý người dùng', style: t.h1.copyWith(fontSize: 19.sp)),
            ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, 12.h, side, 10.h),
            child: _searchField(t),
          ),
          SizedBox(
            height: 34.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: side),
              children: [
                UmFilterChip(
                  label: 'Tất cả',
                  icon: Icons.groups_rounded,
                  selected: _roleFilter == null,
                  count: '$_total',
                  onTap: () => setState(() => _roleFilter = null),
                ),
                for (final role in _rolesInList) ...[
                  SizedBox(width: 8.w),
                  UmFilterChip(
                    label: _roleNames[role] ?? role,
                    icon: umRoleIcon(role),
                    tone: umRoleTone(role),
                    selected: _roleFilter == role,
                    onTap: () => setState(() => _roleFilter = _roleFilter == role ? null : role),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchUsers(),
              child: _list(t, side, visible),
            ),
          ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _showUserModal(),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Thêm người dùng'),
            )
          : null,
    );
  }

  Widget _searchField(FxTokens t) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: c, width: w));
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) => TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: t.body,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm theo tên...',
          hintStyle: t.small,
          prefixIcon: Icon(Icons.search_rounded, color: t.textFaint, size: 20.sp),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xoá tìm kiếm',
                  icon: Icon(Icons.close_rounded, size: 18.sp, color: t.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
          filled: true,
          fillColor: t.card,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
          border: b(t.border),
          enabledBorder: b(t.border),
          focusedBorder: b(FxTokens.blue, 1.4),
        ),
      ),
    );
  }

  Widget _list(FxTokens t, double side, List<UserManageModel> visible) {
    final padding = EdgeInsets.fromLTRB(side, 4.h, side, 96.h);

    // First page loading.
    if (_users.isEmpty && _isLoading) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [for (var i = 0; i < 6; i++) const _UserSkeleton()],
      );
    }

    // Nothing returned by the server.
    if (_users.isEmpty) {
      final searching = _searchQuery.isNotEmpty;
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          SizedBox(height: 48.h),
          FxEmpty(
            icon: searching ? Icons.person_search_rounded : Icons.group_off_rounded,
            title: searching ? 'Không tìm thấy người dùng' : 'Không có dữ liệu',
            message: searching ? 'Không có ai khớp với "$_searchQuery".' : 'Kéo xuống để tải lại danh sách.',
          ),
        ],
      );
    }

    final showFilterEmpty = visible.isEmpty;
    final count = 1 + (showFilterEmpty ? 1 : visible.length) + 1;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      itemBuilder: (context, index) {
        if (index == 0) return _summary(t, visible.length);
        if (index == count - 1) return _footer(t);
        if (showFilterEmpty) {
          return FxEmpty(
            icon: Icons.filter_alt_off_rounded,
            title: 'Không có người dùng thuộc vai trò này',
            message: _hasMore ? 'Tải thêm để tìm trong các trang tiếp theo.' : null,
          );
        }
        return _userCard(t, visible[index - 1]);
      },
    );
  }

  Widget _summary(FxTokens t, int shown) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2.w, 4.h, 2.w, 10.h),
      child: Row(
        children: [
          Text('$_total', style: t.num(15.sp)),
          SizedBox(width: 5.w),
          Text('người dùng', style: t.small),
          const Spacer(),
          if (_roleFilter != null || _users.length < _total)
            Text(
              _roleFilter != null ? 'Đang lọc $shown / ${_users.length} đã tải' : 'Đã tải ${_users.length}',
              style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
            ),
        ],
      ),
    );
  }

  Widget _footer(FxTokens t) {
    if (_isLoading) {
      return const Column(children: [_UserSkeleton(), _UserSkeleton()]);
    }
    if (_hasMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Center(
          child: TextButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('Tải thêm'),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Center(
        child: Text('Đã hiển thị tất cả ${_users.length} người dùng', style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
      ),
    );
  }

  Widget _userCard(FxTokens t, UserManageModel user) {
    final tone = umRoleTone(user.role);
    final roleLabel = _roleNames[user.role] ?? user.role;
    final status = umStatus(user.userStatus);
    final shortName = user.userShortName?.trim() ?? '';
    final hasActions = _canUpdate || _canDelete;

    return FxCard(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.fromLTRB(12.w, 12.h, hasActions ? 2.w : 12.w, 12.h),
      onTap: _canUpdate ? () => _showUserModal(user: user) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UmAvatar(name: user.userFullName, tone: tone, size: 44),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.userFullName.isEmpty ? '—' : user.userFullName,
                        style: t.h3.copyWith(fontSize: 14.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (shortName.isNotEmpty) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: t.cardAlt,
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: t.border),
                        ),
                        child: Text(shortName, style: t.tiny.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  user.username.isEmpty ? '—' : '@${user.username}',
                  style: t.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    FxPill(label: roleLabel, tone: tone, icon: umRoleIcon(user.role)),
                    if (status != null) FxPill(label: status.label, tone: status.tone, dot: true),
                  ],
                ),
                SizedBox(height: 8.h),
                _meta(t, Icons.mail_outline_rounded, user.userEmail.isNotEmpty ? user.userEmail : 'Chưa cập nhật',
                    faint: user.userEmail.isEmpty),
                if (user.userPhoneNumber.isNotEmpty) ...[
                  SizedBox(height: 3.h),
                  _meta(t, Icons.phone_outlined, user.userPhoneNumber),
                ],
              ],
            ),
          ),
          if (hasActions)
            PopupMenuButton<String>(
              tooltip: 'Thao tác',
              icon: Icon(Icons.more_vert_rounded, color: t.textMuted, size: 20.sp),
              onSelected: (v) {
                if (v == 'edit') {
                  _showUserModal(user: user);
                } else if (v == 'delete') {
                  _deleteUser(user);
                }
              },
              itemBuilder: (context) => [
                if (_canUpdate)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      FxIconBadge(icon: Icons.edit_outlined, tone: FxTokens.blue, size: 28),
                      SizedBox(width: 10.w),
                      Text('Chỉnh sửa', style: t.h3),
                    ]),
                  ),
                if (_canDelete)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      FxIconBadge(icon: Icons.delete_outline_rounded, tone: FxTokens.red, size: 28),
                      SizedBox(width: 10.w),
                      Text('Xóa', style: t.h3.copyWith(color: t.ink(FxTokens.red))),
                    ]),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _meta(FxTokens t, IconData icon, String text, {bool faint = false}) {
    return Row(
      children: [
        Icon(icon, size: 13.sp, color: t.textFaint),
        SizedBox(width: 5.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.tiny.copyWith(color: faint ? t.textFaint : t.textMuted, fontStyle: faint ? FontStyle.italic : null),
          ),
        ),
      ],
    );
  }
}

class _UserSkeleton extends StatelessWidget {
  const _UserSkeleton();

  @override
  Widget build(BuildContext context) {
    return FxCard(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FxSkeleton(height: 44.w, width: 44.w, radius: 22.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FxSkeleton(height: 12.h, width: 150.w, radius: 6),
                SizedBox(height: 6.h),
                FxSkeleton(height: 9.h, width: 90.w, radius: 6),
                SizedBox(height: 10.h),
                Row(children: [
                  FxSkeleton(height: 18.h, width: 76.w, radius: 9),
                  SizedBox(width: 6.w),
                  FxSkeleton(height: 18.h, width: 60.w, radius: 9),
                ]),
                SizedBox(height: 10.h),
                FxSkeleton(height: 9.h, width: 180.w, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
