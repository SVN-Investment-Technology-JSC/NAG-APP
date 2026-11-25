import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/user_manage/data/permission_catalog.dart';

// PermissionNode now lives in the shared catalog (mirror of the web's permission tree).
export 'package:nguyenanh/features/user_manage/data/permission_catalog.dart' show PermissionNode;

class PermissionsPage extends StatefulWidget {
  final bool isTab;
  const PermissionsPage({super.key, this.isTab = false});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
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

  @override
  void initState() {
    super.initState();
    _selectedRole = _availableRoles.first;
    _loadPermissions();
  }

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
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  List<Widget> _buildTreeWidgets(List<PermissionNode> nodes, int depth, List<String> rolePerms, ColorScheme colorScheme) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      final leaves = _getAllLeafPermissions(node);
      final leavesForChecking = leaves.toList();
      if (!rolePerms.contains('/dashboard__view_lot_order_limit_3') && leavesForChecking.contains('/dashboard__view_lot_order_limit_3')) {
        leavesForChecking.remove('/dashboard__view_lot_order_limit_3');
      } else if (rolePerms.contains('/dashboard__view_lot_order_limit_3') && leavesForChecking.contains('/dashboard__view_lot_order')) {
        leavesForChecking.remove('/dashboard__view_lot_order');
      }
      final checkedCount = leavesForChecking.where((leaf) => rolePerms.contains(leaf)).length;
      bool? isChecked = false;
      if (checkedCount > 0) {
        isChecked = checkedCount == leavesForChecking.length ? true : null;
      }

      final hasSubItems = node.children.isNotEmpty || node.actions.isNotEmpty;
      final isExpanded = _expandedKeys.contains(node.key);

      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: (depth * 12).w, bottom: 2.h),
          child: Row(
            children: [
              if (hasSubItems)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    color: colorScheme.primary,
                    size: 22.sp,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedKeys.remove(node.key);
                      } else {
                        _expandedKeys.add(node.key);
                      }
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                )
              else
                SizedBox(width: 32.w),
              Expanded(
                child: CheckboxListTile(
                  title: Text(
                    node.title,
                    style: TextStyle(
                      fontWeight: depth == 0 ? FontWeight.bold : FontWeight.w600,
                      fontSize: depth == 0 ? 14.sp : 13.sp,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  value: isChecked,
                  tristate: true,
                  activeColor: colorScheme.primary,
                  onChanged: _canEditPermissions
                      ? (val) {
                          _toggleNodeState(_selectedRole, node, val ?? false);
                        }
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ),
      );

      if (hasSubItems && isExpanded) {
        if (node.children.isNotEmpty) {
          widgets.addAll(_buildTreeWidgets(node.children, depth + 1, rolePerms, colorScheme));
        }
        if (node.actions.isNotEmpty) {
          for (final action in node.actions) {
            final actionChecked = rolePerms.contains(action);
            widgets.add(
              Padding(
                padding: EdgeInsets.only(left: ((depth + 1) * 12 + 32).w),
                child: CheckboxListTile(
                  title: Text(
                    _permissionNames[action] ?? action,
                    style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                  ),
                  value: actionChecked,
                  dense: true,
                  activeColor: colorScheme.primary,
                  onChanged: _canEditPermissions
                      ? (val) {
                          _togglePermission(_selectedRole, action, val ?? false);
                        }
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          }
        }
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: widget.isTab ? null : AppBar(
        title: Text('Phân quyền vai trò', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
        centerTitle: true,
      ),
      floatingActionButton: !_isLoading && _canEditPermissions
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _savePermissions,
              icon: _isSaving 
                  ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Lưu thay đổi'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            )
          : null,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                  child: DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Chọn vai trò',
                      labelStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    ),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: colorScheme.primary),
                    items: _availableRoles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          _roleNames[role] ?? role,
                          style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadPermissions,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 100.h),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chi tiết quyền hạn',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Chọn một vai trò để chỉnh sửa quyền truy cập của họ.',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              ..._buildTreeWidgets(_permissionTree, 0, _permissions[_selectedRole] ?? [], colorScheme),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
