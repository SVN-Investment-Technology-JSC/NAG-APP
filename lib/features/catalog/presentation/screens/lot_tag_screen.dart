import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/catalog/data/models/lot_tag_model.dart';
import 'package:nguyenanh/features/catalog/data/services/lot_tag_service.dart';

class LotTagScreen extends StatefulWidget {
  const LotTagScreen({super.key});

  @override
  State<LotTagScreen> createState() => _LotTagScreenState();
}

class _LotTagScreenState extends State<LotTagScreen> {
  final LotTagService _service = LotTagService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<LotTagModel> _items = [];
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
    _userRole = (prefs.getString('user_role') ?? '').toLowerCase();
    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canCreate = _userRole == 'admin' || myPerms.contains('/configuration/lot-tags__create');
          _canUpdate = _userRole == 'admin' || myPerms.contains('/configuration/lot-tags__update');
          _canDelete = _userRole == 'admin' || myPerms.contains('/configuration/lot-tags__delete');
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
      final items = await _service.getLotTags(page: _page, limit: _limit, search: _searchQuery);
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
          hintText: 'Tìm kiếm tag lốt xe...',
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
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

  void _showFormModal({LotTagModel? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) {
        return LotTagFormSheet(
          editingTag: item,
          existingTags: _items,
          service: _service,
          onSaved: () {
            _fetchItems();
          },
        );
      },
    );
  }

  void _confirmDelete(LotTagModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa tag lốt "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.deleteLotTag(item.id);
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

  Map<int, int> _getRankByGroup() {
    final groups = _items.map((tag) => tag.sortGroup ?? 20).toSet().toList()..sort();
    final map = <int, int>{};
    for (int i = 0; i < groups.length; i++) {
      map[groups[i]] = i + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rankMap = _getRankByGroup();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag lốt xe'),
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
                        final groupVal = item.sortGroup ?? 20;
                        final rank = rankMap[groupVal] ?? 1;

                        return Card(
                          margin: EdgeInsets.only(bottom: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          elevation: 1,
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.surfaceContainerHighest,
                              radius: 18.r,
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            title: Wrap(
                              spacing: 8.w,
                              runSpacing: 4.h,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: getChipBgColor(item.key),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: getChipTextColor(item.key),
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    'nhóm $rank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade800,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: EdgeInsets.only(top: 6.h),
                              child: Text(
                                item.rule.isNotEmpty ? item.rule : 'Chưa có mô tả luật',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontStyle: item.rule.isEmpty ? FontStyle.italic : null,
                                  color: item.rule.isEmpty ? Colors.grey : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_canUpdate)
                                  IconButton(
                                    icon: Icon(Icons.edit_note_rounded, color: colorScheme.primary),
                                    onPressed: () => _showFormModal(item: item),
                                  ),
                                if (_canDelete)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
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

class LotTagFormSheet extends StatefulWidget {
  final LotTagModel? editingTag;
  final List<LotTagModel> existingTags;
  final LotTagService service;
  final VoidCallback onSaved;

  const LotTagFormSheet({
    super.key,
    this.editingTag,
    required this.existingTags,
    required this.service,
    required this.onSaved,
  });

  @override
  State<LotTagFormSheet> createState() => _LotTagFormSheetState();
}

class _LotTagFormSheetState extends State<LotTagFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ruleController;
  final _answerController = TextEditingController();

  bool _analyzing = false;
  bool _saving = false;
  String? _aiQuestion;
  final List<Map<String, String>> _qaHistory = [];
  Map<String, dynamic>? _preview;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editingTag?.name ?? '');
    _ruleController = TextEditingController(text: widget.editingTag?.rule ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ruleController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _handleAnalyze() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final rule = _ruleController.text.trim();

    String key = widget.editingTag?.key ?? '';
    if (widget.editingTag == null) {
      key = slugifyLotTagKey(name);
      if (key.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập tên tag hợp lệ')),
        );
        return;
      }
      if (widget.existingTags.any((tag) => tag.key == key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag này đã tồn tại')),
        );
        return;
      }
    }

    final ruleChanged = widget.editingTag == null || widget.editingTag!.rule.trim() != rule;
    if (!ruleChanged) {
      setState(() {
        _preview = {
          'name': name,
          'rule': rule,
          'key': key,
          'sortGroup': widget.editingTag?.sortGroup,
          'summary': 'Giữ nguyên vị trí hiện tại (không đổi luật)',
        };
      });
      return;
    }

    setState(() => _analyzing = true);

    try {
      final pendingQa = [..._qaHistory];
      if (_aiQuestion != null && _answerController.text.trim().isNotEmpty) {
        pendingQa.add({
          'question': _aiQuestion!,
          'answer': _answerController.text.trim(),
        });
      }

      final messages = buildLotTagFormulaMessages(
        name: name,
        rule: rule,
        existingTags: widget.existingTags
            .where((tag) => tag.id != widget.editingTag?.id)
            .toList(),
        qaHistory: pendingQa,
      );

      final content = await analyzeLotTagFormula(messages);
      final formula = parseLotTagFormulaResponse(content);

      if (formula == null) {
        throw Exception('AI chưa phản hồi được. Vui lòng thử lại.');
      }

      if (formula['status'] == 'question') {
        setState(() {
          _qaHistory.clear();
          _qaHistory.addAll(pendingQa);
          _aiQuestion = formula['question'];
          _answerController.clear();
          _analyzing = false;
        });
      } else if (formula['status'] == 'ok') {
        setState(() {
          _aiQuestion = null;
          _answerController.clear();
          _qaHistory.clear();
          _preview = {
            'name': name,
            'rule': rule,
            'key': key,
            'sortGroup': formula['sort_group'],
            'summary': formula['summary'],
          };
          _analyzing = false;
        });
      }
    } catch (e) {
      setState(() => _analyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi phân tích: $e')),
        );
      }
    }
  }

  Future<void> _handleConfirm() async {
    if (_preview == null) return;
    setState(() => _saving = true);
    try {
      final name = _preview!['name'] as String;
      final rule = _preview!['rule'] as String;
      final key = _preview!['key'] as String;
      final sortGroup = _preview!['sortGroup'] as int?;

      if (widget.editingTag != null) {
        await widget.service.updateLotTag(widget.editingTag!.id, {
          'lot_tag_name': name,
          'lot_tag_rule': rule,
          if (sortGroup != null) 'sort_group': sortGroup,
        });
      } else {
        final maxOrder = widget.existingTags.fold<int>(
          0,
          (max, tag) => tag.displayOrder != null && tag.displayOrder! > max ? tag.displayOrder! : max,
        );
        await widget.service.createLotTag({
          'lot_tag_key': key,
          'lot_tag_name': name,
          'lot_tag_rule': rule,
          'sort_group': sortGroup ?? 20, // DEFAULT_LOT_TAG_GROUP is 20
          'display_order': maxOrder + 1,
        });
      }
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu tag: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final modalTitle = _preview != null
        ? (widget.editingTag != null ? 'Xác nhận lưu tag' : 'Xác nhận tạo tag')
        : (widget.editingTag != null ? 'Sửa tag' : 'Thêm tag mới');

    final confirmLabel = widget.editingTag != null ? 'Xác nhận lưu' : 'Xác nhận tạo';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.blue.shade600, size: 22.sp),
                SizedBox(width: 8.w),
                Text(
                  modalTitle,
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lgH),

            if (_preview != null) ...[
              // Preview Screen
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  'Kiểm tra lại trước khi lưu:',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewRow('Tên tag', _preview!['name'], isTagChip: true),
                    const Divider(height: 16),
                    _buildPreviewRow('Mô tả luật xếp', _preview!['rule'].isNotEmpty ? _preview!['rule'] : 'Chưa có mô tả luật', isItalicIfEmpty: _preview!['rule'].isEmpty),
                    const Divider(height: 16),
                    _buildPreviewRow('Vị trí xếp lốt', _preview!['summary'], isHighlight: true),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xlH),

              // Preview Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => setState(() => _preview = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Sửa lại'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    onPressed: _saving ? null : _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(confirmLabel),
                  ),
                ],
              ),
            ] else ...[
              // Form Input Screen
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên tag *',
                        hintText: 'Tên tag (vd: Về sớm)',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên tag' : null,
                    ),
                    SizedBox(height: AppSpacing.mdH),
                    TextFormField(
                      controller: _ruleController,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả luật xếp',
                        hintText: 'Mô tả ảnh hưởng sắp xếp — AI sẽ đọc. Vd: Xe này hôm sau xếp cuối lốt, đứng trước xe nghỉ',
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: AppSpacing.mdH),

                    // AI Question Section if available
                    if (_aiQuestion != null) ...[
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.blue),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    _aiQuestion!,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            TextField(
                              controller: _answerController,
                              decoration: const InputDecoration(
                                hintText: 'Trả lời để AI chốt công thức xếp',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onSubmitted: (_) => _handleAnalyze(),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.mdH),
                    ],
                    SizedBox(height: AppSpacing.xlH),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: _analyzing ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          ),
                          child: const Text('Đóng'),
                        ),
                        SizedBox(width: 12.w),
                        ElevatedButton.icon(
                          onPressed: _analyzing ? null : _handleAnalyze,
                          icon: _analyzing
                              ? Container(
                                  width: 16.w,
                                  height: 16.w,
                                  margin: EdgeInsets.only(right: 4.w),
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.auto_awesome_rounded),
                          label: Text(_analyzing
                              ? 'Đang phân tích...'
                              : (_aiQuestion != null ? 'Trả lời & xem tiếp' : 'Xem trước')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: AppSpacing.lgH),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool isHighlight = false, bool isTagChip = false, bool isItalicIfEmpty = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          if (isTagChip)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: getChipBgColor(widget.editingTag?.key ?? slugifyLotTagKey(value)),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: getChipTextColor(widget.editingTag?.key ?? slugifyLotTagKey(value)),
                ),
              ),
            )
          else if (isHighlight)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontStyle: isItalicIfEmpty ? FontStyle.italic : null,
                color: isItalicIfEmpty ? Colors.grey : theme.colorScheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}

