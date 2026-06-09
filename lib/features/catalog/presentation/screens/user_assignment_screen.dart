import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/catalog/data/models/user_assignment_model.dart';
import 'package:nguyenanh/features/catalog/data/models/department_model.dart';
import 'package:nguyenanh/features/catalog/data/models/skill_model.dart';
import 'package:nguyenanh/features/catalog/data/services/user_assignment_service.dart';
import 'package:nguyenanh/features/catalog/data/services/department_service.dart';
import 'package:nguyenanh/features/catalog/data/services/skill_service.dart';
import 'package:nguyenanh/features/user_manage/data/models/user_manage_model.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

class UserAssignmentScreen extends StatefulWidget {
  const UserAssignmentScreen({super.key});

  @override
  State<UserAssignmentScreen> createState() => _UserAssignmentScreenState();
}

class _UserAssignmentScreenState extends State<UserAssignmentScreen> {
  final UserAssignmentService _service = UserAssignmentService();
  final UserManageService _userService = UserManageService();
  final DepartmentService _deptService = DepartmentService();
  final SkillService _skillService = SkillService();

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<UserAssignmentModel> _items = [];
  List<UserManageModel> _users = [];
  List<DepartmentModel> _depts = [];
  List<SkillModel> _skills = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 20;
  String _searchQuery = '';
  bool _isInitLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _scrollController.addListener(_onScroll);
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
      _fetchData(isLoadMore: true);
    }
  }

  Future<void> _fetchData({bool isLoadMore = false}) async {
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
      if (!_isInitLoaded) {
        final userRes = await _userService.getUsers(limit: 1000);
        _users = userRes['users'] as List<UserManageModel>? ?? [];
        _depts = await _deptService.getDepartments();
        _skills = await _skillService.getSkills();
        _isInitLoaded = true;
      }

      final items = await _service.getUserAssignments(page: _page, limit: _limit, search: _searchQuery);
      
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
        _fetchData();
      }
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm nhân sự...',
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

  void _showFormModal({UserAssignmentModel? item}) {
    final isEditing = item != null;
    int? selectedUserId = item?.userId != 0 ? item?.userId : null;
    int? selectedDeptId = item?.departmentId != 0 ? item?.departmentId : null;
    int? selectedSkillId = item?.skillId;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
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
                      isEditing ? 'Sửa phân công' : 'Thêm phân công nhân sự',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: AppSpacing.lgH),
                    DropdownButtonFormField<int>(
                      value: selectedUserId,
                      decoration: const InputDecoration(labelText: 'Nhân viên *'),
                      items: _users.map((u) => DropdownMenuItem(value: u.userId, child: Text(u.userFullName ?? u.username ?? ''))).toList(),
                      onChanged: (val) => setModalState(() => selectedUserId = val),
                      validator: (val) => val == null ? 'Vui lòng chọn nhân viên' : null,
                    ),
                    SizedBox(height: AppSpacing.mdH),
                    DropdownButtonFormField<int>(
                      value: selectedDeptId,
                      decoration: const InputDecoration(labelText: 'Bộ phận *'),
                      items: _depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                      onChanged: (val) => setModalState(() => selectedDeptId = val),
                      validator: (val) => val == null ? 'Vui lòng chọn bộ phận' : null,
                    ),
                    SizedBox(height: AppSpacing.mdH),
                    DropdownButtonFormField<int>(
                      value: selectedSkillId,
                      decoration: const InputDecoration(labelText: 'Tay nghề'),
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('Không có tay nghề')),
                        ..._skills.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: (val) => setModalState(() => selectedSkillId = val),
                    ),
                    SizedBox(height: AppSpacing.xlH),
                    ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(ctx);
                          final data = {
                            'user_id': selectedUserId,
                            'department_id': selectedDeptId,
                            if (selectedSkillId != null) 'skill_id': selectedSkillId,
                          };
                          try {
                            if (isEditing) {
                              await _service.updateUserAssignment(item.id, data);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
                            } else {
                              await _service.createUserAssignment(data);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm mới thành công')));
                            }
                            _fetchData();
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
      },
    );
  }

  void _confirmDelete(UserAssignmentModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa phân công của "${item.userFullName ?? item.userId}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.deleteUserAssignment(item.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa thành công')));
                _fetchData();
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
        title: const Text('Danh mục nhân sự'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchData(),
          ),
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
                    onRefresh: () => _fetchData(),
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
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.person, color: colorScheme.onSurfaceVariant),
                            ),
                            title: Text(item.userFullName ?? 'ID: ${item.userId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bộ phận: ${item.departmentName ?? item.departmentId}'),
                                if (item.skillName != null) Text('Tay nghề: ${item.skillName}', style: TextStyle(color: colorScheme.primary)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: colorScheme.primary),
                                  onPressed: () => _showFormModal(item: item),
                                ),
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
