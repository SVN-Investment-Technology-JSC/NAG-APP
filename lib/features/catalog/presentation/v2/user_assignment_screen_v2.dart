import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/catalog/data/models/department_model.dart';
import 'package:nguyenanh/features/catalog/data/models/skill_model.dart';
import 'package:nguyenanh/features/catalog/data/models/user_assignment_model.dart';
import 'package:nguyenanh/features/catalog/data/services/department_service.dart';
import 'package:nguyenanh/features/catalog/data/services/skill_service.dart';
import 'package:nguyenanh/features/catalog/data/services/user_assignment_service.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/catalog_ui_v2.dart';
import 'package:nguyenanh/features/user_manage/data/models/user_manage_model.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

/// "Danh mục nhân sự" (v2). Same constructor, state, permissions, paging, search and API calls as
/// `UserAssignmentScreen`; only the widget tree is redesigned.
class UserAssignmentScreenV2 extends StatefulWidget {
  const UserAssignmentScreenV2({super.key});

  @override
  State<UserAssignmentScreenV2> createState() => _UserAssignmentScreenV2State();
}

class _UserAssignmentScreenV2State extends State<UserAssignmentScreenV2> {
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
  String? _loadError; // v2: shown in the empty state (v1 only showed a snackbar)

  String _userRole = '';
  bool _canCreate = false;
  bool _canUpdate = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _fetchData();
    _scrollController.addListener(_onScroll);
  }

  // ── Data & logic (verbatim from UserAssignmentScreen) ─────────────────────

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canCreate = _userRole == 'admin' || myPerms.contains('/configuration/user-assignments__create');
          _canUpdate = _userRole == 'admin' || myPerms.contains('/configuration/user-assignments__update');
          _canDelete = _userRole == 'admin' || myPerms.contains('/configuration/user-assignments__delete');
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
        _loadError = null;
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
          if (!isLoadMore) _loadError = '$e';
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

  void _showFormModal({UserAssignmentModel? item}) {
    final isEditing = item != null;
    int? selectedUserId = item?.userId != 0 ? item?.userId : null;
    int? selectedDeptId = item?.departmentId != 0 ? item?.departmentId : null;
    int? selectedSkillId = item?.skillId;
    final formKey = GlobalKey<FormState>();

    // v2 fix: a dropdown asserts when its value is missing from its items (e.g. a skill/department beyond
    // the first page that `getSkills()` / `getDepartments()` return). Keep the current value selectable
    // with the name the assignment already carries, so the form opens and saves the same ids as before.
    final userItems = <DropdownMenuItem<int>>[
      if (selectedUserId != null && !_users.any((u) => u.userId == selectedUserId))
        DropdownMenuItem(value: selectedUserId, child: _optionText(item?.userFullName ?? 'ID: $selectedUserId')),
      ..._users.map(
        (u) => DropdownMenuItem(value: u.userId, child: _optionText(u.userFullName.isNotEmpty ? u.userFullName : u.username)),
      ),
    ];
    final deptItems = <DropdownMenuItem<int>>[
      if (selectedDeptId != null && !_depts.any((d) => d.id == selectedDeptId))
        DropdownMenuItem(value: selectedDeptId, child: _optionText(item?.departmentName ?? 'ID: $selectedDeptId')),
      ..._depts.map((d) => DropdownMenuItem(value: d.id, child: _optionText(d.name))),
    ];
    final skillItems = <DropdownMenuItem<int>>[
      DropdownMenuItem<int>(value: null, child: _optionText('Không có tay nghề')),
      if (selectedSkillId != null && !_skills.any((s) => s.id == selectedSkillId))
        DropdownMenuItem(value: selectedSkillId, child: _optionText(item?.skillName ?? 'ID: $selectedSkillId')),
      ..._skills.map((s) => DropdownMenuItem(value: s.id, child: _optionText(s.name))),
    ];

    showCatalogSheetV2(
      context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return CatalogFormSheetV2(
              formKey: formKey,
              icon: Icons.badge_rounded,
              tone: FxTokens.violet,
              title: isEditing ? 'Sửa phân công' : 'Thêm phân công nhân sự',
              subtitle: isEditing
                  ? 'Cập nhật bộ phận và tay nghề của nhân viên'
                  : 'Gán nhân viên vào bộ phận và tay nghề',
              submitLabel: isEditing ? 'Lưu thay đổi' : 'Tạo mới',
              submitIcon: isEditing ? Icons.save_rounded : Icons.add_rounded,
              children: [
                CatalogFieldGroupV2(
                  title: 'Nhân sự',
                  children: [
                    CatalogFieldV2(
                      label: 'Nhân viên',
                      isRequired: true,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedUserId,
                        isExpanded: true,
                        style: Theme.of(context).textTheme.bodyLarge,
                        menuMaxHeight: 380.h,
                        borderRadius: BorderRadius.circular(14.r),
                        decoration: catalogInputV2(context, hint: 'Chọn nhân viên', icon: Icons.person_outline_rounded),
                        items: userItems,
                        onChanged: (val) => setModalState(() => selectedUserId = val),
                        validator: (val) => val == null ? 'Vui lòng chọn nhân viên' : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                CatalogFieldGroupV2(
                  title: 'Phân công',
                  children: [
                    CatalogFieldV2(
                      label: 'Bộ phận',
                      isRequired: true,
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedDeptId,
                        isExpanded: true,
                        style: Theme.of(context).textTheme.bodyLarge,
                        menuMaxHeight: 380.h,
                        borderRadius: BorderRadius.circular(14.r),
                        decoration: catalogInputV2(context, hint: 'Chọn bộ phận', icon: Icons.domain_rounded),
                        items: deptItems,
                        onChanged: (val) => setModalState(() => selectedDeptId = val),
                        validator: (val) => val == null ? 'Vui lòng chọn bộ phận' : null,
                      ),
                    ),
                    CatalogFieldV2(
                      label: 'Tay nghề',
                      child: DropdownButtonFormField<int>(
                        initialValue: selectedSkillId,
                        isExpanded: true,
                        style: Theme.of(context).textTheme.bodyLarge,
                        menuMaxHeight: 380.h,
                        borderRadius: BorderRadius.circular(14.r),
                        decoration: catalogInputV2(context, icon: Icons.workspace_premium_outlined),
                        items: skillItems,
                        onChanged: (val) => setModalState(() => selectedSkillId = val),
                      ),
                    ),
                  ],
                ),
              ],
              onSubmit: (sheetCtx) async {
                final data = {
                  'user_id': selectedUserId,
                  'department_id': selectedDeptId,
                  'skill_id': ?selectedSkillId,
                };
                try {
                  if (isEditing) {
                    await _service.updateUserAssignment(item.id, data);
                    if (sheetCtx.mounted) closeCatalogSheetV2(sheetCtx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
                  } else {
                    await _service.createUserAssignment(data);
                    if (sheetCtx.mounted) closeCatalogSheetV2(sheetCtx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(const SnackBar(content: Text('Thêm mới thành công')));
                  }
                  _fetchData();
                } catch (e) {
                  if (sheetCtx.mounted) closeCatalogSheetV2(sheetCtx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Lỗi lưu dữ liệu: $e')));
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _optionText(String text) => Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);

  Future<void> _confirmDelete(UserAssignmentModel item) async {
    final confirmed = await showCatalogDeleteDialogV2(
      context,
      message: 'Bạn có chắc muốn xóa phân công của "${item.userFullName ?? item.userId}"?',
    );
    if (!confirmed || !mounted) return;
    try {
      await _service.deleteUserAssignment(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa thành công')));
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
    }
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final side = catalogGutterV2(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: catalogAppBarV2(
        context,
        title: 'Danh mục nhân sự',
        subtitle: catalogCountLabelV2(
          isLoading: _isLoading,
          count: _items.length,
          hasMore: _hasMore,
          noun: 'phân công',
        ),
        actions: [CatalogRefreshButtonV2(onPressed: () => _fetchData())],
      ),
      floatingActionButton: _canCreate ? CatalogAddFabV2(onPressed: () => _showFormModal()) : null,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, 4.h, side, 4.h),
            child: CatalogSearchFieldV2(
              controller: _searchController,
              hint: 'Tìm kiếm nhân sự...',
              onChanged: _onSearchChanged,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
          Expanded(
            child: CatalogListV2<UserAssignmentModel>(
              controller: _scrollController,
              items: _items,
              isLoading: _isLoading,
              isLoadingMore: _isLoadingMore,
              hasMore: _hasMore,
              error: _loadError,
              searchQuery: _searchQuery,
              emptyIcon: Icons.people_alt_outlined,
              emptyTitle: 'Chưa có phân công nhân sự',
              listHint: _canUpdate ? 'Chạm để chỉnh sửa' : null,
              onAdd: _canCreate ? () => _showFormModal() : null,
              onRetry: () => _fetchData(),
              onRefresh: () => _fetchData(),
              itemBuilder: (context, item, index) {
                final name = item.userFullName ?? 'ID: ${item.userId}';
                return CatalogRowV2(
                  leading: CatalogAvatarV2(name: item.userFullName ?? '${item.userId}'),
                  title: name,
                  subtitle: 'Bộ phận: ${item.departmentName ?? item.departmentId}',
                  subtitleIcon: Icons.domain_rounded,
                  subtitleMaxLines: 1,
                  meta: [
                    if (item.skillName != null)
                      FxPill(
                        label: 'Tay nghề: ${item.skillName}',
                        tone: FxTokens.blue,
                        icon: Icons.workspace_premium_rounded,
                      ),
                  ],
                  onTap: _canUpdate ? () => _showFormModal(item: item) : null,
                  onEdit: _canUpdate ? () => _showFormModal(item: item) : null,
                  onDelete: _canDelete ? () => _confirmDelete(item) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
