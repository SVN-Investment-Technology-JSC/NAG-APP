import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/catalog/data/models/department_model.dart';
import 'package:nguyenanh/features/catalog/data/services/department_service.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/catalog_ui_v2.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

/// "Quản lý bộ phận" (v2). Same constructor, state, permissions, paging, search and API calls as
/// `DepartmentScreen`; only the widget tree is redesigned.
class DepartmentScreenV2 extends StatefulWidget {
  const DepartmentScreenV2({super.key});

  @override
  State<DepartmentScreenV2> createState() => _DepartmentScreenV2State();
}

class _DepartmentScreenV2State extends State<DepartmentScreenV2> {
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
  String? _loadError; // v2: shown in the empty state (v1 only showed a snackbar)

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

  // ── Data & logic (verbatim from DepartmentScreen) ─────────────────────────

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
        _loadError = null;
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
        _fetchItems();
      }
    });
  }

  void _showFormModal({DepartmentModel? item}) {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final descController = TextEditingController(text: item?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showCatalogSheetV2(
      context,
      builder: (ctx) => CatalogFormSheetV2(
        formKey: formKey,
        icon: Icons.domain_rounded,
        tone: FxTokens.indigo,
        title: isEditing ? 'Sửa bộ phận' : 'Thêm bộ phận',
        subtitle: isEditing ? 'Cập nhật thông tin "${item.name}"' : 'Nhập thông tin bộ phận mới',
        submitLabel: isEditing ? 'Lưu thay đổi' : 'Tạo mới',
        submitIcon: isEditing ? Icons.save_rounded : Icons.add_rounded,
        children: [
          CatalogFieldGroupV2(
            title: 'Thông tin chung',
            children: [
              CatalogFieldV2(
                label: 'Tên bộ phận',
                isRequired: true,
                child: TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: catalogInputV2(ctx, hint: 'VD: Điều độ', icon: Icons.label_outline_rounded),
                  validator: (val) => val == null || val.isEmpty ? 'Vui lòng nhập tên' : null,
                ),
              ),
              CatalogFieldV2(
                label: 'Mô tả',
                child: TextFormField(
                  controller: descController,
                  decoration: catalogInputV2(ctx, hint: 'Ghi chú thêm (không bắt buộc)'),
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ],
        onSubmit: (sheetCtx) async {
          final data = {
            'department_name': nameController.text.trim(),
            'department_description': descController.text.trim(),
            'department_root': item?.rootId ?? 0,
          };
          try {
            if (isEditing) {
              await _service.updateDepartment(item.id, data);
              if (sheetCtx.mounted) closeCatalogSheetV2(sheetCtx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
            } else {
              await _service.createDepartment(data);
              if (sheetCtx.mounted) closeCatalogSheetV2(sheetCtx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm mới thành công')));
            }
            _fetchItems();
          } catch (e) {
            if (sheetCtx.mounted) closeCatalogSheetV2(sheetCtx);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lưu dữ liệu: $e')));
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(DepartmentModel item) async {
    final confirmed = await showCatalogDeleteDialogV2(context, message: 'Bạn có chắc muốn xóa "${item.name}"?');
    if (!confirmed || !mounted) return;
    try {
      await _service.deleteDepartment(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa thành công')));
      _fetchItems();
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
        title: 'Quản lý bộ phận',
        subtitle: catalogCountLabelV2(
          isLoading: _isLoading,
          count: _items.length,
          hasMore: _hasMore,
          noun: 'bộ phận',
        ),
        actions: [CatalogRefreshButtonV2(onPressed: () => _fetchItems())],
      ),
      floatingActionButton: _canCreate ? CatalogAddFabV2(onPressed: () => _showFormModal()) : null,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, 4.h, side, 4.h),
            child: CatalogSearchFieldV2(
              controller: _searchController,
              hint: 'Tìm kiếm bộ phận...',
              onChanged: _onSearchChanged,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
          Expanded(
            child: CatalogListV2<DepartmentModel>(
              controller: _scrollController,
              items: _items,
              isLoading: _isLoading,
              isLoadingMore: _isLoadingMore,
              hasMore: _hasMore,
              error: _loadError,
              searchQuery: _searchQuery,
              emptyIcon: Icons.domain_disabled_rounded,
              emptyTitle: 'Chưa có bộ phận',
              listHint: _canUpdate ? 'Chạm để chỉnh sửa' : null,
              onAdd: _canCreate ? () => _showFormModal() : null,
              onRetry: () => _fetchItems(),
              onRefresh: () => _fetchItems(),
              itemBuilder: (context, item, index) => CatalogRowV2(
                leading: const FxIconBadge(icon: Icons.domain_rounded, tone: FxTokens.indigo, size: 40),
                title: item.name,
                subtitle: item.description?.isNotEmpty == true ? item.description! : null,
                placeholder: 'Không có mô tả',
                onTap: _canUpdate ? () => _showFormModal(item: item) : null,
                onEdit: _canUpdate ? () => _showFormModal(item: item) : null,
                onDelete: _canDelete ? () => _confirmDelete(item) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
