import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/data/services/work_arrangement_service.dart';

class WorkAttendanceManager extends StatefulWidget {
  const WorkAttendanceManager({super.key});

  @override
  State<WorkAttendanceManager> createState() => _WorkAttendanceManagerState();
}

class _WorkAttendanceManagerState extends State<WorkAttendanceManager>
    with SingleTickerProviderStateMixin {
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          color: colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0D9488), // teal-600
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: const Color(0xFF0D9488),
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
            tabs: const [
              Tab(text: 'Chấm công ngày'),
              Tab(text: 'Tổng quan tháng'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _DailyMarkingView(service: _service),
              _MonthlyOverviewView(service: _service),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyMarkingView extends StatefulWidget {
  final WorkArrangementService service;
  const _DailyMarkingView({required this.service});

  @override
  State<_DailyMarkingView> createState() => _DailyMarkingViewState();
}

class _DailyMarkingViewState extends State<_DailyMarkingView> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  WorkAttendanceBootstrap? _data;
  
  String _searchQuery = '';
  String? _selectedDepartment;
  String? _selectedSkill;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.service.getAttendanceBootstrap(_dateStr);
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveData() async {
    if (_data == null) return;
    setState(() => _isSaving = true);
    try {
      final savedDraft = await widget.service.saveAttendanceDraft(_data!.draft);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data;
    if (data == null) {
      return Center(
        child: FilledButton.icon(onPressed: _loadData, icon: const Icon(Icons.refresh), label: const Text('Tải lại')),
      );
    }

    final personnel = data.personnel;
    
    // Stats calculation
    int total = personnel.length;
    int offCount = 0;
    double halfCount = 0;
    for (var s in data.draft.userStatuses) {
      if (s.status == 'off_full') offCount++;
      else if (s.status == 'off_morning' || s.status == 'off_afternoon') halfCount += 0.5;
    }
    double working = total - offCount - halfCount;

    // Filters
    final departments = personnel.map((e) => e.departmentName ?? '').where((e) => e.isNotEmpty).toSet().toList()..sort();
    final skills = personnel.map((e) => e.skillName ?? '').where((e) => e.isNotEmpty).toSet().toList()..sort();

    // Filter list
    final filtered = personnel.where((p) {
      final matchSearch = _searchQuery.isEmpty || 
          p.userFullName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          (p.departmentName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final matchDept = _selectedDepartment == null || p.departmentName == _selectedDepartment;
      final matchSkill = _selectedSkill == null || p.skillName == _selectedSkill;
      return matchSearch && matchDept && matchSkill;
    }).toList();

    // Group by department
    final Map<String, List<WorkPersonnel>> grouped = {};
    for (var p in filtered) {
      final dept = (p.departmentName == null || p.departmentName!.isEmpty) ? 'Chưa phân bộ phận' : p.departmentName!;
      grouped.putIfAbsent(dept, () => []).add(p);
    }
    final sortedGroups = grouped.keys.toList()..sort((a, b) {
      if (a == 'Chưa phân bộ phận') return 1;
      if (b == 'Chưa phân bộ phận') return -1;
      return a.compareTo(b);
    });

    return Column(
      children: [
        // Controls & Actions Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      foregroundColor: colorScheme.onSurface,
                    ),
                  ),
                  if (DateFormat('yyyy-MM-dd').format(_selectedDate) != DateFormat('yyyy-MM-dd').format(DateTime.now())) ...[
                    SizedBox(width: 8.w),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedDate = DateTime.now());
                        _loadData();
                      },
                      child: const Text('Hôm nay', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 20),
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveData,
                    icon: _isSaving ? SizedBox(width: 16, height: 16, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 16),
                    label: const Text('Lưu'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Stats Row
        Padding(
          padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!data.isAttendanceMarked) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(100.r), border: Border.all(color: const Color(0xFFFDE68A))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6.w, height: 6.w, decoration: const BoxDecoration(color: Color(0xFFD97706), shape: BoxShape.circle)),
                        SizedBox(width: 4.w),
                        Text('Chưa chấm', style: TextStyle(fontSize: 10.sp, color: const Color(0xFFD97706), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                ],
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                    children: [
                      WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: EdgeInsets.only(right: 4.w), child: Icon(Icons.circle, size: 8.sp, color: const Color(0xFF10B981)))),
                      const TextSpan(text: 'Đi làm '),
                      TextSpan(text: '${working.toStringAsFixed(working.truncateToDouble() == working ? 0 : 1)}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                      const TextSpan(text: '   '),
                      WidgetSpan(alignment: PlaceholderAlignment.middle, child: Padding(padding: EdgeInsets.only(right: 4.w), child: Icon(Icons.circle, size: 8.sp, color: const Color(0xFFEF4444)))),
                      const TextSpan(text: 'Nghỉ '),
                      TextSpan(text: '${offCount + halfCount}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),

        // Search & Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              SizedBox(
                width: 200.w,
                height: 40.h,
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Tìm họ tên, bộ phận...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12.w),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: colorScheme.outlineVariant)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              _buildDropdown(
                value: _selectedDepartment,
                items: departments,
                hint: 'Tất cả bộ phận',
                onChanged: (val) => setState(() => _selectedDepartment = val),
                colorScheme: colorScheme,
              ),
              SizedBox(width: 8.w),
              _buildDropdown(
                value: _selectedSkill,
                items: skills,
                hint: 'Tất cả tay nghề',
                onChanged: (val) => setState(() => _selectedSkill = val),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Hiển thị ${filtered.length}/${personnel.length}', style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant)),
          ),
        ),

        // Grouped List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            itemCount: sortedGroups.length,
            itemBuilder: (context, index) {
              final dept = sortedGroups[index];
              final members = grouped[dept]!;
              return _DepartmentGroup(
                department: dept,
                members: members,
                draft: data.draft,
                onSetStatus: _setStatus,
                theme: theme,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({required String? value, required List<String> items, required String hint, required ValueChanged<String?> onChanged, required ColorScheme colorScheme}) {
    return Container(
      height: 40.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 13.sp)),
          icon: Icon(Icons.keyboard_arrow_down, size: 16.sp),
          items: [
            DropdownMenuItem<String>(value: null, child: Text(hint, style: TextStyle(fontSize: 13.sp))),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13.sp)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DepartmentGroup extends StatelessWidget {
  final String department;
  final List<WorkPersonnel> members;
  final WorkAttendanceDraft draft;
  final void Function(int, String) onSetStatus;
  final ThemeData theme;

  const _DepartmentGroup({
    required this.department,
    required this.members,
    required this.draft,
    required this.onSetStatus,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    
    int offCount = 0;
    double halfCount = 0;
    for (var m in members) {
      final st = draft.userStatuses.where((e) => e.userId == m.userId).firstOrNull?.status;
      if (st == 'off_full') offCount++;
      else if (st == 'off_morning' || st == 'off_afternoon') halfCount += 0.5;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              Text(
                department,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const Spacer(),
              Text(
                '${offCount + halfCount} nghỉ / ${members.length}',
                style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        ...members.map((m) {
          final st = draft.userStatuses.where((e) => e.userId == m.userId).firstOrNull?.status ?? 'working';
          return _EmployeeRow(
            person: m,
            status: st,
            onStatusChange: (val) => onSetStatus(m.userId, val),
            theme: theme,
          );
        }),
        SizedBox(height: 16.h),
      ],
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final WorkPersonnel person;
  final String status;
  final ValueChanged<String> onStatusChange;
  final ThemeData theme;

  const _EmployeeRow({
    required this.person,
    required this.status,
    required this.onStatusChange,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.userFullName,
                      style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), fontSize: 16.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${person.userShortName ?? person.userFullName} • ${person.departmentName ?? ''}'.toUpperCase(),
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8), letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Center(
                  child: Icon(Icons.person_outline, color: const Color(0xFF94A3B8), size: 22.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(child: _buildRadio('Đi làm', 'working', const Color(0xFF059669), true)),
              SizedBox(width: 8.w),
              Expanded(child: _buildRadio('Sáng', 'off_morning', const Color(0xFFF59E0B), false)),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(child: _buildRadio('Chiều', 'off_afternoon', const Color(0xFFF59E0B), false)),
              SizedBox(width: 8.w),
              Expanded(child: _buildRadio('Cả ngày', 'off_full', const Color(0xFFEF4444), false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadio(String label, String value, Color activeColor, bool isWorkingLabel) {
    final isSelected = status == value;
    Color borderColor = isSelected ? activeColor.withOpacity(0.5) : theme.colorScheme.outlineVariant.withOpacity(0.3);
    Color bgColor = isSelected ? activeColor.withOpacity(0.08) : Colors.transparent;
    Color textColor = isSelected ? activeColor : const Color(0xFF475569);

    return GestureDetector(
      onTap: () => onStatusChange(value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40.h,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle, size: 14.sp, color: activeColor),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyOverviewView extends StatefulWidget {
  final WorkArrangementService service;
  const _MonthlyOverviewView({required this.service});

  @override
  State<_MonthlyOverviewView> createState() => _MonthlyOverviewViewState();
}

class _MonthlyOverviewViewState extends State<_MonthlyOverviewView> {
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final from = DateFormat('yyyy-MM-dd').format(_month);
    final to = DateFormat('yyyy-MM-dd').format(DateTime(_month.year, _month.month + 1, 0));
    try {
      final data = await widget.service.getMonthlyOverview(from, to);
      setState(() {
        _personnel = data['personnel'] as List<WorkPersonnel>;
        _markedDates = data['markedDates'] as Map<String, bool>;
        _statusesByDate = data['statusesByDate'] as Map<String, Map<int, String>>;
        _isLoading = false;
      });
    } catch (_) {
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
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
          child: Column(
            children: [
              Container(margin: EdgeInsets.only(top: 12.h, bottom: 8.h), width: 40.w, height: 4.h, decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(4.r))),
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text('Chi tiết ngày ${DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr))}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: offPeople.isEmpty
                    ? const Center(child: Text('Không có ai nghỉ'))
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: offPeople.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.3)),
                        itemBuilder: (context, index) {
                          final p = offPeople[index];
                          final st = offStatuses[p.userId]!;
                          String stLabel = st == 'off_morning' ? 'Sáng' : st == 'off_afternoon' ? 'Chiều' : 'Cả ngày';
                          Color stColor = st == 'off_morning' || st == 'off_afternoon' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
                          
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(p.userFullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                            subtitle: Text(p.departmentName ?? '', style: TextStyle(fontSize: 11.sp)),
                            trailing: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(color: stColor.withOpacity(0.1), borderRadius: BorderRadius.circular(100.r)),
                              child: Text(stLabel, style: TextStyle(color: stColor, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    int totalMarked = _markedDates.length;
    int totalOff = _statusesByDate.values.fold(0, (sum, map) => sum + map.length);

    // Calculate calendar grid
    int daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    int firstWeekday = _month.weekday; // 1 (Mon) - 7 (Sun)
    int lead = (firstWeekday - 1) % 7;
    
    List<DateTime?> cells = List.filled(lead, null, growable: true);
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_month.year, _month.month, d));
    }

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _selectMonth,
                icon: const Icon(Icons.calendar_month, size: 16),
                label: Text(DateFormat('MM/yyyy').format(_month)),
              ),
              SizedBox(width: 8.w),
              IconButton.outlined(
                onPressed: _isLoading ? null : _loadData,
                icon: _isLoading ? SizedBox(width: 16, height: 16, child: const CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, size: 20),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                  side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
              ),
            ],
          ),
        ),
        
        // Stats
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Icon(Icons.event_available, size: 16.sp, color: const Color(0xFF0D9488)),
              SizedBox(width: 4.w),
              Text('Đã chấm: $totalMarked ngày', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: colorScheme.onSurface)),
              SizedBox(width: 16.w),
              Container(width: 8.w, height: 8.w, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
              SizedBox(width: 4.w),
              Text('Lượt nghỉ: $totalOff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: colorScheme.onSurface)),
            ],
          ),
        ),
        SizedBox(height: 12.h),

        // Calendar
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    Row(
                      children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((w) => Expanded(
                        child: Text(w, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp, color: colorScheme.onSurfaceVariant)),
                      )).toList(),
                    ),
                    SizedBox(height: 8.h),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: cells.length,
                        itemBuilder: (context, index) {
                          final day = cells[index];
                          if (day == null) return const SizedBox();

                          final dateStr = DateFormat('yyyy-MM-dd').format(day);
                          final offStatuses = _statusesByDate[dateStr] ?? {};
                          final offCount = offStatuses.length;
                          final isMarked = _markedDates[dateStr] == true;
                          final isToday = day.year == DateTime.now().year && day.month == DateTime.now().month && day.day == DateTime.now().day;

                          Color bgColor = offCount > 0 ? const Color(0xFFFFF1F2) : (isMarked ? colorScheme.surface : const Color(0xFFF8FAFC));
                          Color borderColor = offCount > 0 ? const Color(0xFFFECDD3) : (isMarked ? colorScheme.outlineVariant : Colors.transparent);
                          
                          return GestureDetector(
                            onTap: () => _showDayDetails(dateStr, offStatuses),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bgColor,
                                border: Border.all(color: isToday ? const Color(0xFF0D9488) : borderColor, width: isToday ? 2 : 1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              padding: EdgeInsets.all(4.w),
                              child: Stack(
                                children: [
                                  Text('${day.day}', style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.w600, color: isToday ? const Color(0xFF0D9488) : colorScheme.onSurface)),
                                  if (offCount > 0)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                                        decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(100.r)),
                                        child: Text('$offCount', style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
        ),
      ],
    );
  }
}
