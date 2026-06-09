import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/data/services/work_arrangement_service.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/personnel_selector_sheet.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class WorkTaskManager extends StatefulWidget {
  const WorkTaskManager({super.key});

  @override
  State<WorkTaskManager> createState() => _WorkTaskManagerState();
}

class _WorkTaskManagerState extends State<WorkTaskManager> {
  final WorkArrangementService _service = WorkArrangementService(ApiClient.dio);

  DateTime _selectedDate = DateTime.now();
  String _selectedView = 'assigned';
  Set<int> _addedParentIds = {};
  bool _isLoading = true;
  bool _saving = false;
  bool _creating = false;
  bool _dirty = false;

  List<WorkPersonnel> _personnel = [];
  List<WorkTaskItem> _works = [];
  WorkTaskAssignmentDraft _draft = WorkTaskAssignmentDraft(workDate: '', taskAssignments: []);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Set<int> get _assignedUserIds {
    final set = <int>{};
    for (final a in _draft.taskAssignments) {
      set.addAll(a.userIds);
    }
    return set;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final bootstrap = await _service.getTaskBootstrap(dateStr);
      if (mounted) {
        setState(() {
          _personnel = bootstrap.personnel;
          _works = bootstrap.works;
          _draft = bootstrap.draft;
          _addedParentIds.clear(); // Reset on load
          _dirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu công việc: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await _service.saveTaskAssignment(_draft);
      if (mounted) {
        setState(() {
          _draft = saved;
          _dirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu phân công công việc')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createWork(String name) async {
    setState(() => _creating = true);
    try {
      await _service.createWork(name, null);
      await _loadData(); // Reload to get new work list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo công việc mới')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tạo công việc: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showAddWorkSelector() {
    final parentWorks = _works.where((w) => w.workRoot == null || w.workRoot == 0).toList();
    final shownParentIds = _getShownParentIds();
    final availableWorks = parentWorks.where((w) => !shownParentIds.contains(w.workId)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.all(16.w),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chọn nhóm công việc', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Tạo việc mới',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCreateWorkDialog();
                    },
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: availableWorks.isEmpty 
                  ? Center(child: Text('Không còn công việc nào để thêm.', style: Theme.of(context).textTheme.bodyMedium))
                  : ListView.builder(
                  itemCount: availableWorks.length,
                  itemBuilder: (context, index) {
                    final w = availableWorks[index];
                    return ListTile(
                      leading: Icon(Icons.work_outline, color: Theme.of(context).colorScheme.primary),
                      title: Text(w.workName),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _addedParentIds.add(w.workId);
                          _dirty = true;
                        });
                      },
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

  void _showCreateWorkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tạo công việc mới'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Tên công việc',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  _createWork(name);
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );
  }

  void _showPersonnelSelector(int targetWorkId) {
    final unassigned = _personnel.where((p) => !_assignedUserIds.contains(p.userId)).toList();
    PersonnelSelectorSheet.show(context, unassigned, (p) {
      final newAssignments = List<TaskAssignmentItem>.from(_draft.taskAssignments);
      final existingIndex = newAssignments.indexWhere((a) => a.workId == targetWorkId);
      
      if (existingIndex >= 0) {
        final existing = newAssignments[existingIndex];
        final newUserIds = List<int>.from(existing.userIds)..add(p.userId);
        newAssignments[existingIndex] = TaskAssignmentItem(
          assignmentId: existing.assignmentId,
          workId: existing.workId,
          userIds: newUserIds,
        );
      } else {
        newAssignments.add(TaskAssignmentItem(
          assignmentId: 'new_${DateTime.now().millisecondsSinceEpoch}_$targetWorkId',
          workId: targetWorkId,
          userIds: [p.userId],
        ));
      }

      setState(() {
        _draft = WorkTaskAssignmentDraft(
          workDate: _draft.workDate,
          taskAssignments: newAssignments,
          updatedAt: _draft.updatedAt,
        );
        _dirty = true;
      });
    });
  }

  void _removeUserFromWork(int workId, int userId) {
    final newAssignments = List<TaskAssignmentItem>.from(_draft.taskAssignments);
    final idx = newAssignments.indexWhere((a) => a.workId == workId);
    if (idx >= 0) {
      final existing = newAssignments[idx];
      final newUserIds = List<int>.from(existing.userIds)..remove(userId);
      if (newUserIds.isEmpty && existing.assignmentId.startsWith('new_')) {
        newAssignments.removeAt(idx);
      } else {
        newAssignments[idx] = TaskAssignmentItem(
          assignmentId: existing.assignmentId,
          workId: existing.workId,
          userIds: newUserIds,
        );
      }
      setState(() {
        _draft = WorkTaskAssignmentDraft(
          workDate: _draft.workDate,
          taskAssignments: newAssignments,
          updatedAt: _draft.updatedAt,
        );
        _dirty = true;
      });
    }
  }

  void _removeParentGroup(int parentId) {
    final childIds = _works.where((w) => w.workRoot == parentId).map((w) => w.workId).toSet();
    childIds.add(parentId);
    
    final newAssignments = _draft.taskAssignments.where((a) => !childIds.contains(a.workId)).toList();
    
    setState(() {
      _addedParentIds.remove(parentId);
      _draft = WorkTaskAssignmentDraft(
        workDate: _draft.workDate,
        taskAssignments: newAssignments,
        updatedAt: _draft.updatedAt,
      );
      _dirty = true;
    });
  }

  Set<int> _getShownParentIds() {
    final set = Set<int>.from(_addedParentIds);
    for (final task in _draft.taskAssignments) {
      if (task.userIds.isEmpty) continue;
      final work = _works.firstWhere((w) => w.workId == task.workId, orElse: () => WorkTaskItem(workId: 0, workName: ''));
      if (work.workId != 0) {
        set.add(work.workRoot ?? work.workId);
      }
    }
    return set;
  }

  Widget _buildUnassignedPersonnel(ThemeData theme, ColorScheme colorScheme) {
    final unassigned = _personnel.where((p) => !_assignedUserIds.contains(p.userId)).toList();

    if (unassigned.isEmpty) {
      return const Center(child: Text('Tất cả nhân sự đã được phân công'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: unassigned.length,
      itemBuilder: (context, index) {
        final p = unassigned[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Text(p.userFullName.substring(0, 1).toUpperCase()),
            ),
            title: Text(p.userFullName),
            subtitle: Text(p.departmentName ?? '---'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    final shownParentIds = _getShownParentIds();
    final parentWorks = _works.where((w) => (w.workRoot == null || w.workRoot == 0) && shownParentIds.contains(w.workId)).toList();
    parentWorks.sort((a, b) => a.workName.compareTo(b.workName));

    Widget content;
    if (_isLoading || _creating) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_selectedView == 'unassigned_personnel') {
      content = _buildUnassignedPersonnel(theme, colorScheme);
    } else {
      content = Stack(
        children: [
          ListView.builder(
            padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 80.h),
            itemCount: parentWorks.length,
            itemBuilder: (context, index) {
              final parent = parentWorks[index];
              final childWorks = _works.where((w) => w.workRoot == parent.workId).toList();
              final tasks = childWorks.isNotEmpty ? childWorks : [parent];
              
              int totalAssigned = 0;
              for (var t in tasks) {
                final assignment = _draft.taskAssignments.firstWhere((a) => a.workId == t.workId, orElse: () => TaskAssignmentItem(assignmentId: '', workId: t.workId, userIds: []));
                totalAssigned += assignment.userIds.length;
              }

              return Card(
                key: ValueKey('parent_${parent.workId}'),
                margin: EdgeInsets.only(bottom: 12.h),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.handyman, size: 18.sp, color: colorScheme.primary),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              parent.workName.toUpperCase(),
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                            ),
                          ),
                          if (totalAssigned > 0)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '$totalAssigned',
                                style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 12.sp, fontWeight: FontWeight.bold),
                              ),
                            ),
                          SizedBox(width: 4.w),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 20.sp,
                            onPressed: () => _removeParentGroup(parent.workId),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Column(
                        children: tasks.map((task) {
                          final assignment = _draft.taskAssignments.firstWhere(
                            (a) => a.workId == task.workId,
                            orElse: () => TaskAssignmentItem(assignmentId: '', workId: task.workId, userIds: []),
                          );
                          final assignedUsers = _personnel.where((p) => assignment.userIds.contains(p.userId)).toList();

                          return Container(
                            margin: EdgeInsets.only(bottom: task == tasks.last ? 0 : 12.h),
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              border: Border.all(color: colorScheme.outlineVariant, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (childWorks.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: Text(
                                      task.workName,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Wrap(
                                  spacing: 8.w,
                                  runSpacing: 8.h,
                                  children: [
                                    ...assignedUsers.map((u) => Chip(
                                          label: Text(u.userFullName),
                                          onDeleted: () => _removeUserFromWork(task.workId, u.userId),
                                          deleteIcon: const Icon(Icons.close, size: 16),
                                          backgroundColor: colorScheme.surfaceContainerHighest,
                                          visualDensity: VisualDensity.compact,
                                        )),
                                    ActionChip(
                                      label: Text(assignedUsers.isEmpty ? 'Thêm nhân sự vào' : 'Gán thêm', style: TextStyle(color: colorScheme.primary)),
                                      avatar: Icon(Icons.add, size: 16, color: colorScheme.primary),
                                      onPressed: () => _showPersonnelSelector(task.workId),
                                      backgroundColor: Colors.transparent,
                                      shape: StadiumBorder(side: BorderSide(color: colorScheme.primary.withOpacity(0.5))),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 16.h,
            right: 16.w,
            child: FloatingActionButton.extended(
              onPressed: _showAddWorkSelector,
              icon: const Icon(Icons.add),
              label: const Text('Thêm việc'),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              FilledButton.tonal(
                onPressed: _pickDate,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  visualDensity: VisualDensity.compact,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14.sp),
                    SizedBox(width: 6.w),
                    Text(
                      isToday ? l10n.today : DateFormat('dd/MM').format(_selectedDate),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              IconButton.filledTonal(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 20),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.all(6.w),
                tooltip: 'Tải lại',
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedView,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'assigned', child: Text('Bố trí công việc')),
                    DropdownMenuItem(value: 'unassigned_personnel', child: Text('Nhân sự chưa phân công')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedView = val);
                  },
                ),
              ),
              if (_dirty) ...[
                SizedBox(width: 12.w),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Lưu'),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}