// Global Helpers for LotTag Key Generation & AI analysis
String _removeDiacritics(String str) {
  const withDia = 'áàảãạâấầẩẫậăắằẳẵặđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ';
  const withoutDia = 'aaaaaaaaaaaaaaaaadeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy';
  for (int i = 0; i < withDia.length; i++) {
    str = str.replaceAll(withDia[i], withoutDia[i]);
    str = str.replaceAll(withDia[i].toUpperCase(), withoutDia[i].toUpperCase());
  }
  return str;
}

String slugifyLotTagKey(String name) {
  String v = _removeDiacritics(name).toLowerCase();
  v = v.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (v.length > 40) {
    v = v.substring(0, 40);
  }
  return v;
}

Color getChipBgColor(String key) {
  switch (key) {
    case 've_som':
      return Colors.green.shade50;
    case 'sua_chua':
    case 'nghi':
      return Colors.amber.shade50;
    case 'du_be_tong':
      return Colors.blue.shade50;
    case 'keo_bom_tinh':
      return Colors.purple.shade50;
    case 'truc_san_xuat':
      return Colors.teal.shade50;
    case 'chay_bom':
      return Colors.indigo.shade50;
    case 'lam_viec_khac':
    default:
      return Colors.grey.shade100;
  }
}

Color getChipTextColor(String key) {
  switch (key) {
    case 've_som':
      return Colors.green.shade900;
    case 'sua_chua':
    case 'nghi':
      return Colors.amber.shade900;
    case 'du_be_tong':
      return Colors.blue.shade900;
    case 'keo_bom_tinh':
      return Colors.purple.shade900;
    case 'truc_san_xuat':
      return Colors.teal.shade900;
    case 'chay_bom':
      return Colors.indigo.shade900;
    case 'lam_viec_khac':
    default:
      return Colors.grey.shade800;
  }
}

