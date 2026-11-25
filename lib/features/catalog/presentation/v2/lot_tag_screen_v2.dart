import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/catalog/data/models/lot_tag_model.dart';
import 'package:nguyenanh/features/catalog/data/services/lot_tag_service.dart';
// The key slug + AI formula helpers are shared with v1 so both UIs always analyse tags the same way.
import 'package:nguyenanh/features/catalog/presentation/screens/lot_tag_screen.dart'
    show analyzeLotTagFormula, buildLotTagFormulaMessages, parseLotTagFormulaResponse, slugifyLotTagKey;
import 'package:nguyenanh/features/catalog/presentation/v2/catalog_ui_v2.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

/// "Tag lốt xe" (v2). Same constructor, state, permissions, paging, search, ranking and API calls as
/// `LotTagScreen`; only the widget tree is redesigned.
class LotTagScreenV2 extends StatefulWidget {
  const LotTagScreenV2({super.key});

  @override
  State<LotTagScreenV2> createState() => _LotTagScreenV2State();
}

class _LotTagScreenV2State extends State<LotTagScreenV2> {
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

  // ── Data & logic (verbatim from LotTagScreen) ─────────────────────────────

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
        _loadError = null;
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

  void _showFormModal({LotTagModel? item}) {
    showCatalogSheetV2(
      context,
      builder: (ctx) {
        return LotTagFormSheetV2(
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

  Future<void> _confirmDelete(LotTagModel item) async {
    final confirmed = await showCatalogDeleteDialogV2(context, message: 'Bạn có chắc muốn xóa tag lốt "${item.name}"?');
    if (!confirmed || !mounted) return;
    try {
      await _service.deleteLotTag(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Xóa thành công')));
      _fetchItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
    }
  }

  Map<int, int> _getRankByGroup() {
    final groups = _items.map((tag) => tag.sortGroup ?? 20).toSet().toList()..sort();
    final map = <int, int>{};
    for (int i = 0; i < groups.length; i++) {
      map[groups[i]] = i + 1;
    }
    return map;
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final side = catalogGutterV2(context);
    final rankMap = _getRankByGroup();

    return Scaffold(
      backgroundColor: t.bg,
      appBar: catalogAppBarV2(
        context,
        title: 'Tag lốt xe',
        subtitle: _isLoading
            ? catalogCountLabelV2(isLoading: true, count: 0, hasMore: false, noun: 'tag')
            : '${catalogCountLabelV2(isLoading: false, count: _items.length, hasMore: _hasMore, noun: 'tag')}'
                ' · ${rankMap.length} nhóm xếp',
        actions: [CatalogRefreshButtonV2(onPressed: () => _fetchItems())],
      ),
      floatingActionButton: _canCreate ? CatalogAddFabV2(onPressed: () => _showFormModal()) : null,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(side, 4.h, side, 4.h),
            child: CatalogSearchFieldV2(
              controller: _searchController,
              hint: 'Tìm kiếm tag lốt xe...',
              onChanged: _onSearchChanged,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
          Expanded(
            child: CatalogListV2<LotTagModel>(
              controller: _scrollController,
              items: _items,
              isLoading: _isLoading,
              isLoadingMore: _isLoadingMore,
              hasMore: _hasMore,
              error: _loadError,
              searchQuery: _searchQuery,
              emptyIcon: Icons.sell_outlined,
              emptyTitle: 'Chưa có tag lốt xe',
              listHint: _canUpdate ? 'Chạm để chỉnh sửa' : null,
              onAdd: _canCreate ? () => _showFormModal() : null,
              onRetry: () => _fetchItems(),
              onRefresh: () => _fetchItems(),
              header: _items.isEmpty
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: const FxBanner(
                        tone: FxTokens.blue,
                        icon: Icons.auto_awesome_rounded,
                        text: 'Mỗi tag thuộc một nhóm xếp do AI chốt từ mô tả luật. '
                            'Nhóm nhỏ hơn được gọi sớm hơn trong lốt xe.',
                      ),
                    ),
              itemBuilder: (context, item, index) {
                final groupVal = item.sortGroup ?? 20;
                final rank = rankMap[groupVal] ?? 1;
                return CatalogRowV2(
                  leading: CatalogIndexBadgeV2(label: '#${index + 1}'),
                  titleWidget: Row(
                    children: [
                      Flexible(child: LotTagChipV2(name: item.name, tagKey: item.key)),
                      SizedBox(width: 6.w),
                      FxPill(label: 'nhóm $rank', tone: FxTokens.blue, icon: Icons.layers_rounded),
                    ],
                  ),
                  subtitle: item.rule.isNotEmpty ? item.rule : null,
                  placeholder: 'Chưa có mô tả luật',
                  subtitleMaxLines: 3,
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

// ─── Add / edit sheet ───────────────────────────────────────────────────────

/// Add / edit sheet of a lot tag (v2): name + rule → AI analysis (with follow-up questions) → preview →
/// save. Same constructor, state and calls as `LotTagFormSheet`.
class LotTagFormSheetV2 extends StatefulWidget {
  final LotTagModel? editingTag;
  final List<LotTagModel> existingTags;
  final LotTagService service;
  final VoidCallback onSaved;

  const LotTagFormSheetV2({
    super.key,
    this.editingTag,
    required this.existingTags,
    required this.service,
    required this.onSaved,
  });

  @override
  State<LotTagFormSheetV2> createState() => _LotTagFormSheetV2State();
}

class _LotTagFormSheetV2State extends State<LotTagFormSheetV2> {
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

  // ── Logic (verbatim from LotTagFormSheet; v2 adds `mounted` guards after the awaits) ──

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
        existingTags: widget.existingTags.where((tag) => tag.id != widget.editingTag?.id).toList(),
        qaHistory: pendingQa,
      );

      final content = await analyzeLotTagFormula(messages);
      final formula = parseLotTagFormulaResponse(content);

      if (formula == null) {
        throw Exception('AI chưa phản hồi được. Vui lòng thử lại.');
      }

      if (!mounted) return; // v2 fix: the sheet may have been dismissed during the analysis
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
      if (!mounted) return; // v2 fix: v1 called setState here even after dispose
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi phân tích: $e')),
      );
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
          'sort_group': ?sortGroup,
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
      if (!mounted) return; // v2 fix: v1 called setState here even after dispose
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu tag: $e')),
      );
    }
  }

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final previewing = _preview != null;

    final modalTitle = _preview != null
        ? (widget.editingTag != null ? 'Xác nhận lưu tag' : 'Xác nhận tạo tag')
        : (widget.editingTag != null ? 'Sửa tag' : 'Thêm tag mới');

    final confirmLabel = widget.editingTag != null ? 'Xác nhận lưu' : 'Xác nhận tạo';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogSheetHeaderV2(
            icon: Icons.auto_awesome_rounded,
            tone: FxTokens.violet,
            title: modalTitle,
            subtitle: previewing
                ? 'Kiểm tra lại trước khi lưu'
                : 'AI đọc mô tả luật để chọn vị trí của tag trong lốt xe',
          ),
          _stepper(t, previewing),
          Divider(height: 1, thickness: 1, color: t.divider),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: previewing ? _buildPreview(t) : _buildForm(t),
            ),
          ),
          if (previewing)
            CatalogSheetActionsV2(
              secondaryLabel: 'Sửa lại',
              secondaryIcon: Icons.arrow_back_rounded,
              onSecondary: _saving ? null : () => setState(() => _preview = null),
              primaryLabel: confirmLabel,
              primaryIcon: Icons.check_rounded,
              onPrimary: _handleConfirm,
              busy: _saving,
              busyLabel: 'Đang lưu…',
            )
          else
            CatalogSheetActionsV2(
              secondaryLabel: 'Đóng',
              onSecondary: _analyzing ? null : () => Navigator.pop(context),
              primaryLabel: _aiQuestion != null ? 'Trả lời & xem tiếp' : 'Xem trước',
              primaryIcon: Icons.auto_awesome_rounded,
              onPrimary: _handleAnalyze,
              busy: _analyzing,
              busyLabel: 'Đang phân tích...',
            ),
        ],
      ),
    );
  }

  Widget _stepper(FxTokens t, bool previewing) {
    Widget step(int n, String label, {required bool active, required bool done}) {
      final on = active || done;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20.w,
            height: 20.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? FxTokens.blue : t.cardAlt,
              border: Border.all(color: on ? FxTokens.blue : t.border),
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 12.sp, color: Colors.white)
                : Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : t.textMuted,
                    ),
                  ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? t.text : t.textMuted,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
      child: Row(
        children: [
          step(1, 'Nhập thông tin', active: !previewing, done: previewing),
          Expanded(
            child: Container(
              height: 1.5,
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              color: previewing ? FxTokens.blue : t.border,
            ),
          ),
          step(2, 'Xác nhận', active: previewing, done: false),
        ],
      ),
    );
  }

  Widget _buildForm(FxTokens t) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogFieldV2(
            label: 'Tên tag',
            isRequired: true,
            child: TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: catalogInputV2(context, hint: 'Tên tag (vd: Về sớm)', icon: Icons.sell_outlined),
              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên tag' : null,
            ),
          ),
          CatalogFieldV2(
            label: 'Mô tả luật xếp',
            helper: 'Mô tả ảnh hưởng sắp xếp — AI sẽ đọc để chốt công thức xếp.',
            child: TextFormField(
              controller: _ruleController,
              decoration: catalogInputV2(
                context,
                hint: 'Vd: Xe này hôm sau xếp cuối lốt, đứng trước xe nghỉ',
              ).copyWith(hintMaxLines: 3),
              maxLines: 3,
            ),
          ),

          // AI follow-up question
          if (_aiQuestion != null)
            Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: t.soft(FxTokens.blue),
                borderRadius: BorderRadius.circular(FxTokens.rTile),
                border: Border.all(color: FxTokens.blue.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FxIconBadge(icon: Icons.help_outline_rounded, tone: FxTokens.blue, size: 28),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AI CẦN LÀM RÕ', style: t.overline.copyWith(color: t.ink(FxTokens.blue))),
                            SizedBox(height: 3.h),
                            Text(
                              _aiQuestion!,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: t.ink(FxTokens.blue),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  TextField(
                    controller: _answerController,
                    style: t.body,
                    textInputAction: TextInputAction.send,
                    decoration: catalogInputV2(
                      context,
                      hint: 'Trả lời để AI chốt công thức xếp',
                      icon: Icons.reply_rounded,
                    ).copyWith(fillColor: t.card),
                    onSubmitted: (_) => _handleAnalyze(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview(FxTokens t) {
    final rule = _preview!['rule'] as String;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: t.cardAlt,
            borderRadius: BorderRadius.circular(FxTokens.rTile),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPreviewRow(Icons.sell_outlined, 'Tên tag', _preview!['name'], isTagChip: true),
              Divider(height: 1, thickness: 1, color: t.divider),
              _buildPreviewRow(
                Icons.rule_rounded,
                'Mô tả luật xếp',
                rule.isNotEmpty ? rule : 'Chưa có mô tả luật',
                isItalicIfEmpty: rule.isEmpty,
              ),
              Divider(height: 1, thickness: 1, color: t.divider),
              _buildPreviewRow(Icons.format_list_numbered_rounded, 'Vị trí xếp lốt', _preview!['summary'], isHighlight: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
    bool isTagChip = false,
    bool isItalicIfEmpty = false,
  }) {
    final t = FxTokens.of(context);
    final Widget body;
    if (isTagChip) {
      body = Align(
        alignment: Alignment.centerLeft,
        child: LotTagChipV2(name: value, tagKey: widget.editingTag?.key ?? slugifyLotTagKey(value)),
      );
    } else if (isHighlight) {
      body = Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(color: t.soft(FxTokens.blue), borderRadius: BorderRadius.circular(10.r)),
        child: Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(fontSize: 13.5.sp, color: t.ink(FxTokens.blue), fontWeight: FontWeight.w600, height: 1.4),
        ),
      );
    } else {
      body = Text(
        value,
        style: isItalicIfEmpty
            ? t.body.copyWith(fontStyle: FontStyle.italic, color: t.textFaint)
            : t.body,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: Icon(icon, size: 16.sp, color: t.textFaint),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label.toUpperCase(), style: t.overline),
                SizedBox(height: 6.h),
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tag chip ───────────────────────────────────────────────────────────────

/// v2 tone of a lot tag — same key → colour mapping as v1's `getChipBgColor` / `getChipTextColor`,
/// expressed with design tokens so it works in dark mode.
Color lotTagToneV2(String key) => switch (key) {
      've_som' => FxTokens.green,
      'sua_chua' || 'nghi' => FxTokens.amber,
      'du_be_tong' => FxTokens.blue,
      'keo_bom_tinh' => FxTokens.violet,
      'truc_san_xuat' => FxTokens.cyan,
      'chay_bom' => FxTokens.indigo,
      _ => FxTokens.slate,
    };

class LotTagChipV2 extends StatelessWidget {
  final String name;
  final String tagKey;

  const LotTagChipV2({super.key, required this.name, required this.tagKey});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final tone = lotTagToneV2(tagKey);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: t.soft(tone),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: t.ink(tone), height: 1.25),
      ),
    );
  }
}
