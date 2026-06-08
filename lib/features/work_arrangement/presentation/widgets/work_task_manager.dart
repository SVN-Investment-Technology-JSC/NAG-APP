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

  void _showPersonnelSelector(TaskAssignmentItem assignment, int index) {
    final unassigned = _personnel.where((p) => !_assignedUserIds.contains(p.userId)).toList();
    PersonnelSelectorSheet.show(context, unassigned, (p) {
      final newAssignments = List<TaskAssignmentItem>.from(_draft.taskAssignments);
      final newUserIds = List<int>.from(assignment.userIds)..add(p.userId);
      
      newAssignments[index] = TaskAssignmentItem(
        assignmentId: assignment.assignmentId,
        workId: assignment.workId,
        userIds: newUserIds,
      );

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

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
              const Spacer(),
              if (_dirty) ...[
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
        if (_isLoading || _creating)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: _draft.taskAssignments.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) newIndex -= 1;
                if (oldIndex == newIndex) return;

                final newAssignments = List<TaskAssignmentItem>.from(_draft.taskAssignments);
                final item = newAssignments.removeAt(oldIndex);
                newAssignments.insert(newIndex, item);

                setState(() {
                  _draft = WorkTaskAssignmentDraft(
                    workDate: _draft.workDate,
                    taskAssignments: newAssignments,
                    updatedAt: _draft.updatedAt,
                  );
                  _dirty = true;
                });
              },
              itemBuilder: (context, index) {
                final assignment = _draft.taskAssignments[index];
                final work = _works.firstWhere(
                  (w) => w.workId == assignment.workId,
                  orElse: () => WorkTaskItem(workId: 0, workName: 'Unknown'),
                );
                
                final assignedUsers = _personnel.where((p) => assignment.userIds.contains(p.userId)).toList();

                return Card(
                  key: ValueKey(assignment.assignmentId),
                  margin: EdgeInsets.only(bottom: 12.h),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.drag_indicator, color: colorScheme.outline),
                            SizedBox(width: 8.w),
                            Icon(Icons.handyman_outlined, color: colorScheme.primary),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                work.workName,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                final newAssignments = List<TaskAssignmentItem>.from(_draft.taskAssignments);
                                newAssignments.removeAt(index);
                                setState(() {
                                  _draft = WorkTaskAssignmentDraft(
                                    workDate: _draft.workDate,
                                    taskAssignments: newAssignments,
                                    updatedAt: _draft.updatedAt,
                                  );
                                  _dirty = true;
                                });
                              },
                            ),
                          ],
                        ),
                        Divider(color: colorScheme.outlineVariant),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            ...assignedUsers.map((u) => Chip(
                                  label: Text(u.userFullName),
                                  onDeleted: () {
                                    final newAssignments = List<TaskAssignmentItem>.from(_draft.taskAssignments);
                                    final newUserIds = List<int>.from(assignment.userIds)..remove(u.userId);
                                    newAssignments[index] = TaskAssignmentItem(
                                      assignmentId: assignment.assignmentId,
                                      workId: assignment.workId,
                                      userIds: newUserIds,
                                    );
                                    setState(() {
                                      _draft = WorkTaskAssignmentDraft(
                                        workDate: _draft.workDate,
                                        taskAssignments: newAssignments,
                                        updatedAt: _draft.updatedAt,
                                      );
                                      _dirty = true;
                                    });
                                  },
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  backgroundColor: colorScheme.surfaceContainerHighest,
                                )),
                            ActionChip(
                              label: const Text('Gán nhân sự'),
                              avatar: const Icon(Icons.add, size: 16),
                              onPressed: () => _showPersonnelSelector(assignment, index),
                              backgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
