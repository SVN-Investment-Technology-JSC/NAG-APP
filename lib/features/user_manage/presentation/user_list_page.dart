import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/user_manage/data/models/user_manage_model.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/user_manage/presentation/widgets/user_form_modal.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class UserListPage extends StatefulWidget {
  final bool isTab;
  const UserListPage({super.key, this.isTab = false});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
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

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchUsers();
    _scrollController.addListener(_onScroll);
  }

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

  Future<void> _fetchUsers({bool isLoadMore = false}) async {
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
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirm),
        content: Text('Bạn có chắc chắn muốn xóa người dùng ${user.userFullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: UserFormModal(
          user: user,
          onSuccess: _fetchUsers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: widget.isTab ? null : AppBar(
        title: Text('Quản lý người dùng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchUsers(),
              child: _users.isEmpty && !_isLoading
                  ? Center(child: Text('Không có dữ liệu', style: TextStyle(color: colorScheme.outline)))
                  : ListView.separated(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      itemCount: _users.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, index) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        if (index == _users.length) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ));
                        }

                        final user = _users[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(
                                user.userFullName.isNotEmpty ? user.userFullName[0].toUpperCase() : '?',
                                style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              user.userFullName,
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Icon(Icons.badge_rounded, size: 14.sp, color: colorScheme.outline),
                                    SizedBox(width: 4.w),
                                    Text(
                                      (_roleNames[user.role] ?? user.role).toUpperCase(),
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                                Row(
                                  children: [
                                    Icon(Icons.email_outlined, size: 14.sp, color: colorScheme.outline),
                                    SizedBox(width: 4.w),
                                    Expanded(
                                      child: Text(
                                        user.userEmail.isNotEmpty ? user.userEmail : 'Chưa cập nhật',
                                        style: TextStyle(color: colorScheme.outline, fontSize: 12.sp),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_canUpdate)
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: colorScheme.secondary),
                                    onPressed: () => _showUserModal(user: user),
                                  ),
                                if (_canDelete)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                                    onPressed: () => _deleteUser(user),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: _canCreate ? FloatingActionButton(
        onPressed: () => _showUserModal(),
        child: const Icon(Icons.add),
      ) : null,
    );
  }
}
