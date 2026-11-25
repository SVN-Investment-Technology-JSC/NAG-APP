import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/data/services/work_arrangement_service.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/wa_widgets_v2.dart';

/// v2 of `WorkAttendanceManager` ("Chấm công" tab). Same constructor, sub-tabs, state, API calls,
/// filters and status rules; only the widget tree is redesigned.
class WorkAttendanceManagerV2 extends StatefulWidget {
  final bool readOnly;
  const WorkAttendanceManagerV2({super.key, this.readOnly = false});

  @override
  State<WorkAttendanceManagerV2> createState() => _WorkAttendanceManagerV2State();
}

class _WorkAttendanceManagerV2State extends State<WorkAttendanceManagerV2> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final WorkArrangementService _service;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _service = WorkArrangementService(ApiClient.dio);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 4.h),
          child: WaPillTabBar(
            controller: _tabController,
            dense: true,
            tabs: const [
              (icon: Icons.fact_check_outlined, label: 'Chấm công ngày'),
              (icon: Icons.calendar_month_rounded, label: 'Tổng quan tháng'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _DailyMarkingViewV2(service: _service, readOnly: widget.readOnly),
              _MonthlyOverviewViewV2(service: _service),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Status options (same values / labels as v1) ────────────────────────────

const _statusOptions = [
  (value: 'working', label: 'Đi làm', tone: FxTokens.emerald),
  (value: 'off_morning', label: 'Sáng', tone: FxTokens.amber),
  (value: 'off_afternoon', label: 'Chiều', tone: FxTokens.amber),
  (value: 'off_full', label: 'Cả ngày', tone: FxTokens.red),
];

Color _statusTone(String status) => switch (status) {
  'off_full' => FxTokens.red,
  'off_morning' || 'off_afternoon' => FxTokens.amber,
  _ => FxTokens.emerald,
};

// ─── Daily marking ──────────────────────────────────────────────────────────

class _DailyMarkingViewV2 extends StatefulWidget {
  final WorkArrangementService service;
  final bool readOnly;
  const _DailyMarkingViewV2({required this.service, this.readOnly = false});

  @override
  State<_DailyMarkingViewV2> createState() => _DailyMarkingViewV2State();
}

class _DailyMarkingViewV2State extends State<_DailyMarkingViewV2> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  WorkAttendanceBootstrap? _data;

  String _searchQuery = '';
  String? _selectedDepartment;
  String? _selectedSkill;

  // v2 presentation only: keeps the search text when the field scrolls out of the list.
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Logic (from v1; `mounted` guards added — v1 called setState after dispose when the tab changed mid-load)

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.service.getAttendanceBootstrap(_dateStr);
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (_data == null) return;
    setState(() => _isSaving = true);
    try {
      final savedDraft = await widget.service.saveAttendanceDraft(_data!.draft);
      if (!mounted) return;
      setState(() {
        _data = WorkAttendanceBootstrap(
          workDate: _data!.workDate,
          personnel: _data!.personnel,
          isAttendanceMarked: true,
          draft: savedDraft,
        );
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu thành công')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu thất bại')));
      }
    }
  }

  void _setStatus(int userId, String status) {
    if (_data == null) return;
    final currentDraft = _data!.draft;
    final currentStatuses = currentDraft.userStatuses.toList();

    currentStatuses.removeWhere((e) => e.userId == userId);
    if (status != 'working') {
      currentStatuses.add(UserDayStatus(userId: userId, status: status));
    }

    setState(() {
      _data = WorkAttendanceBootstrap(
        workDate: _data!.workDate,
        personnel: _data!.personnel,
        isAttendanceMarked: _data!.isAttendanceMarked,
        draft: WorkAttendanceDraft(workDate: currentDraft.workDate, userStatuses: currentStatuses),
      );
    });
  }

  void _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (date != null && date != _selectedDate) {
      setState(() => _selectedDate = date);
      _loadData();
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    if (_isLoading) {
      return const _DailySkeleton();
    }

    final data = _data;
    if (data == null) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: FxEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Không tải được dữ liệu chấm công',
            message: 'Kiểm tra kết nối mạng rồi thử lại.',
            action: FilledButton.tonalIcon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại'),
            ),
          ),
        ),
      );
    }

    final personnel = data.personnel;

    // Stats calculation (same as v1)
    int total = personnel.length;
    int offCount = 0;
    double halfCount = 0;
    for (var s in data.draft.userStatuses) {
      if (s.status == 'off_full') {
        offCount++;
      } else if (s.status == 'off_morning' || s.status == 'off_afternoon') {
        halfCount += 0.5;
      }
    }
    double working = total - offCount - halfCount;

    // Filters (same as v1)
    final departments = personnel.map((e) => e.departmentName ?? '').where((e) => e.isNotEmpty).toSet().toList()
      ..sort();
    final skills = personnel.map((e) => e.skillName ?? '').where((e) => e.isNotEmpty).toSet().toList()..sort();

    final filtered = personnel.where((p) {
      final matchSearch =
          _searchQuery.isEmpty ||
          p.userFullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.departmentName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final matchDept = _selectedDepartment == null || p.departmentName == _selectedDepartment;
      final matchSkill = _selectedSkill == null || p.skillName == _selectedSkill;
      return matchSearch && matchDept && matchSkill;
    }).toList();

    // Group by department (same as v1)
    final Map<String, List<WorkPersonnel>> grouped = {};
    for (var p in filtered) {
      final dept = (p.departmentName == null || p.departmentName!.isEmpty) ? 'Chưa phân bộ phận' : p.departmentName!;
      grouped.putIfAbsent(dept, () => []).add(p);
    }
    final sortedGroups = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Chưa phân bộ phận') return 1;
        if (b == 'Chưa phân bộ phận') return -1;
        return a.compareTo(b);
      });

    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final headerCount = 4;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 24.h),
            itemCount: headerCount + (sortedGroups.isEmpty ? 1 : sortedGroups.length),
            itemBuilder: (context, index) {
              switch (index) {
                case 0:
                  return _toolbar(t, isToday);
                case 1:
                  return _summary(t, data, total, working, offCount, halfCount);
                case 2:
                  return _filters(t, departments, skills);
                case 3:
                  return Padding(
                    padding: EdgeInsets.fromLTRB(2.w, 2.h, 2.w, 10.h),
                    child: Row(
                      children: [
                        Icon(Icons.groups_rounded, size: 14.sp, color: t.textFaint),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            'Hiển thị ${filtered.length}/${personnel.length} · ${sortedGroups.length} bộ phận',
                            style: t.small.copyWith(fontFeatures: FxTokens.tabular),
                          ),
                        ),
                      ],
                    ),
                  );
              }
              if (sortedGroups.isEmpty) {
                return const FxEmpty(icon: Icons.person_search_rounded, title: 'Không tìm thấy nhân sự phù hợp');
              }
              final dept = sortedGroups[index - headerCount];
              final members = grouped[dept]!;
              return _DepartmentGroupV2(
                department: dept,
                members: members,
                draft: data.draft,
                onSetStatus: _setStatus,
                readOnly: widget.readOnly,
              );
            },
          ),
        ),
        if (!widget.readOnly)
          WaSaveBar(
            title: 'Chấm công ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
            subtitle: data.isAttendanceMarked ? 'Đã chấm · có thể cập nhật lại' : 'Chưa chấm · nhấn Lưu để chấm công',
            icon: Icons.fact_check_rounded,
            tone: data.isAttendanceMarked ? FxTokens.emerald : FxTokens.amber,
            saving: _isSaving,
            onSave: _saveData,
          ),
      ],
    );
  }

  Widget _toolbar(FxTokens t, bool isToday) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Flexible(
            child: WaDateChip(label: DateFormat('dd/MM/yyyy').format(_selectedDate), onTap: () => _selectDate(context)),
          ),
          if (!isToday) ...[
            SizedBox(width: 6.w),
            TextButton(
              onPressed: () {
                setState(() => _selectedDate = DateTime.now());
                _loadData();
              },
              style: TextButton.styleFrom(
                minimumSize: Size(0, 38.h),
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                foregroundColor: t.ink(FxTokens.blue),
              ),
              child: const Text('Hôm nay'),
            ),
          ],
          const Spacer(),
          WaToolButton(icon: Icons.refresh_rounded, tooltip: 'Tải lại', onTap: _loadData),
        ],
      ),
    );
  }

  Widget _summary(FxTokens t, WorkAttendanceBootstrap data, int total, double working, int offCount, double halfCount) {
    Widget cell(String label, String value, Color tone) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: t.num(20.sp)),
          ),
        ],
      ),
    );

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.how_to_reg_rounded,
            tone: FxTokens.emerald,
            title: 'Tình hình đi làm',
            subtitle: MaterialLocalizations.of(context).formatFullDate(_selectedDate),
            trailing: data.isAttendanceMarked
                ? const FxPill(label: 'Đã chấm', tone: FxTokens.emerald, dot: true)
                : const FxPill(label: 'Chưa chấm', tone: FxTokens.amber, dot: true),
          ),
          Row(
            children: [
              cell('Nhân sự', '$total', FxTokens.slate),
              cell('Đi làm', waNum(working), FxTokens.emerald),
              cell('Nghỉ', waNum(offCount + halfCount), FxTokens.red),
            ],
          ),
          SizedBox(height: 12.h),
          FxStackBar(
            height: 8,
            parts: [
              (value: working < 0 ? 0 : working, color: FxTokens.emerald),
              (value: halfCount, color: FxTokens.amber),
              (value: offCount.toDouble(), color: FxTokens.red),
            ],
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 14.w,
            runSpacing: 6.h,
            children: [
              FxLegend(color: FxTokens.emerald, label: 'Đi làm', value: waNum(working)),
              FxLegend(color: FxTokens.amber, label: 'Nghỉ nửa ngày', value: waNum(halfCount)),
              FxLegend(color: FxTokens.red, label: 'Nghỉ cả ngày', value: '$offCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters(FxTokens t, List<String> departments, List<String> skills) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        children: [
          FxSearchField(
            hint: 'Tìm họ tên, bộ phận...',
            controller: _searchCtrl,
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _selectedDepartment,
                  items: departments,
                  hint: 'Tất cả bộ phận',
                  icon: Icons.apartment_rounded,
                  onChanged: (val) => setState(() => _selectedDepartment = val),
                  t: t,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildDropdown(
                  value: _selectedSkill,
                  items: skills,
                  hint: 'Tất cả tay nghề',
                  icon: Icons.engineering_rounded,
                  onChanged: (val) => setState(() => _selectedSkill = val),
                  t: t,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    required FxTokens t,
  }) {
    final active = value != null;
    final labels = [hint, ...items];
    return Container(
      height: 42.h,
      padding: EdgeInsets.only(left: 10.w, right: 6.w),
      decoration: BoxDecoration(
        color: active ? t.soft(FxTokens.blue) : t.cardAlt,
        border: Border.all(color: active ? FxTokens.blue.withValues(alpha: 0.45) : t.border),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: t.card,
          borderRadius: BorderRadius.circular(14.r),
          hint: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.small),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18.sp,
            color: active ? t.ink(FxTokens.blue) : t.textMuted,
          ),
          // Derived from the theme so the menu keeps the app's font family.
          style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
            fontSize: 12.5.sp,
            color: t.text,
            fontWeight: FontWeight.w600,
          ),
          selectedItemBuilder: (context) => [
            for (final l in labels)
              Row(
                children: [
                  Icon(icon, size: 15.sp, color: active ? t.ink(FxTokens.blue) : t.textFaint),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      l,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? t.ink(FxTokens.blue) : t.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
          ],
          items: [
            DropdownMenuItem<String>(value: null, child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ...items.map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DepartmentGroupV2 extends StatelessWidget {
  final String department;
  final List<WorkPersonnel> members;
  final WorkAttendanceDraft draft;
  final void Function(int, String) onSetStatus;
  final bool readOnly;

  const _DepartmentGroupV2({
    required this.department,
    required this.members,
    required this.draft,
    required this.onSetStatus,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    int offCount = 0;
    double halfCount = 0;
    for (var m in members) {
      final st = draft.userStatuses.where((e) => e.userId == m.userId).firstOrNull?.status;
      if (st == 'off_full') {
        offCount++;
      } else if (st == 'off_morning' || st == 'off_afternoon') {
        halfCount += 0.5;
      }
    }
    final off = offCount + halfCount;

    return FxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 12.w, 12.h),
            child: Row(
              children: [
                const FxIconBadge(icon: Icons.apartment_rounded, tone: FxTokens.slate, size: 32),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(department, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3),
                      SizedBox(height: 1.h),
                      Text('${members.length} nhân sự', style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                FxPill(
                  label: '${waNum(off)} nghỉ / ${members.length}',
                  tone: off > 0 ? FxTokens.red : FxTokens.emerald,
                ),
              ],
            ),
          ),
          for (final m in members) ...[
            Divider(height: 1, color: t.divider),
            _EmployeeRowV2(
              person: m,
              status: draft.userStatuses.where((e) => e.userId == m.userId).firstOrNull?.status ?? 'working',
              onStatusChange: (val) => onSetStatus(m.userId, val),
              readOnly: readOnly,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeRowV2 extends StatelessWidget {
  final WorkPersonnel person;
  final String status;
  final ValueChanged<String> onStatusChange;
  final bool readOnly;

  const _EmployeeRowV2({
    required this.person,
    required this.status,
    required this.onStatusChange,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              WaAvatar(name: person.userFullName, size: 36, tone: _statusTone(status)),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.userFullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3),
                    SizedBox(height: 2.h),
                    Text(
                      '${person.userShortName ?? person.userFullName} • ${person.departmentName ?? ''}'.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: t.textFaint,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            height: 36.h,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: t.cardAlt,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: t.border.withValues(alpha: 0.8)),
            ),
            child: Row(
              children: [for (final o in _statusOptions) Expanded(child: _segment(t, o.label, o.value, o.tone))],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(FxTokens t, String label, String value, Color tone) {
    final isSelected = status == value;
    return Material(
      color: isSelected ? t.soft(tone) : Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9.r),
        side: BorderSide(color: isSelected ? tone.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: InkWell(
        onTap: readOnly ? null : () => onStatusChange(value),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_circle_rounded, size: 13.sp, color: t.ink(tone)),
                  SizedBox(width: 4.w),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? t.ink(tone) : t.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailySkeleton extends StatelessWidget {
  const _DailySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            FxSkeleton(height: 38.h, width: 130.w, radius: 12),
            const Spacer(),
            FxSkeleton(height: 38.h, width: 38.h, radius: 12),
          ],
        ),
        SizedBox(height: 12.h),
        FxSkeleton(height: 170.h, radius: 18),
        SizedBox(height: 12.h),
        FxSkeleton(height: 42.h, radius: 12),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(child: FxSkeleton(height: 42.h, radius: 12)),
            SizedBox(width: 8.w),
            Expanded(child: FxSkeleton(height: 42.h, radius: 12)),
          ],
        ),
        SizedBox(height: 14.h),
        FxSkeleton(height: 260.h, radius: 18),
      ],
    );
  }
}

// ─── Monthly overview ───────────────────────────────────────────────────────

class _MonthlyOverviewViewV2 extends StatefulWidget {
  final WorkArrangementService service;
  const _MonthlyOverviewViewV2({required this.service});

  @override
  State<_MonthlyOverviewViewV2> createState() => _MonthlyOverviewViewV2State();
}

class _MonthlyOverviewViewV2State extends State<_MonthlyOverviewViewV2> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = true;

  List<WorkPersonnel> _personnel = [];
  Map<String, bool> _markedDates = {};
  Map<String, Map<int, String>> _statusesByDate = {}; // date -> { userId: status }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Logic (from v1; `mounted` guards added) ───────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final from = DateFormat('yyyy-MM-dd').format(_month);
    final to = DateFormat('yyyy-MM-dd').format(DateTime(_month.year, _month.month + 1, 0));
    try {
      final data = await widget.service.getMonthlyOverview(from, to);
      if (!mounted) return;
      setState(() {
        _personnel = data['personnel'] as List<WorkPersonnel>;
        _markedDates = data['markedDates'] as Map<String, bool>;
        _statusesByDate = data['statusesByDate'] as Map<String, Map<int, String>>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _selectMonth() async {
    // Simple month picker using year and month selector
    // In Flutter, showDatePicker can be used and restricted to day 1
    final date = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (date != null) {
      setState(() => _month = DateTime(date.year, date.month, 1));
      _loadData();
    }
  }

  void _showDayDetails(String dateStr, Map<int, String> offStatuses) {
    final offPeople = _personnel.where((p) => offStatuses.containsKey(p.userId)).toList()
      ..sort((a, b) => a.userFullName.compareTo(b.userFullName));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final t = FxTokens.of(context);
        final morning = offPeople.where((p) => offStatuses[p.userId] == 'off_morning').length;
        final afternoon = offPeople.where((p) => offStatuses[p.userId] == 'off_afternoon').length;
        final full = offPeople.length - morning - afternoon;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WaSheetHandle(),
              WaSheetHeader(
                icon: Icons.event_note_rounded,
                tone: offPeople.isEmpty ? FxTokens.emerald : FxTokens.red,
                title: 'Chi tiết ngày ${DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr))}',
                subtitle: offPeople.isEmpty ? 'Không có lượt nghỉ' : '${offPeople.length} người nghỉ',
                onClose: () => Navigator.pop(context),
              ),
              if (offPeople.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                  child: Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      FxPill(label: 'Sáng · $morning', tone: FxTokens.amber),
                      FxPill(label: 'Chiều · $afternoon', tone: FxTokens.amber),
                      FxPill(label: 'Cả ngày · $full', tone: FxTokens.red),
                    ],
                  ),
                ),
              Divider(height: 1, color: t.divider),
              Expanded(
                child: offPeople.isEmpty
                    ? const Center(
                        child: FxEmpty(icon: Icons.event_available_rounded, title: 'Không có ai nghỉ'),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 16.h + MediaQuery.of(context).padding.bottom),
                        itemCount: offPeople.length,
                        separatorBuilder: (_, _) => Divider(height: 1, indent: 67.w, endIndent: 10.w, color: t.divider),
                        itemBuilder: (context, index) {
                          final p = offPeople[index];
                          final st = offStatuses[p.userId]!;
                          String stLabel = st == 'off_morning'
                              ? 'Sáng'
                              : st == 'off_afternoon'
                              ? 'Chiều'
                              : 'Cả ngày';
                          Color stColor = st == 'off_morning' || st == 'off_afternoon' ? FxTokens.amber : FxTokens.red;

                          return WaPersonRow(
                            name: p.userFullName,
                            subtitle: p.departmentName ?? '',
                            avatarTone: stColor,
                            trailing: FxPill(label: stLabel, tone: stColor),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    int totalMarked = _markedDates.length;
    int totalOff = _statusesByDate.values.fold(0, (sum, map) => sum + map.length);

    // Calculate calendar grid (same as v1)
    int daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    int firstWeekday = _month.weekday; // 1 (Mon) - 7 (Sun)
    int lead = (firstWeekday - 1) % 7;

    List<DateTime?> cells = List.filled(lead, null, growable: true);
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_month.year, _month.month, d));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 24.h),
      children: [
        // Toolbar
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            children: [
              Flexible(
                child: WaDateChip(
                  icon: Icons.calendar_month_rounded,
                  label: 'Tháng ${DateFormat('MM/yyyy').format(_month)}',
                  onTap: _selectMonth,
                ),
              ),
              const Spacer(),
              WaToolButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Tải lại',
                loading: _isLoading,
                onTap: _isLoading ? null : _loadData,
              ),
            ],
          ),
        ),

        // Stats
        if (_isLoading)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) SizedBox(width: 10.w),
                  Expanded(child: FxSkeleton(height: 96.h, radius: 18)),
                ],
              ],
            ),
          )
        else
          FxGrid(
            columns: 3,
            children: [
              FxKpi(
                icon: Icons.event_available_rounded,
                label: 'Đã chấm',
                value: '$totalMarked',
                unit: 'ngày',
                tone: FxTokens.emerald,
              ),
              FxKpi(icon: Icons.event_busy_rounded, label: 'Lượt nghỉ', value: '$totalOff', tone: FxTokens.red),
              FxKpi(icon: Icons.groups_rounded, label: 'Nhân sự', value: '${_personnel.length}', tone: FxTokens.blue),
            ],
          ),

        // Calendar
        if (_isLoading)
          FxSkeleton(height: 380.h, radius: 18)
        else
          FxCard(
            padding: EdgeInsets.fromLTRB(10.w, 14.h, 10.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: FxSectionHeader(
                    icon: Icons.calendar_month_rounded,
                    tone: FxTokens.blue,
                    title: 'Lịch chấm công',
                    subtitle: 'Chạm vào một ngày để xem ai nghỉ',
                  ),
                ),
                Row(
                  children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                      .map(
                        (w) => Expanded(
                          child: Text(
                            w,
                            textAlign: TextAlign.center,
                            style: t.overline.copyWith(
                              fontSize: 10.5.sp,
                              color: w == 'CN' ? t.ink(FxTokens.red) : t.textMuted,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 8.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                  ),
                  itemCount: cells.length,
                  itemBuilder: (context, index) {
                    final day = cells[index];
                    if (day == null) return const SizedBox();

                    final dateStr = DateFormat('yyyy-MM-dd').format(day);
                    final offStatuses = _statusesByDate[dateStr] ?? {};
                    final offCount = offStatuses.length;
                    final isMarked = _markedDates[dateStr] == true;
                    final isToday =
                        day.year == DateTime.now().year &&
                        day.month == DateTime.now().month &&
                        day.day == DateTime.now().day;

                    return _DayCell(
                      day: day.day,
                      offCount: offCount,
                      isMarked: isMarked,
                      isToday: isToday,
                      onTap: () => _showDayDetails(dateStr, offStatuses),
                    );
                  },
                ),
                SizedBox(height: 14.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Wrap(
                    spacing: 14.w,
                    runSpacing: 6.h,
                    children: [
                      const FxLegend(color: FxTokens.emerald, label: 'Đã chấm'),
                      const FxLegend(color: FxTokens.red, label: 'Có người nghỉ'),
                      FxLegend(color: t.border, label: 'Chưa chấm'),
                      const FxLegend(color: FxTokens.blue, label: 'Hôm nay', line: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int offCount;
  final bool isMarked;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.offCount,
    required this.isMarked,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final hasOff = offCount > 0;
    final bg = hasOff ? t.soft(FxTokens.red) : (isMarked ? t.soft(FxTokens.emerald) : t.cardAlt);
    final border = isToday
        ? FxTokens.blue
        : hasOff
        ? FxTokens.red.withValues(alpha: 0.28)
        : (isMarked ? FxTokens.emerald.withValues(alpha: 0.28) : t.border.withValues(alpha: 0.6));

    return Material(
      color: bg,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(color: border, width: isToday ? 1.6 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 2.w, top: 1.h),
                  child: Text(
                    '$day',
                    style: t.num(
                      12.5.sp,
                      color: isToday ? t.ink(FxTokens.blue) : (hasOff || isMarked ? t.text : t.textMuted),
                      weight: isToday ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (hasOff)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                    decoration: BoxDecoration(color: FxTokens.red, borderRadius: BorderRadius.circular(FxTokens.rPill)),
                    child: Text(
                      '$offCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w800,
                        fontFeatures: FxTokens.tabular,
                        height: 1.2,
                      ),
                    ),
                  ),
                )
              else if (isMarked)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.check_rounded, size: 12.sp, color: t.ink(FxTokens.emerald)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