List<Map<String, dynamic>> buildLotTagFormulaMessages({
  required String name,
  required String rule,
  required List<LotTagModel> existingTags,
  required List<Map<String, String>> qaHistory,
}) {
  final existingList = existingTags.map((tag) => {
    'ten': tag.name,
    'luat': tag.rule,
    'sort_group': tag.sortGroup ?? 20,
  }).toList();

  final payload = {
    'tag_moi': {'ten': name, 'luat': rule},
    'danh_muc_hien_co': existingList,
    if (qaHistory.isNotEmpty)
      'hoi_dap_da_co': qaHistory.map((qa) => {
        'hoi': qa['question'] ?? '',
        'dap': qa['answer'] ?? '',
      }).toList(),
  };

  const systemPrompt = '''
Bạn là bộ phân tích luật xếp lốt xe bồn cho trạm trộn bê tông.
Mỗi tag trạng thái xe có một CÔNG THỨC XẾP cố định là số nguyên sort_group (1-99):
- Số càng NHỎ xe càng được gọi SỚM (đứng đầu lốt).
- Mốc cố định: xe KHÔNG có tag thuộc nhóm 20.
- Tag kiểu 'giữ nguyên vị trí / theo thực tế / điều độ tự xếp / theo bố trí' cũng thuộc nhóm 20.
- Có thể chen giữa hai nhóm hiện có bằng số ở giữa (vd 35 nằm giữa 30 và 40).
- NGHĨA NGHIỆP VỤ (bắt buộc theo): 'về sớm / đi sớm' = ĐẦU lốt (nhóm nhỏ, khoảng 10). 'xin nghỉ / nghỉ' = CUỐI CÙNG (nhóm lớn nhất). 'trước xe nghỉ' nghĩa là GẦN CUỐI (ngay trước nhóm nghỉ), TUYỆT ĐỐI KHÔNG phải đầu lốt. 'làm việc khác / chạy bơm / trực sản xuất / trực chốt' = về cuối lốt nhưng đứng TRƯỚC xe nghỉ, và SAU nhóm chạy hàng bình thường (nhóm 20).
- Nếu luật nhắc tới loại xe/tag CHƯA có trong danh mục (vd 'trước xe nghỉ' mà chưa có tag nghỉ), hãy suy luận theo nghĩa nghiệp vụ trên (nghỉ ở cuối) — ĐỪNG đặt nhầm về đầu lốt.
- CHỈ xếp tag HIỆN TẠI. TUYỆT ĐỐI KHÔNG hỏi/không đề xuất tạo tag khác, không hỏi sort_group của tag chưa tồn tại. Nếu tag tham chiếu chưa có, cứ đặt theo nghĩa nghiệp vụ và ghi rõ trong summary — KHÔNG bỏ cuộc, luôn trả về JSON hợp lệ (ok hoặc question).
- Nếu luật tag mới TƯƠNG ĐƯƠNG một tag đã có (cùng hướng, không nói rõ trước/sau, vd cả hai đều 'đưa ra sau') → ĐỪNG tự tách thành nhóm khác. Hãy HỎI LẠI: hai tag gọi CÙNG ĐỢT (chung nhóm) hay tag nào ra sau/xa hơn?
- Chỉ gán sort_group KHÁC nhau khi luật nêu RÕ thứ tự tương đối (đứng trước/sau, xa hơn; 'cuối cùng / sau cùng' xa hơn 'gần cuối').
- Chỉ gán CHUNG sort_group khi chắc chắn hai tag gọi cùng đợt (không cần phân biệt trước/sau).
- Được HỎI NHIỀU VÒNG, mỗi vòng MỘT câu hỏi ngắn, cho tới khi rõ.
Nhiệm vụ: đọc mô tả luật của TAG MỚI, so với danh mục tag hiện có, và chốt sort_group.
Chỉ trả về status:'ok' khi đã CHẮC CHẮN (cùng nhóm hay trước/sau) so với mọi tag cùng vùng; còn nghi ngờ thì hỏi tiếp.
Nếu đã đủ rõ:
  → trả về {"status":"ok","sort_group":N,"summary":"1 câu tiếng Việt mô tả vị trí (vd: Xếp sau Trực sản xuất, trước Chạy bơm)"}.
Nếu còn mơ hồ (chưa rõ đứng trước/sau tag nào, hoặc chưa rõ tag nào xa nhất):
  → trả về {"status":"question","question":"MỘT câu hỏi ngắn tiếng Việt để làm rõ (vd: Tag này nằm xa nhất hay đứng trước tag Nghỉ?)"}.
Chỉ trả về DUY NHẤT một JSON hợp lệ, không viết thêm chữ nào khác.
''';

  return [
    {'role': 'system', 'content': systemPrompt},
    {'role': 'user', 'content': jsonEncode(payload)},
  ];
}

