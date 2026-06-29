import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/personnel_selector_sheet.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/vehicle_selector_sheet.dart';

class MixerAssignmentBoard extends StatefulWidget {
  final List<WorkPersonnel> personnel;
  final Set<int> assignedUserIds;
  final List<WorkVehicle> vehicles;
  final Set<int> halfDaySet;
  final WorkMixerAssignmentDraft draft;
  final bool saving;
  final bool dirty;
  final Function(WorkMixerAssignmentDraft) onChangeDraft;
  final VoidCallback onSave;

  final bool readOnly;

  const MixerAssignmentBoard({
    super.key,
    required this.personnel,
    required this.assignedUserIds,
    required this.vehicles,
    required this.halfDaySet,
    required this.draft,
    required this.saving,
    required this.dirty,
    required this.onChangeDraft,
    required this.onSave,
    this.readOnly = false,
  });

  @override
  State<MixerAssignmentBoard> createState() => _MixerAssignmentBoardState();
}

class _MixerAssignmentBoardState extends State<MixerAssignmentBoard> {
  String _selectedView = 'assigned'; // 'available_vehicles', 'unassigned_personnel', 'assigned'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        _buildHeader(theme, colorScheme),
        Expanded(
          child: _buildContent(theme, colorScheme),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                DropdownMenuItem(value: 'assigned', child: Text('Bố trí xe trộn')),
                DropdownMenuItem(value: 'available_vehicles', child: Text('Các xe đang trống')),
                DropdownMenuItem(value: 'unassigned_personnel', child: Text('Nhân sự chưa phân công')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedView = val);
              },
            ),
          ),
          if (widget.dirty && !widget.readOnly) ...[
            SizedBox(width: 12.w),
            FilledButton(
              onPressed: widget.saving ? null : widget.onSave,
              child: widget.saving
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
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    switch (_selectedView) {
      case 'available_vehicles':
        return _buildAvailableVehicles(theme, colorScheme);
      case 'unassigned_personnel':
        return _buildUnassignedPersonnel(theme, colorScheme);
      case 'assigned':
      default:
        return _buildAssignedList(theme, colorScheme);
    }
  }

  Widget _buildAvailableVehicles(ThemeData theme, ColorScheme colorScheme) {
    final assignedVehicleIds = widget.draft.mixerAssignments.map((e) => e.vehicleId).toSet();
    final available = widget.vehicles.where((v) => !assignedVehicleIds.contains(v.vehicleId)).toList();

    if (available.isEmpty) {
      return const Center(child: Text('Không có xe trống'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: available.length,
      itemBuilder: (context, index) {
        final v = available[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: Icon(Icons.fire_truck, color: colorScheme.primary),
            title: Text(v.vehicleLicensePlate ?? ''),
            subtitle: Text(v.vehicleName ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                final newAssignments = List<MixerAssignmentItem>.from(widget.draft.mixerAssignments);
                newAssignments.add(MixerAssignmentItem(
                  assignmentId: DateTime.now().millisecondsSinceEpoch.toString(),
                  vehicleId: v.vehicleId,
                  userId: null,
                ));
                widget.onChangeDraft(WorkMixerAssignmentDraft(
                  workDate: widget.draft.workDate,
                  mixerAssignments: newAssignments,
                  updatedAt: widget.draft.updatedAt,
                ));
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnassignedPersonnel(ThemeData theme, ColorScheme colorScheme) {
    final unassigned = widget.personnel.where((p) => !widget.assignedUserIds.contains(p.userId)).toList();

    if (unassigned.isEmpty) {
      return const Center(child: Text('Tất cả nhân sự đã được phân công'));
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: unassigned.length,
      itemBuilder: (context, index) {
        final p = unassigned[index];
        final isHalfDay = widget.halfDaySet.contains(p.userId);
        return Card(
          margin: EdgeInsets.only(bottom: 8.h),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Text(p.userFullName.substring(0, 1).toUpperCase()),
            ),
            title: Text(p.userFullName),
            subtitle: Text(p.departmentName ?? '---'),
            trailing: isHalfDay
                ? Chip(
                    label: const Text('Nửa ngày'),
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.orange),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildAssignedList(ThemeData theme, ColorScheme colorScheme) {
    final assignments = widget.draft.mixerAssignments;

    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_ind_outlined, size: 48.sp, color: colorScheme.outline),
            SizedBox(height: 16.h),
            const Text('Chưa có phân công nào'),
            SizedBox(height: 16.h),
            OutlinedButton(
              onPressed: () => setState(() => _selectedView = 'available_vehicles'),
              child: const Text('Thêm từ danh sách xe trống'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ReorderableListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 80.h),
          onReorder: (oldIndex, newIndex) {
            if (oldIndex >= assignments.length) return;
            if (newIndex > assignments.length) newIndex = assignments.length;
            if (oldIndex < newIndex) newIndex -= 1;
            if (oldIndex == newIndex) return;

            final newAssignments = List<MixerAssignmentItem>.from(assignments);
            final item = newAssignments.removeAt(oldIndex);
            newAssignments.insert(newIndex, item);

            widget.onChangeDraft(WorkMixerAssignmentDraft(
              workDate: widget.draft.workDate,
              mixerAssignments: newAssignments,
              updatedAt: widget.draft.updatedAt,
            ));
          },
          children: [
            for (int index = 0; index < assignments.length; index++)
              _buildAssignmentCard(assignments[index], index, theme, colorScheme),
          ],
        ),
        Positioned(
          bottom: 16.h,
          right: 16.w,
          child: FloatingActionButton.extended(
            onPressed: () {
              final assignedVehicleIds = widget.draft.mixerAssignments.map((e) => e.vehicleId).toSet();
              final available = widget.vehicles.where((v) => !assignedVehicleIds.contains(v.vehicleId)).toList();
              VehicleSelectorSheet.show(context, available, (v) {
                final newAssignments = List<MixerAssignmentItem>.from(widget.draft.mixerAssignments);
                newAssignments.add(MixerAssignmentItem(
                  assignmentId: DateTime.now().millisecondsSinceEpoch.toString(),
                  vehicleId: v.vehicleId,
                  userId: null,
                ));
                widget.onChangeDraft(WorkMixerAssignmentDraft(
                  workDate: widget.draft.workDate,
                  mixerAssignments: newAssignments,
                  updatedAt: widget.draft.updatedAt,
                ));
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Thêm xe trộn'),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(MixerAssignmentItem assignment, int index, ThemeData theme, ColorScheme colorScheme) {
    final assignments = widget.draft.mixerAssignments;
    final vehicle = widget.vehicles.firstWhere(
      (v) => v.vehicleId == assignment.vehicleId,
      orElse: () => WorkVehicle(vehicleId: 0, vehicleLicensePlate: 'Unknown'),
    );
    
    final assignedUser = assignment.userId != null 
      ? widget.personnel.where((p) => p.userId == assignment.userId).firstOrNull
      : null;

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
                Icon(Icons.fire_truck, color: colorScheme.primary),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    vehicle.vehicleLicensePlate ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    final newAssignments = List<MixerAssignmentItem>.from(assignments);
                    newAssignments.removeAt(index);
                    widget.onChangeDraft(WorkMixerAssignmentDraft(
                      workDate: widget.draft.workDate,
                      mixerAssignments: newAssignments,
                      updatedAt: widget.draft.updatedAt,
                    ));
                  },
                ),
              ],
            ),
            Divider(color: colorScheme.outlineVariant),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80.w,
                    child: Text(
                      'Lái xe',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 4.h,
                      children: [
                        if (assignedUser != null)
                          Chip(
                            label: Text(assignedUser.userFullName, overflow: TextOverflow.ellipsis),
                            onDeleted: widget.readOnly
                                ? null
                                : () {
                                    final newAssignments = List<MixerAssignmentItem>.from(widget.draft.mixerAssignments);
                                    newAssignments[index] = MixerAssignmentItem(
                                      assignmentId: assignment.assignmentId,
                                      vehicleId: assignment.vehicleId,
                                      userId: null,
                                    );
                                    widget.onChangeDraft(WorkMixerAssignmentDraft(
                                      workDate: widget.draft.workDate,
                                      mixerAssignments: newAssignments,
                                      updatedAt: widget.draft.updatedAt,
                                    ));
                                  },
                            deleteIcon: widget.readOnly ? null : const Icon(Icons.close, size: 16),
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          )
                        else if (!widget.readOnly)
                          ActionChip(
                            label: const Icon(Icons.add, size: 16),
                            onPressed: () => _showPersonnelSelector(assignment, index),
                            backgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
                            shape: const CircleBorder(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonnelSelector(MixerAssignmentItem assignment, int index) {
    final unassigned = widget.personnel.where((p) => !widget.assignedUserIds.contains(p.userId)).toList();
    PersonnelSelectorSheet.show(context, unassigned, (p) {
      final newAssignments = List<MixerAssignmentItem>.from(widget.draft.mixerAssignments);
      newAssignments[index] = MixerAssignmentItem(
        assignmentId: assignment.assignmentId,
        vehicleId: assignment.vehicleId,
        userId: p.userId,
      );

      widget.onChangeDraft(WorkMixerAssignmentDraft(
        workDate: widget.draft.workDate,
        mixerAssignments: newAssignments,
        updatedAt: widget.draft.updatedAt,
      ));
    });
  }
}
