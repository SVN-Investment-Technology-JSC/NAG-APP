import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/user_manage/data/permission_catalog.dart';
import 'package:nguyenanh/features/user_manage/presentation/v2/widgets/user_manage_ui_v2.dart';

/// "Quyền hạn" (v2). Same role list, permission tree, permission keys, tri-state rules, toggle rules
/// (incl. the lot-order / lot-order-limit-3 exclusivity), normalisation and save call as
/// [PermissionsPage] (v1, ../permissions_page.dart) — only the layout changes.
///
/// The v1 tree data and logic below are copied verbatim; v2 adds only presentation state
/// (saved snapshot for the "unsaved changes" bar, load-error banner).
class PermissionsPageV2 extends StatefulWidget {
  final bool isTab;
  const PermissionsPageV2({super.key, this.isTab = false});

  @override
  State<PermissionsPageV2> createState() => _PermissionsPageV2State();
}

class _PermissionsPageV2State extends State<PermissionsPageV2> {
  // ── State (verbatim from v1) ──────────────────────────────────────────────
  final UserManageService _userService = UserManageService();
  String _selectedRole = 'manager';
  bool _canEditPermissions = false;

  Map<String, List<String>> _permissions = {};
  bool _isLoading = true;
  bool _isSaving = false;

  List<String> _availableRoles = ['manager', 'dispatcher', 'driver', 'user'];

  Map<String, String> _roleNames = {
    'admin': 'Quản trị viên',
    'manager': 'Quản lý',
    'dispatcher': 'Điều phối xe',
    'driver': 'Tài xế',
    'user': 'Người dùng',
  };

  final Set<String> _expandedKeys = {
    '/dashboard',
    'category-group',
    'tools-group',
  };

  // Same tree as the web (see permission_catalog.dart).
  final List<PermissionNode> _permissionTree = buildPermissionTree();

  static const Map<String, String> _permissionNames = kPermissionNames;

  // ── v2 presentation only ──────────────────────────────────────────────────
  /// Permissions as last loaded from / saved to the server (to show the unsaved-changes state).
  Map<String, Set<String>> _baseline = {};