String? _extractJsonBlock(String text) {
  final cleaned = text.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '');
  final start = cleaned.indexOf('{');
  if (start < 0) return null;

  int depth = 0;
  bool inString = false;
  bool escaped = false;
  for (int i = start; i < cleaned.length; i++) {
    final char = cleaned[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == '\\') {
      if (inString) escaped = true;
      continue;
    }
    if (char == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return cleaned.substring(start, i + 1);
      }
    }
  }
  return null;
}

Map<String, dynamic>? parseLotTagFormulaResponse(String text) {
  final block = _extractJsonBlock(text);
  if (block == null) return null;
  try {
    final parsed = jsonDecode(block);
    if (parsed is Map) {
      if (parsed['status'] == 'question') {
        return {
          'status': 'question',
          'question': parsed['question']?.toString().trim() ?? '',
        };
      }
      final rawGroup = double.tryParse(parsed['sort_group']?.toString() ?? parsed['group']?.toString() ?? '');
      int? sortGroup;
      if (rawGroup != null && rawGroup.isFinite) {
        sortGroup = rawGroup.round().clamp(1, 99);
      }
      return {
        'status': 'ok',
        'sort_group': sortGroup,
        'summary': parsed['summary']?.toString().trim() ?? '',
      };
    }
  } catch (_) {}
  return null;
}

Future<String> analyzeLotTagFormula(List<Map<String, dynamic>> messages) async {
  try {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 30);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    final response = await dio.post(
      'https://api.svnagentic.site/v1/chat/completions',
      data: {
        'model': 'Qwopus3.6-35B-A3B-v1-MTP-Q6_K.gguf',
        'messages': messages,
        'stream': false,
        'temperature': 0.2,
        'max_tokens': 3000,
      },
    );
    final choices = response.data['choices'] as List?;
    if (choices != null && choices.isNotEmpty) {
      final content = choices[0]['message']?['content'] ?? choices[0]['text'] ?? '';
      return content.toString();
    }
    return '';
  } catch (e) {
    throw Exception('Lỗi gọi AI phân tích: $e');
  }
}
