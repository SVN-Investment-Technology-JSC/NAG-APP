import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/catalog/data/models/department_model.dart';
import 'package:nguyenanh/features/catalog/data/services/department_service.dart';

class DepartmentScreen extends StatefulWidget {
  const DepartmentScreen({super.key});

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  final DepartmentService _service = DepartmentService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<DepartmentModel> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 20;
  String _searchQuery = '';

  final UserManageService _userManageService = UserManageService();
  String _userRole = '';
  bool _canCreate = false;
  bool _canUpdate = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchItems();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canCreate = _userRole == 'admin' || myPerms.contains('/configuration/departments__create');
          _canUpdate = _userRole == 'admin' || myPerms.contains('/configuration/departments__update');
          _canDelete = _userRole == 'admin' || myPerms.contains('/configuration/departments__delete');
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        !_isLoading &&
        _hasMore) {
      _fetchItems(isLoadMore: true);
    }
  }

  Future<void> _fetchItems({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _page = 1;
        _hasMore = true;
      });
    }

    try {
      final items = await _service.getDepartments(page: _page, limit: _limit, search: _searchQuery);
      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _items.addAll(items);
          } else {
            _items = items;
          }
          _hasMore = items.length == _limit;
          if (_hasMore) _page++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery != query) {
        _searchQuery = query;
        _fetchItems();
      }
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm bộ phận...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  void _showFormModal({DepartmentModel? item}) {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final descController = TextEditingController(text: item?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isEditing ? 'Sửa bộ phận' : 'Thêm bộ phận',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.lgH),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Tên bộ phận *'),
                  validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập tên' : null,
                ),
                SizedBox(height: AppSpacing.mdH),
                TextFormField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  maxLines: 3,
                ),
                SizedBox(height: AppSpacing.xlH),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx);
                      final data = {
                        'department_name': nameController.text.trim(),
                        'department_description': descController.text.trim(),
                        'department_root': item?.rootId ?? 0,
                      };
                      try {
                        if (isEditing) {
                          await _service.updateDepartment(item.id, data);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
                        } else {
                          await _service.createDepartment(data);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm mới thành công')));
                        }
                        _fetchItems();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lưu dữ liệu: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14.h)),
                  child: Text(isEditing ? 'Lưu thay đổi' : 'Tạo mới'),
                ),
                SizedBox(height: AppSpacing.lgH),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(DepartmentModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.deleteDepartment(item.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa thành công')));
                _fetchItems();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý bộ phận'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchItems(),
          ),
          if (_canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showFormModal(),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _fetchItems(),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.w),
                      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        final item = _items[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          elevation: 1,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.secondaryContainer,
                              child: Icon(Icons.domain_rounded, color: colorScheme.onSecondaryContainer),
                            ),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(item.description?.isNotEmpty == true ? item.description! : 'Không có mô tả'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_canUpdate)
                                  IconButton(
                                    icon: Icon(Icons.edit, color: colorScheme.primary),
                                    onPressed: () => _showFormModal(item: item),
                                  ),
                                if (_canDelete)
                                  IconButton(
                                    icon: Icon(Icons.delete, color: colorScheme.error),
                                    onPressed: () => _confirmDelete(item),
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
    );
  }
}