  /// Last load failed (banner only; the page behaves like v1 otherwise).
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = _availableRoles.first;
    _loadPermissions();
  }

  // ── Logic (verbatim from v1; `mounted` guards + snapshot lines added) ─────

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserRole = prefs.getString('user_role') ?? '';

      List<Map<String, dynamic>> rolesData = [];
      try {
        rolesData = await _userService.getRoles();
      } catch (e) {
        debugPrint('Error loading roles from API: $e');
      }

      final data = await _userService.getPermissions();

      if (!mounted) return;
      setState(() {
        if (rolesData.isNotEmpty) {
          final List<String> fetchedRoles = [];
          final Map<String, String> fetchedNames = {
            'admin': 'Quản trị viên',
          };
          for (final roleObj in rolesData) {
            final String rName = roleObj['role'] ?? '';
            final String rLabel = roleObj['role_label'] ?? rName;
            if (rName.isNotEmpty && rName != 'admin') {
              fetchedRoles.add(rName);
              fetchedNames[rName] = rLabel;
            }
          }
          if (fetchedRoles.isNotEmpty) {
            _availableRoles = fetchedRoles;
            _roleNames = fetchedNames;
          }
        }

        if (!_availableRoles.contains(_selectedRole)) {
          _selectedRole = _availableRoles.isNotEmpty ? _availableRoles.first : 'manager';
        }

        final currentUserPerms = data[currentUserRole] ?? [];
        _canEditPermissions = currentUserRole == 'admin' || currentUserPerms.contains('/role-permissions__update');
        _permissions = Map<String, List<String>>.from(
            data.map((key, value) => MapEntry(key, List<String>.from(value))));
        _isLoading = false;
        // v2: snapshot for the unsaved-changes bar.
        _baseline = _snapshot(_permissions);
        _loadFailed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true; // v2: banner only
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải quyền hạn: $e')),
        );
      }
    }
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);

    final normalizedPermissions = <String, List<String>>{};

    final allParentKeys = kPermissionParentKeys;

    for (final role in _permissions.keys) {
      final rolePerms = _permissions[role]?.toSet() ?? {};
      // Filter out non-leaf structural keys
      rolePerms.removeAll(allParentKeys);
      normalizedPermissions[role] = rolePerms.toList();
    }

    try {
      await _userService.updatePermissions(normalizedPermissions);
      if (mounted) {
        setState(() {
          _permissions.clear();
          _permissions.addAll(normalizedPermissions);
          // v2: the saved state becomes the new snapshot.
          _baseline = _snapshot(normalizedPermissions);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lưu quyền hạn thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<String> _getAllLeafPermissions(PermissionNode node) {
    final result = <String>[];
    if (node.actions.isNotEmpty) {
      result.addAll(node.actions);
    }
    if (node.children.isNotEmpty) {
      for (var child in node.children) {
        result.addAll(_getAllLeafPermissions(child));
      }
    }
    if (node.actions.isEmpty && node.children.isEmpty) {
      result.add(node.key);
    }
    return result;
  }

  void _toggleNodeState(String role, PermissionNode node, bool isGranted) {
    if (!_canEditPermissions) return;
    final leaves = _getAllLeafPermissions(node);
    final before = List<String>.from(_permissions[role] ?? const <String>[]);
    setState(() {
      if (_permissions[role] == null) {
        _permissions[role] = [];
      }
      if (isGranted) {
        for (var leaf in leaves) {
          if (leaf == '/dashboard__view_lot_order_limit_3') {
            continue;
          }
          if (!_permissions[role]!.contains(leaf)) {
            _permissions[role]!.add(leaf);
          }
        }
        if (leaves.contains('/dashboard__view_lot_order')) {
          _permissions[role]!.remove('/dashboard__view_lot_order_limit_3');
        }
      } else {
        for (var leaf in leaves) {
          _permissions[role]!.remove(leaf);
        }
      }
      // same dependency rule as the web: an action implies "Xem"; removing "Xem" removes the page's actions
      _permissions[role] = applyWebPermissionRules(before, _permissions[role] ?? const <String>[]);
    });
  }

  void _togglePermission(String role, String perm, bool isGranted) {
    if (!_canEditPermissions) return;
    final before = List<String>.from(_permissions[role] ?? const <String>[]);
    setState(() {
      if (_permissions[role] == null) {
        _permissions[role] = [];
      }
      if (isGranted) {
        if (!_permissions[role]!.contains(perm)) {
          _permissions[role]!.add(perm);
        }
        if (perm == '/dashboard__view_lot_order') {
          _permissions[role]!.remove('/dashboard__view_lot_order_limit_3');
        } else if (perm == '/dashboard__view_lot_order_limit_3') {
          _permissions[role]!.remove('/dashboard__view_lot_order');
        }
      } else {
        _permissions[role]!.remove(perm);
      }
      // same dependency rule as the web: an action implies "Xem"; removing "Xem" removes the page's actions
      _permissions[role] = applyWebPermissionRules(before, _permissions[role] ?? const <String>[]);
    });
  }

  /// Leaf set used for the tri-state value of a node — the exact rule of v1 `_buildTreeWidgets`.
  List<String> _leavesForChecking(PermissionNode node, List<String> rolePerms) {
    final leaves = _getAllLeafPermissions(node);
    final leavesForChecking = leaves.toList();
    if (!rolePerms.contains('/dashboard__view_lot_order_limit_3') && leavesForChecking.contains('/dashboard__view_lot_order_limit_3')) {
      leavesForChecking.remove('/dashboard__view_lot_order_limit_3');
    } else if (rolePerms.contains('/dashboard__view_lot_order_limit_3') && leavesForChecking.contains('/dashboard__view_lot_order')) {
      leavesForChecking.remove('/dashboard__view_lot_order');
    }
    return leavesForChecking;
  }

  /// Tri-state value of a node (true = all, null = some, false = none) — same as v1.
  bool? _nodeValue(List<String> leavesForChecking, List<String> rolePerms) {
    final checkedCount = leavesForChecking.where((leaf) => rolePerms.contains(leaf)).length;
    bool? isChecked = false;
    if (checkedCount > 0) {
      isChecked = checkedCount == leavesForChecking.length ? true : null;
    }
    return isChecked;
  }

  // ── v2 presentation helpers ───────────────────────────────────────────────

  static Map<String, Set<String>> _snapshot(Map<String, List<String>> perms) =>
      {for (final e in perms.entries) e.key: e.value.toSet()};

  int _changesFor(String role) {
    final cur = (_permissions[role] ?? const <String>[]).toSet();
    final base = _baseline[role] ?? const <String>{};
    return cur.difference(base).length + base.difference(cur).length;
  }

  int get _pendingChanges {
    var n = 0;
    for (final r in {..._permissions.keys, ..._baseline.keys}) {
      n += _changesFor(r);
    }
    return n;
  }

  ({int granted, int total}) _statsFor(String role) {
    final rolePerms = _permissions[role] ?? const <String>[];
    var granted = 0, total = 0;
    for (final node in _permissionTree) {
      final leaves = _leavesForChecking(node, rolePerms);
      total += leaves.length;
      granted += leaves.where(rolePerms.contains).length;
    }
    return (granted: granted, total: total);
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (_expandedKeys.contains(key)) {
        _expandedKeys.remove(key);
      } else {
        _expandedKeys.add(key);
      }
    });
  }

  Iterable<String> _expandableKeys(List<PermissionNode> nodes) sync* {
    for (final n in nodes) {
      if (n.children.isNotEmpty || n.actions.isNotEmpty) yield n.key;
      yield* _expandableKeys(n.children);
    }
  }

  static const Map<String, ({IconData icon, Color tone})> _moduleLook = {
    '/dashboard': (icon: Icons.space_dashboard_rounded, tone: FxTokens.blue),
    '/vehicles': (icon: Icons.local_shipping_rounded, tone: FxTokens.emerald),
    '/vehicle-maintenances': (icon: Icons.build_circle_rounded, tone: FxTokens.amber),
    '/stations': (icon: Icons.ev_station_rounded, tone: FxTokens.cyan),
    'reports-group': (icon: Icons.bar_chart_rounded, tone: FxTokens.violet),
    'fleet-monitoring-group': (icon: Icons.local_gas_station_rounded, tone: FxTokens.emerald),
    '/concrete-quality': (icon: Icons.science_rounded, tone: FxTokens.amber),
    '/operations': (icon: Icons.factory_rounded, tone: FxTokens.slate),
    '/parking-idle-engine': (icon: Icons.power_settings_new_rounded, tone: FxTokens.orange),
    'tools-group': (icon: Icons.handyman_rounded, tone: FxTokens.indigo),
    '/ai-assistant': (icon: Icons.smart_toy_rounded, tone: FxTokens.cyan),
    'category-group': (icon: Icons.folder_copy_rounded, tone: FxTokens.violet),
    'user-manage-group': (icon: Icons.manage_accounts_rounded, tone: FxTokens.blue),
  };

  static const Map<String, String> _exclusiveHints = {
    '/dashboard__view_lot_order': 'Bật mục này sẽ tắt "Xem thứ tự lốt xe (chỉ 3 xe)"',
    '/dashboard__view_lot_order_limit_3': 'Bật mục này sẽ tắt "Xem thứ tự lốt xe"',
  };

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 760 ? (width - 720) / 2 : 14.w;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: widget.isTab
          ? null
          : AppBar(
              backgroundColor: t.bg,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              centerTitle: false,
              title: Text('Phân quyền vai trò', style: t.h1.copyWith(fontSize: 19.sp)),
            ),
      bottomNavigationBar: !_isLoading && _canEditPermissions ? _saveBar(t, side) : null,
      body: _isLoading ? _PermissionsSkeleton(side: side) : _content(t, side),
    );
  }

  Widget _content(FxTokens t, double side) {
    final rolePerms = _permissions[_selectedRole] ?? [];
    final stats = _statsFor(_selectedRole);
    final allExpandable = _expandableKeys(_permissionTree).toSet();
    final allExpanded = allExpandable.every(_expandedKeys.contains);

    return RefreshIndicator(
      onRefresh: _loadPermissions,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 10.h, 0, 24.h),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chi tiết quyền hạn', style: t.h2),
                SizedBox(height: 2.h),
                Text('Chọn một vai trò để chỉnh sửa quyền truy cập của họ.', style: t.small),
                SizedBox(height: 12.h),
              ],
            ),
          ),
          SizedBox(
            height: 64.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: side),
              itemCount: _availableRoles.length,
              separatorBuilder: (_, _) => SizedBox(width: 8.w),
              itemBuilder: (context, i) => _roleTile(t, _availableRoles[i]),
            ),
          ),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loadFailed)
                  const FxBanner(
                    tone: FxTokens.red,
                    icon: Icons.cloud_off_rounded,
                    title: 'Không tải được quyền hạn',
                    text: 'Kéo xuống để tải lại trước khi chỉnh sửa.',
                  ),
                if (!_canEditPermissions)
                  const FxBanner(
                    tone: FxTokens.amber,
                    icon: Icons.lock_outline_rounded,
                    text: 'Bạn chỉ có quyền xem. Cần quyền "Chỉnh sửa quyền hạn" để thay đổi.',
                  ),
                _overview(t, stats, allExpanded, allExpandable),
                for (final node in _permissionTree) _moduleCard(t, node, rolePerms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleTile(FxTokens t, String role) {
    final selected = role == _selectedRole;
    final tone = umRoleTone(role);
    final stats = _statsFor(role);
    final dirty = _changesFor(role) > 0;
    return Material(
      color: selected ? t.soft(FxTokens.blue) : t.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        side: BorderSide(
          color: selected ? FxTokens.blue.withValues(alpha: 0.55) : t.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedRole = role),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 8.h, 14.w, 8.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FxIconBadge(icon: umRoleIcon(role), tone: tone, size: 34),
                  if (dirty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: FxTokens.amber,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.card, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 10.w),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 140.w),
                    child: Text(
                      _roleNames[role] ?? role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.h3.copyWith(color: selected ? t.ink(FxTokens.blue) : t.text),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '${stats.granted}/${stats.total} quyền',
                    style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overview(FxTokens t, ({int granted, int total}) stats, bool allExpanded, Set<String> allExpandable) {
    final ratio = stats.total == 0 ? 0.0 : stats.granted / stats.total;
    return FxCard(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 6.w, 12.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Quyền của ${_roleNames[_selectedRole] ?? _selectedRole}',
                        style: t.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text('${stats.granted}/${stats.total}', style: t.num(13.sp, color: t.ink(FxTokens.blue))),
                  ],
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: t.track,
                    color: FxTokens.blue,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          TextButton.icon(
            onPressed: () => setState(() {
              if (allExpanded) {
                _expandedKeys.clear();
              } else {
                _expandedKeys.addAll(allExpandable);
              }
            }),
            icon: Icon(allExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded, size: 18.sp),
            label: Text(allExpanded ? 'Thu gọn' : 'Mở rộng'),
          ),
        ],
      ),
    );
  }

  /// Tri-state checkbox of a node — same widget, value and onChanged as v1.
  Widget _nodeCheckbox(PermissionNode node, bool? value) {
    return Checkbox(
      value: value,
      tristate: true,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onChanged: _canEditPermissions
          ? (val) {
              _toggleNodeState(_selectedRole, node, val ?? false);
            }
          : null,
    );
  }

  Widget _countPill(FxTokens t, int granted, int total, Color tone) {
    final full = total > 0 && granted == total;
    final none = granted == 0;
    return FxPill(
      label: '$granted/$total',
      tone: none ? FxTokens.slate : (full ? FxTokens.emerald : tone),
      icon: full ? Icons.check_rounded : null,
    );
  }

  Widget _moduleCard(FxTokens t, PermissionNode node, List<String> rolePerms) {
    final leaves = _leavesForChecking(node, rolePerms);
    final granted = leaves.where(rolePerms.contains).length;
    final value = _nodeValue(leaves, rolePerms);
    final hasSubItems = node.children.isNotEmpty || node.actions.isNotEmpty;
    final isExpanded = _expandedKeys.contains(node.key);
    final look = _moduleLook[node.key] ?? (icon: Icons.shield_outlined, tone: FxTokens.slate);

    final header = Padding(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, hasSubItems ? 6.w : 8.w, 10.h),
      child: Row(
        children: [
          FxIconBadge(icon: look.icon, tone: look.tone, size: 36),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.title, style: t.h3.copyWith(fontSize: 14.sp), maxLines: 2, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    _countPill(t, granted, leaves.length, look.tone),
                    if (hasSubItems) ...[
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          node.children.isNotEmpty ? '${node.children.length} nhóm' : '${node.actions.length} thao tác',
                          style: t.tiny,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (hasSubItems) ...[
            _nodeCheckbox(node, value),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, size: 22.sp, color: t.textMuted),
            ),
          ] else
            Switch(
              value: value == true,
              onChanged: _canEditPermissions ? (v) => _toggleNodeState(_selectedRole, node, v) : null,
            ),
        ],
      ),
    );

    return FxCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.only(bottom: 10.h),
      borderColor: value == false ? null : look.tone.withValues(alpha: t.dark ? 0.40 : 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: hasSubItems
                ? () => _toggleExpanded(node.key)
                : (_canEditPermissions ? () => _toggleNodeState(_selectedRole, node, value != true) : null),
            child: header,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: hasSubItems && isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, thickness: 1, color: t.divider),
                      SizedBox(height: 4.h),
                      ..._nodeBody(t, node, 0, rolePerms),
                      SizedBox(height: 6.h),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// Expanded content of a node: children first, then actions (same order as v1).
  List<Widget> _nodeBody(FxTokens t, PermissionNode node, int depth, List<String> rolePerms) {
    final out = <Widget>[];
    for (final child in node.children) {
      out.addAll(_childNode(t, child, depth + 1, rolePerms));
    }
    for (final action in node.actions) {
      final actionChecked = rolePerms.contains(action);
      out.add(_permRow(
        t,
        title: _permissionNames[action] ?? action,
        hint: _exclusiveHints[action],
        value: actionChecked,
        depth: depth + (node.children.isEmpty ? 0 : 1),
        onChanged: _canEditPermissions
            ? (val) {
                _togglePermission(_selectedRole, action, val);
              }
            : null,
      ));
    }
    return out;
  }

  /// A nested node (e.g. "Bảng công" inside "Công cụ").
  List<Widget> _childNode(FxTokens t, PermissionNode node, int depth, List<String> rolePerms) {
    final leaves = _leavesForChecking(node, rolePerms);
    final value = _nodeValue(leaves, rolePerms);
    final hasSubItems = node.children.isNotEmpty || node.actions.isNotEmpty;

    if (!hasSubItems) {
      // Leaf node: one key — v1 tri-state checkbox can only be on / off here.
      return [
        _permRow(
          t,
          title: node.title,
          value: value == true,
          depth: depth - 1,
          strong: true,
          onChanged: _canEditPermissions ? (v) => _toggleNodeState(_selectedRole, node, v) : null,
        ),
      ];
    }

    final isExpanded = _expandedKeys.contains(node.key);
    final granted = leaves.where(rolePerms.contains).length;
    final indent = (depth - 1) * 14.w;

    return [
      Padding(
        padding: EdgeInsets.fromLTRB(10.w + indent, 2.h, 10.w, 2.h),
        child: Material(
          color: t.cardAlt,
          borderRadius: BorderRadius.circular(12.r),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _toggleExpanded(node.key),
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.w, 6.h, 2.w, 6.h),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right_rounded, size: 20.sp, color: t.textMuted),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      node.title,
                      style: t.h3.copyWith(fontSize: 13.sp),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '$granted/${leaves.length}',
                    style: t.tiny.copyWith(fontWeight: FontWeight.w700, fontFeatures: FxTokens.tabular),
                  ),
                  _nodeCheckbox(node, value),
                ],
              ),
            ),
          ),
        ),
      ),
      if (isExpanded) ..._nodeBody(t, node, depth, rolePerms),
    ];
  }

  Widget _permRow(
    FxTokens t, {
    required String title,
    required bool value,
    required int depth,
    required ValueChanged<bool>? onChanged,
    String? hint,
    bool strong = false,
  }) {
    final indent = depth * 14.w;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18.w + indent, 2.h, 8.w, 2.h),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? FxTokens.emerald : t.border,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: (strong ? t.h3.copyWith(fontSize: 13.sp) : t.body.copyWith(fontSize: 12.5.sp))
                        .copyWith(color: value ? t.text : t.textMuted),
                  ),
                  if (hint != null) ...[
                    SizedBox(height: 1.h),
                    Text(hint, style: t.tiny.copyWith(color: t.textFaint)),
                  ],
                ],
              ),
            ),
            SizedBox(width: 6.w),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: value,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveBar(FxTokens t, double side) {
    final pending = _pendingChanges;
    final dirty = pending > 0;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.border)),
        boxShadow: t.dark
            ? null
            : const [BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(side, 10.h, side, 10.h),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: FxIconBadge(
                  key: ValueKey(dirty),
                  icon: dirty ? Icons.edit_note_rounded : Icons.cloud_done_rounded,
                  tone: dirty ? FxTokens.amber : FxTokens.emerald,
                  size: 36,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dirty ? '$pending thay đổi chưa lưu' : 'Không có thay đổi',
                      style: t.h3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      dirty ? 'Nhấn "Lưu thay đổi" để áp dụng' : 'Đã đồng bộ với máy chủ',
                      style: t.tiny,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              FilledButton.icon(
                onPressed: _isSaving ? null : _savePermissions,
                icon: _isSaving
                    ? SizedBox(width: 18.w, height: 18.w, child: const CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.save_rounded, size: 18.sp),
                label: const Text('Lưu thay đổi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionsSkeleton extends StatelessWidget {
  final double side;
  const _PermissionsSkeleton({required this.side});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, 14.h, side, 14.h),
      children: [
        FxSkeleton(height: 14.h, width: 150.w, radius: 6),
        SizedBox(height: 6.h),
        FxSkeleton(height: 10.h, width: 230.w, radius: 6),
        SizedBox(height: 14.h),
        Row(children: [
          Expanded(child: FxSkeleton(height: 52.h, radius: 14)),
          SizedBox(width: 8.w),
          Expanded(child: FxSkeleton(height: 52.h, radius: 14)),
          SizedBox(width: 8.w),
          Expanded(child: FxSkeleton(height: 52.h, radius: 14)),
        ]),
        SizedBox(height: 12.h),
        FxSkeleton(height: 62.h, radius: 18),
        for (var i = 0; i < 6; i++) ...[
          SizedBox(height: 10.h),
          FxSkeleton(height: 64.h, radius: 18),
        ],
      ],
    );
  }
}
