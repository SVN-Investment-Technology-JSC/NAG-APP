import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

class PermissionNode {
  final String key;
  final String title;
  final List<String> actions;
  final List<PermissionNode> children;

  PermissionNode({
    required this.key,
    required this.title,
    this.actions = const [],
    this.children = const [],
  });
}

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

  final List<PermissionNode> _permissionTree = [
    PermissionNode(
      key: '/dashboard',
      title: 'Bảng điều khiển',
      actions: [
        '/dashboard__view',
        '/dashboard__order_detail',
        '/dashboard__sync_slots',
        '/dashboard__history',
        '/dashboard__checklog',
        '/dashboard__manual_sort',
        '/dashboard__view_map',
        '/dashboard__view_yard_vehicles',
        '/dashboard__view_lot_order',
        '/dashboard__manual_camera_fallback',
        '/dashboard__system_settings',
      ],
    ),
    PermissionNode(
      key: '/vehicles',
      title: 'Quản lý phương tiện',
      actions: [
        '/vehicles__view',
        '/vehicles__create',
        '/vehicles__update',
        '/vehicles__delete',
      ],
    ),
    PermissionNode(
      key: '/vehicle-maintenances',
      title: 'Bảo trì xe',
      actions: [
        '/vehicle-maintenances__view',
        '/vehicle-maintenances__create',
        '/vehicle-maintenances__update',
        '/vehicle-maintenances__delete',
        '/vehicle-maintenances__submit',
        '/vehicle-maintenances__dispatch_review',
        '/vehicle-maintenances__production_approve',
      ],
    ),
    PermissionNode(
      key: '/stations',
      title: 'Quản lý trạm',
      actions: [
        '/stations__view',
        '/stations__create',
        '/stations__update',
        '/stations__delete',
      ],
    ),
    PermissionNode(
      key: 'reports-group',
      title: 'Báo cáo phân tích',
      children: [
        PermissionNode(key: '/reports/production', title: 'Báo cáo sản xuất'),
        PermissionNode(key: '/reports/fuel', title: 'Báo cáo nhiên liệu'),
      ],
    ),
    PermissionNode(
      key: '/parking-idle-engine',
      title: 'Giám sát nổ máy',
      actions: [
        '/parking-idle-engine__view',
        '/parking-idle-engine__settings',
      ],
    ),
    PermissionNode(
      key: 'tools-group',
      title: 'Công cụ',
      children: [
        PermissionNode(
          key: '/calendar',
          title: 'Xem lịch âm/dương',
          actions: ['/calendar__view'],
        ),
        PermissionNode(
          key: '/meal-check',
          title: 'Đăng ký cơm ca',
        ),
        PermissionNode(
          key: '/work-attendance',
          title: 'Bảng công',
          actions: [
            '/work-attendance__view',
            '/work-attendance__update',
          ],
        ),
        PermissionNode(
          key: '/work-arrangements',
          title: 'Bố trí công việc',
          actions: [
            '/work-arrangements__view',
            '/work-arrangements__update',
          ],
        ),
        PermissionNode(
          key: '/work-arrangements/lot-tag-requests',
          title: 'Đơn xin bận',
          actions: [
            '/work-arrangements/lot-tag-requests__view',
            '/work-arrangements/lot-tag-requests__create',
            '/work-arrangements/lot-tag-requests__review',
            '/work-arrangements/lot-tag-requests__cancel',
            '/work-arrangements/lot-tag-requests__delete',
          ],
        ),
      ],
    ),
    PermissionNode(
      key: '/ai-assistant',
      title: 'Trợ lý AI',
    ),
    PermissionNode(
      key: 'category-group',
      title: 'Danh mục',
      children: [
        PermissionNode(
          key: '/vehicle-types',
          title: 'Loại phương tiện',
          actions: [
            '/vehicle-types__view',
            '/vehicle-types__create',
            '/vehicle-types__update',
            '/vehicle-types__delete',
          ],
        ),
        PermissionNode(
          key: '/configuration/departments',
          title: 'Quản lý bộ phận',
          actions: [
            '/configuration/departments__view',
            '/configuration/departments__create',
            '/configuration/departments__update',
            '/configuration/departments__assign_users',
            '/configuration/departments__delete',
          ],
        ),
        PermissionNode(
          key: '/configuration/skills',
          title: 'Quản lý tay nghề',
          actions: [
            '/configuration/skills__view',
            '/configuration/skills__create',
            '/configuration/skills__update',
            '/configuration/skills__delete',
          ],
        ),
        PermissionNode(
          key: '/configuration/user-assignments',
          title: 'Danh mục nhân sự',
          actions: [
            '/configuration/user-assignments__view',
            '/configuration/user-assignments__create',
            '/configuration/user-assignments__update',
            '/configuration/user-assignments__delete',
          ],
        ),
        PermissionNode(
          key: '/configuration/works',
          title: 'Quản lý công việc',
          actions: [
            '/configuration/works__view',
            '/configuration/works__create',
            '/configuration/works__update',
            '/configuration/works__delete',
          ],
        ),
        PermissionNode(
          key: '/configuration/lot-tags',
          title: 'Tag lốt xe',
          actions: [
            '/configuration/lot-tags__view',
            '/configuration/lot-tags__create',
            '/configuration/lot-tags__update',
            '/configuration/lot-tags__delete',
          ],
        ),
      ],
    ),
    PermissionNode(
      key: 'user-manage-group',
      title: 'Quản lý người dùng',
      children: [
        PermissionNode(
          key: '/user-manage',
          title: 'Tất cả người dùng',
          actions: [
            '/user-manage__view',
            '/user-manage__create',
            '/user-manage__update',
            '/user-manage__delete',
          ],
        ),
        PermissionNode(
          key: '/role-permissions',
          title: 'Phân quyền vai trò',
          actions: [
            '/role-permissions__view',
            '/role-permissions__update',
          ],
        ),
      ],
    ),
  ];

  static const Map<String, String> _permissionNames = {
    '/dashboard__view': 'Xem thông tin chung',
    '/dashboard__order_detail': 'Xem chi tiết các chuyến xe (đơn hàng)',
    '/dashboard__sync_slots': 'Thao tác đồng bộ lốt xe',
    '/dashboard__history': 'Xem lịch sử lốt xe',
    '/dashboard__checklog': 'Xem nhật ký vận hành',
    '/dashboard__manual_sort': 'Thao tác sắp xếp thứ tự lốt xe',
    '/dashboard__view_map': 'Xem bản đồ',
    '/dashboard__view_yard_vehicles': 'Xem xe trong bãi',
    '/dashboard__view_lot_order': 'Xem thứ tự lốt xe',
    '/dashboard__manual_camera_fallback': 'Thao tác cho xe vào/xuất trạm (camera sự cố)',
    '/dashboard__system_settings': 'Cấu hình vận hành',
    
    '/vehicles__view': 'Xem danh sách phương tiện',
    '/vehicles__create': 'Thêm phương tiện',
    '/vehicles__update': 'Sửa phương tiện',
    '/vehicles__delete': 'Xóa phương tiện',
    
    '/vehicle-maintenances__view': 'Xem dữ liệu bảo trì',
    '/vehicle-maintenances__create': 'Thêm bảo trì',
    '/vehicle-maintenances__update': 'Sửa bảo trì',
    '/vehicle-maintenances__delete': 'Xóa bảo trì',
    '/vehicle-maintenances__submit': 'Gửi phiếu bảo trì',
    '/vehicle-maintenances__dispatch_review': 'Kiểm tra bảo trì',
    '/vehicle-maintenances__production_approve': 'Phê duyệt bảo trì',

    '/parking-idle-engine__view': 'Xem giám sát nổ máy trong bãi',
    '/parking-idle-engine__settings': 'Cấu hình cảnh báo nổ máy',
    
    '/vehicle-types__view': 'Xem danh sách loại phương tiện',
    '/vehicle-types__create': 'Thêm loại phương tiện',
    '/vehicle-types__update': 'Sửa loại phương tiện',
    '/vehicle-types__delete': 'Xóa loại phương tiện',

    '/configuration/departments__view': 'Xem danh sách bộ phận',
    '/configuration/departments__create': 'Thêm bộ phận',
    '/configuration/departments__update': 'Sửa bộ phận',
    '/configuration/departments__assign_users': 'Gán nhân sự vào bộ phận',
    '/configuration/departments__delete': 'Xóa bộ phận',

    '/configuration/skills__view': 'Xem danh sách tay nghề',
    '/configuration/skills__create': 'Thêm tay nghề',
    '/configuration/skills__update': 'Sửa tay nghề',
    '/configuration/skills__delete': 'Xóa tay nghề',

    '/configuration/user-assignments__view': 'Xem danh mục nhân sự',
    '/configuration/user-assignments__create': 'Thêm nhân sự',
    '/configuration/user-assignments__update': 'Sửa nhân sự',
    '/configuration/user-assignments__delete': 'Xóa nhân sự',

    '/configuration/works__view': 'Xem danh sách công việc',
    '/configuration/works__create': 'Thêm công việc',
    '/configuration/works__update': 'Sửa công việc',
    '/configuration/works__delete': 'Xóa công việc',

    '/configuration/lot-tags__view': 'Xem danh sách tag lốt',
    '/configuration/lot-tags__create': 'Thêm tag lốt',
    '/configuration/lot-tags__update': 'Sửa tag lốt',
    '/configuration/lot-tags__delete': 'Xóa tag lốt',

    '/stations__view': 'Xem danh sách bãi/trạm',
    '/stations__create': 'Thêm bãi/trạm',
    '/stations__update': 'Sửa bãi/trạm',
    '/stations__delete': 'Xóa bãi/trạm',
    
    '/reports/production': 'Báo cáo sản xuất',
    '/reports/fuel': 'Báo cáo nhiên liệu',
    
    '/calendar__view': 'Xem lịch âm/dương',
    '/meal-check': 'Đăng ký cơm ca',
    '/work-attendance__view': 'Xem bảng công',
    '/work-attendance__update': 'Cập nhật nghỉ nửa ngày',
    '/work-arrangements__view': 'Xem phân công',
    '/work-arrangements__update': 'Cập nhật phân công',
    '/ai-assistant': 'Trợ lý AI',
    '/attendance': 'Chấm công',
    
    '/work-arrangements/lot-tag-requests__view': 'Xem đơn xin bận',
    '/work-arrangements/lot-tag-requests__create': 'Tạo đơn xin bận',
    '/work-arrangements/lot-tag-requests__review': 'Duyệt/từ chối đơn xin bận',
    '/work-arrangements/lot-tag-requests__cancel': 'Hủy đơn xin bận',
    '/work-arrangements/lot-tag-requests__delete': 'Xóa đơn xin bận',
    
    '/user-manage__view': 'Xem danh sách người dùng',
    '/user-manage__create': 'Thêm người dùng',
    '/user-manage__update': 'Sửa người dùng',
    '/user-manage__delete': 'Xóa người dùng',
    
    '/role-permissions__view': 'Xem quyền hạn',
    '/role-permissions__update': 'Chỉnh sửa quyền hạn',
  };

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
    
    final allParentKeys = <String>{
      '/dashboard',
      '/vehicles',
      '/vehicle-maintenances',
      '/stations',
      'reports-group',
      '/parking-idle-engine',
      'tools-group',
      '/calendar',
      '/work-attendance',
      '/work-arrangements',
      '/work-arrangements/lot-tag-requests',
      'category-group',
      '/vehicle-types',
      '/configuration/departments',
      '/configuration/skills',
      '/configuration/user-assignments',
      '/configuration/works',
      '/configuration/lot-tags',
      'user-manage-group',
      '/user-manage',
      '/role-permissions',
    };

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
    setState(() {
      if (_permissions[role] == null) {
        _permissions[role] = [];
      }
      if (isGranted) {
        for (var leaf in leaves) {
          if (!_permissions[role]!.contains(leaf)) {
            _permissions[role]!.add(leaf);
          }
        }
      } else {
        for (var leaf in leaves) {
          _permissions[role]!.remove(leaf);
        }
      }
    });
  }

  void _togglePermission(String role, String perm, bool isGranted) {
    if (!_canEditPermissions) return;
    setState(() {
      if (_permissions[role] == null) {
        _permissions[role] = [];
      }
      if (isGranted) {
        if (!_permissions[role]!.contains(perm)) {
          _permissions[role]!.add(perm);
        }
      } else {
        _permissions[role]!.remove(perm);
      }
    });
  }

  List<Widget> _buildTreeWidgets(List<PermissionNode> nodes, int depth, List<String> rolePerms, ColorScheme colorScheme) {
    final widgets = <Widget>[];
    for (final node in nodes) {
      final leaves = _getAllLeafPermissions(node);
      final checkedCount = leaves.where((leaf) => rolePerms.contains(leaf)).length;
      bool? isChecked = false;
      if (checkedCount > 0) {
        isChecked = checkedCount == leaves.length ? true : null;
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
