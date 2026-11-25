import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/data/services/work_arrangement_service.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/personnel_selector_sheet_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/wa_widgets_v2.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// v2 of `WorkTaskManager` ("Công việc" tab). Same constructor, state, API calls, add / remove /
/// create-work flows and save; only the widget tree is redesigned.
class WorkTaskManagerV2 extends StatefulWidget {
  final bool readOnly;
  const WorkTaskManagerV2({super.key, this.readOnly = false});

  @override
  State<WorkTaskManagerV2> createState() => _WorkTaskManagerV2State();
}

class _WorkTaskManagerV2State extends State<WorkTaskManagerV2> {
  final WorkArrangementService _service = WorkArrangementService(ApiClient.dio);

  DateTime _selectedDate = DateTime.now();
  String _selectedView = 'assigned';
  final Set<int> _addedParentIds = {};
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

  // ── Logic (verbatim from WorkTaskManager) ─────────────────────────────────

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu công việc: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu phân công công việc')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo công việc mới')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tạo công việc: $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showAddWorkSelector() {
    final parentWorks = _works.where((w) => w.workRoot == null || w.workRoot == 0).toList();
    final shownParentIds = _getShownParentIds();
    final availableWorks = parentWorks.where((w) => !shownParentIds.contains(w.workId)).toList();
    final t = FxTokens.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (ctx) {
        final t = FxTokens.of(ctx);
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WaSheetHandle(),
              WaSheetHeader(
                icon: Icons.playlist_add_rounded,
                tone: FxTokens.indigo,
                title: 'Chọn nhóm công việc',
                subtitle: '${availableWorks.length} nhóm có thể thêm vào ngày này',
                trailing: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showCreateWorkDialog();
                  },
                  icon: Icon(Icons.add_circle_outline_rounded, size: 18.sp),
                  label: const Text('Tạo việc mới'),
                ),
              ),
              Divider(height: 1, color: t.divider),
              Expanded(
                child: availableWorks.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: const FxEmpty(
                            icon: Icons.inventory_2_outlined,
                            title: 'Không còn công việc nào để thêm.',
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 16.h + MediaQuery.of(ctx).padding.bottom),
                        itemCount: availableWorks.length,
                        itemBuilder: (context, index) {
                          final w = availableWorks[index];
                          final subCount = _works.where((c) => c.workRoot == w.workId).length;
                          return Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(FxTokens.rTile),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _addedParentIds.add(w.workId);
                                  _dirty = true;
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                                child: Row(
                                  children: [
                                    const FxIconBadge(
                                      icon: Icons.work_outline_rounded,
                                      tone: FxTokens.indigo,
                                      size: 36,
                                    ),
                                    SizedBox(width: 11.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(w.workName, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.h3),
                                          SizedBox(height: 2.h),
                                          Text(subCount > 0 ? '$subCount đầu việc' : 'Công việc đơn', style: t.tiny),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Icon(Icons.add_circle_outline_rounded, size: 20.sp, color: t.ink(FxTokens.indigo)),
                                  ],
                                ),
                              ),
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

  void _showCreateWorkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final t = FxTokens.of(context);
        return AlertDialog(
          backgroundColor: t.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
          titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
          contentPadding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
          title: Row(
            children: [
              const FxIconBadge(icon: Icons.add_task_rounded, tone: FxTokens.indigo, size: 34),
              SizedBox(width: 10.w),
              Expanded(
                child: Text('Tạo công việc mới', style: t.h2.copyWith(fontSize: 16.sp)),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            style: t.body,
            decoration: InputDecoration(
              labelText: 'Tên công việc',
              prefixIcon: Icon(Icons.work_outline_rounded, size: 18.sp),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: t.textMuted),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: Size(96.w, 44.h)),
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
    PersonnelSelectorSheetV2.show(context, unassigned, (p) {
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
        newAssignments.add(
          TaskAssignmentItem(
            assignmentId: 'new_${DateTime.now().millisecondsSinceEpoch}_$targetWorkId',
            workId: targetWorkId,
            userIds: [p.userId],
          ),
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
      final work = _works.firstWhere(
        (w) => w.workId == task.workId,
        orElse: () => WorkTaskItem(workId: 0, workName: ''),
      );
      if (work.workId != 0) {
        set.add(work.workRoot ?? work.workId);
      }
    }
    return set;
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  Widget _buildUnassignedPersonnel(FxTokens t) {
    final unassigned = _personnel.where((p) => !_assignedUserIds.contains(p.userId)).toList();

    if (unassigned.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: const FxEmpty(icon: Icons.task_alt_rounded, title: 'Tất cả nhân sự đã được phân công'),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 24.h),
      itemCount: unassigned.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return WaListCaption(
            icon: Icons.person_off_outlined,
            text: '${unassigned.length} nhân sự chưa được giao công việc',
          );
        }
        final p = unassigned[i - 1];
        return FxCard(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: WaPersonRow(
            name: p.userFullName,
            subtitle: [p.departmentName ?? '---', if ((p.skillName ?? '').isNotEmpty) p.skillName!].join(' · '),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    final shownParentIds = _getShownParentIds();
    final parentWorks = _works
        .where((w) => (w.workRoot == null || w.workRoot == 0) && shownParentIds.contains(w.workId))
        .toList();
    parentWorks.sort((a, b) => a.workName.compareTo(b.workName));

    final assignedIds = _assignedUserIds;
    final unassignedCount = _personnel.where((p) => !assignedIds.contains(p.userId)).length;

    Widget content;
    if (_isLoading || _creating) {
      content = const WaListSkeleton(count: 3, itemHeight: 140);
    } else if (_selectedView == 'unassigned_personnel') {
      content = _buildUnassignedPersonnel(t);
    } else {
      content = Stack(
        children: [
          if (parentWorks.isEmpty)
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 96.h),
                child: FxEmpty(
                  icon: Icons.assignment_outlined,
                  title: 'Chưa có nhóm công việc nào',
                  message: widget.readOnly
                      ? 'Chưa có công việc nào được bố trí cho ngày này.'
                      : 'Nhấn “Thêm việc” để chọn nhóm công việc và giao nhân sự.',
                ),
              ),
            )
          else
            ListView.builder(
              padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 96.h),
              itemCount: parentWorks.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return WaStatStrip(
                    stats: [
                      WaStat('Nhóm việc', '${parentWorks.length}', tone: FxTokens.indigo),
                      WaStat('Đã giao', '${assignedIds.length}', tone: FxTokens.emerald),
                      WaStat('Chưa giao', '$unassignedCount', tone: FxTokens.amber),
                    ],
                  );
                }
                return _buildParentCard(parentWorks[index - 1], t);
              },
            ),
          if (!widget.readOnly)
            Positioned(
              bottom: 16.h,
              right: 16.w,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: _showAddWorkSelector,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm việc'),
              ),
            ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
          child: Row(
            children: [
              WaDateChip(label: isToday ? l10n.today : DateFormat('dd/MM').format(_selectedDate), onTap: _pickDate),
              SizedBox(width: 8.w),
              WaToolButton(icon: Icons.refresh_rounded, tooltip: 'Tải lại', onTap: _loadData),
              SizedBox(width: 10.w),
              Expanded(
                child: WaSegmented<String>(
                  value: _selectedView,
                  onChanged: (val) => setState(() => _selectedView = val),
                  options: [
                    WaViewOption('assigned', 'Bố trí', count: parentWorks.length),
                    WaViewOption('unassigned_personnel', 'Chưa giao', count: unassignedCount),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: content),
        if (_dirty && !widget.readOnly)
          WaSaveBar(title: 'Có thay đổi chưa lưu', subtitle: 'Phân công công việc', saving: _saving, onSave: _save),
      ],
    );
  }

  Widget _buildParentCard(WorkTaskItem parent, FxTokens t) {
    final childWorks = _works.where((w) => w.workRoot == parent.workId).toList();
    final tasks = childWorks.isNotEmpty ? childWorks : [parent];

    int totalAssigned = 0;
    for (var task in tasks) {
      final assignment = _draft.taskAssignments.firstWhere(
        (a) => a.workId == task.workId,
        orElse: () => TaskAssignmentItem(assignmentId: '', workId: task.workId, userIds: []),
      );
      totalAssigned += assignment.userIds.length;
    }

    return FxCard(
      key: ValueKey('parent_${parent.workId}'),
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const FxIconBadge(icon: Icons.handyman_rounded, tone: FxTokens.indigo, size: 36),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parent.workName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.h3.copyWith(letterSpacing: 0.3),
                    ),
                    SizedBox(height: 2.h),
                    Text(childWorks.isNotEmpty ? '${childWorks.length} đầu việc' : 'Công việc đơn', style: t.tiny),
                  ],
                ),
              ),
              if (totalAssigned > 0) ...[
                SizedBox(width: 6.w),
                FxPill(icon: Icons.groups_rounded, label: '$totalAssigned người', tone: FxTokens.blue),
              ],
              if (!widget.readOnly) ...[
                SizedBox(width: 6.w),
                WaIconAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Bỏ nhóm công việc',
                  tone: FxTokens.red,
                  onTap: () => _removeParentGroup(parent.workId),
                ),
              ],
            ],
          ),
          SizedBox(height: 12.h),
          ...tasks.map((task) {
            final assignment = _draft.taskAssignments.firstWhere(
              (a) => a.workId == task.workId,
              orElse: () => TaskAssignmentItem(assignmentId: '', workId: task.workId, userIds: []),
            );
            final assignedUsers = _personnel.where((p) => assignment.userIds.contains(p.userId)).toList();

            return Container(
              margin: EdgeInsets.only(bottom: task == tasks.last ? 0 : 8.h),
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: t.cardAlt,
                border: Border.all(color: t.border.withValues(alpha: 0.8)),
                borderRadius: BorderRadius.circular(FxTokens.rTile),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (childWorks.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        children: [
                          Icon(Icons.subdirectory_arrow_right_rounded, size: 15.sp, color: t.textFaint),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              task.workName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700, color: t.text),
                            ),
                          ),
                          if (assignedUsers.isNotEmpty) ...[
                            SizedBox(width: 6.w),
                            Text('${assignedUsers.length}', style: t.num(12.sp, color: t.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      ...assignedUsers.map(
                        (u) => WaPersonChip(
                          name: u.userFullName,
                          onRemove: widget.readOnly ? null : () => _removeUserFromWork(task.workId, u.userId),
                        ),
                      ),
                      if (!widget.readOnly)
                        WaAddChip(
                          label: assignedUsers.isEmpty ? 'Thêm nhân sự vào' : 'Gán thêm',
                          tone: FxTokens.indigo,
                          onTap: () => _showPersonnelSelector(task.workId),
                        ),
                      if (widget.readOnly && assignedUsers.isEmpty)
                        Text('Chưa có nhân sự', style: t.tiny.copyWith(color: t.textFaint)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
