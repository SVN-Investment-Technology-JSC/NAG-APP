import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

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
  
  final List<String> _availableRoles = ['manager', 'dispatcher', 'driver', 'user'];
  
  final Map<String, String> _roleNames = {
    'admin': 'Quản trị viên',
    'manager': 'Quản lý',
    'dispatcher': 'Điều phối xe',
    'driver': 'Tài xế',
    'user': 'Người dùng',
  };
  
  final Map<String, List<String>> _allModules = {
    '/dashboard': [
      '/dashboard__view',
      '/dashboard__sync_slots',
      '/dashboard__history',
      '/dashboard__checklog',
      '/dashboard__manual_sort',
      '/dashboard__view_map',
      '/dashboard__manual_camera_fallback',
      '/dashboard__system_settings',
    ],
    '/vehicles': [
      '/vehicles__view',
      '/vehicles__create',
      '/vehicles__update',
      '/vehicles__delete',
    ],
    '/vehicle-maintenances': [
      '/vehicle-maintenances__view',
      '/vehicle-maintenances__create',
      '/vehicle-maintenances__update',
      '/vehicle-maintenances__delete',
    ],
    '/vehicle-types': [
      '/vehicle-types__view',
      '/vehicle-types__create',
      '/vehicle-types__update',
      '/vehicle-types__delete',
    ],
    '/stations': [
      '/stations__view',
      '/stations__create',
      '/stations__update',
      '/stations__delete',
    ],
    '/reports': [
      '/reports/production',
      '/reports/fuel',
    ],
    '/tools': [
      '/meal-check',
      '/attendance',
      '/ai-assistant',
    ],
    '/user-manage': [
      '/user-manage__view',
      '/user-manage__create',
      '/user-manage__update',
      '/user-manage__delete',
    ],
    '/role-permissions': [
      '/role-permissions__view',
      '/role-permissions__update',
    ],
  };

  final Map<String, String> _moduleNames = {
    '/dashboard': 'Bảng điều khiển',
    '/vehicles': 'Quản lý phương tiện',
    '/vehicle-maintenances': 'Bảo trì xe',
    '/vehicle-types': 'Loại phương tiện',
    '/stations': 'Quản lý trạm',
    '/reports': 'Báo cáo phân tích',
    '/tools': 'Công cụ & Trợ lý',
    '/user-manage': 'Tất cả người dùng',
    '/role-permissions': 'Phân quyền vai trò',
  };

  final Map<String, String> _permissionNames = {
    '/dashboard__view': 'Xem',
    '/dashboard__sync_slots': 'Đồng bộ lốt xe',
    '/dashboard__history': 'Lịch sử lốt xe',
    '/dashboard__checklog': 'Nhật ký vận hành',
    '/dashboard__manual_sort': 'Sắp xếp thứ tự lốt xe',
    '/dashboard__view_map': 'Bản đồ',
    '/dashboard__manual_camera_fallback': 'Thao tác thủ công (camera sự cố)',
    '/dashboard__system_settings': 'Cấu hình vận hành',
    
    '/vehicles__view': 'Xem danh sách phương tiện',
    '/vehicles__create': 'Thêm phương tiện',
    '/vehicles__update': 'Sửa phương tiện',
    '/vehicles__delete': 'Xóa phương tiện',
    
    '/vehicle-maintenances__view': 'Xem dữ liệu bảo trì',
    '/vehicle-maintenances__create': 'Thêm bảo trì',
    '/vehicle-maintenances__update': 'Sửa bảo trì',
    '/vehicle-maintenances__delete': 'Xóa bảo trì',
    
    '/vehicle-types__view': 'Xem danh sách loại phương tiện',
    '/vehicle-types__create': 'Thêm loại phương tiện',
    '/vehicle-types__update': 'Sửa loại phương tiện',
    '/vehicle-types__delete': 'Xóa loại phương tiện',
    
    '/stations__view': 'Xem danh sách bãi/trạm',
    '/stations__create': 'Thêm bãi/trạm',
    '/stations__update': 'Sửa bãi/trạm',
    '/stations__delete': 'Xóa bãi/trạm',
    
    '/reports/production': 'Báo cáo sản xuất',
    '/reports/fuel': 'Báo cáo nhiên liệu',
    
    '/meal-check': 'Đăng ký cơm ca',
    '/attendance': 'Chấm công',
    '/ai-assistant': 'Trợ lý AI',
    
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
      final data = await _userService.getPermissions();
      setState(() {
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
    for (final role in _permissions.keys) {
      final rolePerms = _permissions[role]?.toSet() ?? {};
      for (final entry in _allModules.entries) {
        final moduleKey = entry.key;
        final modulePerms = entry.value;
        if (modulePerms.isEmpty) continue;
        
        // Unconditionally remove the parent key, we only send children
        rolePerms.remove(moduleKey);
      }
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

  void _toggleModule(String role, String moduleKey, bool isGranted) {
    if (!_canEditPermissions) return;
    setState(() {
      if (_permissions[role] == null) {
        _permissions[role] = [];
      }
      final modulePerms = _allModules[moduleKey] ?? [];
      if (isGranted) {
        for (var perm in modulePerms) {
          if (!_permissions[role]!.contains(perm)) {
            _permissions[role]!.add(perm);
          }
        }
      } else {
        for (var perm in modulePerms) {
          _permissions[role]!.remove(perm);
        }
      }
    });
  }

  bool? _getModuleCheckState(String role, String moduleKey) {
    final rolePerms = _permissions[role] ?? [];
    final modulePerms = _allModules[moduleKey] ?? [];
    
    if (modulePerms.isEmpty) return false;
    
    int checkedCount = 0;
    for (var perm in modulePerms) {
      if (rolePerms.contains(perm)) checkedCount++;
    }
    
    if (checkedCount == 0) return false;
    if (checkedCount == modulePerms.length) return true;
    return null; // Trạng thái indeterminate (null) nếu chỉ chọn một vài cái
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
              tooltip: 'Lưu quyền',
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
                  child: _buildRolePermissionsTab(_selectedRole, colorScheme),
                ),
              ],
            ),
    );
  }

  Widget _buildRolePermissionsTab(String role, ColorScheme colorScheme) {
    final rolePerms = _permissions[role] ?? [];
    return RefreshIndicator(
      onRefresh: _loadPermissions,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 80.h),
        itemCount: _allModules.length,
        itemBuilder: (context, index) {
          final moduleEntry = _allModules.entries.elementAt(index);
          final moduleKey = moduleEntry.key;
          final modulePermsList = moduleEntry.value;
          
          final moduleState = _getModuleCheckState(role, moduleKey);

          return Card(
            elevation: 0,
            margin: EdgeInsets.only(bottom: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Module Header
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12.r), bottom: Radius.zero),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      _moduleNames[moduleKey] ?? moduleKey,
                      style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                    value: moduleState,
                    tristate: true,
                    activeColor: colorScheme.primary,
                    onChanged: _canEditPermissions ? (value) {
                      _toggleModule(role, moduleKey, value ?? false);
                    } : null,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                
                // Permissions List
                Padding(
                  padding: EdgeInsets.only(left: 32.w, right: 16.w, top: 8.h, bottom: 8.h),
                  child: Column(
                    children: modulePermsList.map((perm) {
                      final isGranted = rolePerms.contains(perm);
                      return CheckboxListTile(
                        title: Text(_permissionNames[perm] ?? perm, style: TextStyle(fontSize: 14.sp)),
                        value: isGranted,
                        dense: true,
                        activeColor: colorScheme.primary,
                        onChanged: _canEditPermissions ? (val) => _togglePermission(role, perm, val ?? false) : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
