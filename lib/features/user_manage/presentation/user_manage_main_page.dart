import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/user_manage/presentation/user_list_page.dart';
import 'package:nguyenanh/features/user_manage/presentation/permissions_page.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserManageMainPage extends StatefulWidget {
  const UserManageMainPage({super.key});

  @override
  State<UserManageMainPage> createState() => _UserManageMainPageState();
}

class _UserManageMainPageState extends State<UserManageMainPage> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: _canViewPermissions ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Quản lý người dùng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.outline,
            indicatorColor: colorScheme.primary,
            tabs: [
              const Tab(text: 'Tất cả người dùng'),
              if (_canViewPermissions) const Tab(text: 'Quyền hạn'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const UserListPage(isTab: true),
            if (_canViewPermissions) const PermissionsPage(isTab: true),
          ],
        ),
      ),
    );
  }
}
