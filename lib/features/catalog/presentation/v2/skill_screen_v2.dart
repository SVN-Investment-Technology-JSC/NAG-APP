import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/catalog/data/models/skill_model.dart';
import 'package:nguyenanh/features/catalog/data/services/skill_service.dart';
import 'package:nguyenanh/features/catalog/presentation/v2/catalog_ui_v2.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

/// "Quản lý tay nghề" (v2). Same constructor, state, permissions, paging, search and API calls as
/// `SkillScreen`; only the widget tree is redesigned.
class SkillScreenV2 extends StatefulWidget {
  const SkillScreenV2({super.key});

  @override
  State<SkillScreenV2> createState() => _SkillScreenV2State();
}

class _SkillScreenV2State extends State<SkillScreenV2> {
  final SkillService _service = SkillService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<SkillModel> _items = [];
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

  // ── Data & logic (verbatim from SkillScreen) ─────────────────────────

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canCreate = _userRole == 'admin' || myPerms.contains('/configuration/skills__create');
          _canUpdate = _userRole == 'admin' || myPerms.contains('/configuration/skills__update');
          _canDelete = _userRole == 'admin' || myPerms.contains('/configuration/skills__delete');
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
      final items = await _service.getSkills(page: _page, limit: _limit, search: _searchQuery);
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

  void _showFormModal({SkillModel? item}) {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final descController = TextEditingController(text: item?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showCatalogSheetV2(
      context,
      builder: (ctx) => CatalogFormSheetV2(
        formKey: formKey,
        icon: Icons.workspace_premium_rounded,
        tone: FxTokens.amber,
        title: isEditing ? 'Sửa tay nghề' : 'Thêm tay nghề',
        subtitle: isEditing ? 'Cập nhật thông tin "${item.name}"' : 'Nhập thông tin tay nghề mới',
        submitLabel: isEditing ? 'Lưu thay đổi' : 'Tạo mới',
        submitIcon: isEditing ? Icons.save_rounded : Icons.add_rounded,
        children: [
          CatalogFieldGroupV2(
            title: 'Thông tin chung',
            children: [
              CatalogFieldV2(
                label: 'Tên tay nghề',
                isRequired: true,
                child: TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: catalogInputV2(ctx, hint: 'VD: Lái xe bồn', icon: Icons.label_outline_rounded),
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
            'skill_name': nameController.text.trim(),
            'skill_description': descController.text.trim(),
          };
          try {
            if (isEditing) {
              await _service.updateSkill(item.id, data);
              if (sheetCtx.mounted) closeCatalogSheetV2(sheetCtx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
            } else {
              await _service.createSkill(data);
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

  Future<void> _confirmDelete(SkillModel item) async {
    final confirmed = await showCatalogDeleteDialogV2(context, message: 'Bạn có chắc muốn xóa "${item.name}"?');
    if (!confirmed || !mounted) return;
    try {
      await _service.deleteSkill(item.id);
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
        title: 'Quản lý tay nghề',
        subtitle: catalogCountLabelV2(
          isLoading: _isLoading,
          count: _items.length,
          hasMore: _hasMore,
          noun: 'tay nghề',
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
              hint: 'Tìm kiếm tay nghề...',
              onChanged: _onSearchChanged,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
          Expanded(
            child: CatalogListV2<SkillModel>(
              controller: _scrollController,
              items: _items,
              isLoading: _isLoading,
              isLoadingMore: _isLoadingMore,
              hasMore: _hasMore,
              error: _loadError,
              searchQuery: _searchQuery,
              emptyIcon: Icons.workspace_premium_outlined,
              emptyTitle: 'Chưa có tay nghề',
              listHint: _canUpdate ? 'Chạm để chỉnh sửa' : null,
              onAdd: _canCreate ? () => _showFormModal() : null,
              onRetry: () => _fetchItems(),
              onRefresh: () => _fetchItems(),
              itemBuilder: (context, item, index) => CatalogRowV2(
                leading: const FxIconBadge(icon: Icons.workspace_premium_rounded, tone: FxTokens.amber, size: 40),
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
