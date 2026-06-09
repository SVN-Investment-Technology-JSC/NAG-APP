import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/personnel_selector_sheet.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/vehicle_selector_sheet.dart';

class PumpAssignmentBoard extends StatefulWidget {
  final List<WorkPersonnel> personnel;
  final Set<int> assignedUserIds;
  final List<WorkVehicle> vehicles;
  final Set<int> halfDaySet;
  final WorkAssignmentDraft draft;
  final bool saving;
  final bool dirty;
  final Function(WorkAssignmentDraft) onChangeDraft;
  final VoidCallback onSave;

  const PumpAssignmentBoard({
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
  });

  @override
  State<PumpAssignmentBoard> createState() => _PumpAssignmentBoardState();
}

class _PumpAssignmentBoardState extends State<PumpAssignmentBoard> {
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
                DropdownMenuItem(value: 'assigned', child: Text('Bố trí xe bơm')),
                DropdownMenuItem(value: 'available_vehicles', child: Text('Các xe đang trống')),
                DropdownMenuItem(value: 'unassigned_personnel', child: Text('Nhân sự chưa phân công')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedView = val);
              },
            ),
          ),
          if (widget.dirty) ...[
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
    final assignedVehicleIds = widget.draft.pumpAssignments.map((e) => e.vehicleId).toSet();
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
            leading: Icon(Icons.local_shipping, color: colorScheme.primary),
            title: Text(v.vehicleLicensePlate ?? ''),
            subtitle: Text(v.vehicleName ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                // Add vehicle to assigned list
                final newAssignments = List<PumpAssignmentItem>.from(widget.draft.pumpAssignments);
                newAssignments.add(PumpAssignmentItem(
                  assignmentId: DateTime.now().millisecondsSinceEpoch.toString(),
                  vehicleId: v.vehicleId,
                  roles: {'driver': [], 'operator': [], 'hose': []},
                ));
                widget.onChangeDraft(WorkAssignmentDraft(
                  workDate: widget.draft.workDate,
                  pumpAssignments: newAssignments,
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
    final assignments = widget.draft.pumpAssignments;

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

            final newAssignments = List<PumpAssignmentItem>.from(assignments);
            final item = newAssignments.removeAt(oldIndex);
            newAssignments.insert(newIndex, item);

            widget.onChangeDraft(WorkAssignmentDraft(
              workDate: widget.draft.workDate,
              pumpAssignments: newAssignments,
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
              final assignedVehicleIds = widget.draft.pumpAssignments.map((e) => e.vehicleId).toSet();
              final available = widget.vehicles.where((v) => !assignedVehicleIds.contains(v.vehicleId)).toList();
              VehicleSelectorSheet.show(context, available, (v) {
                final newAssignments = List<PumpAssignmentItem>.from(widget.draft.pumpAssignments);
                newAssignments.add(PumpAssignmentItem(
                  assignmentId: DateTime.now().millisecondsSinceEpoch.toString(),
                  vehicleId: v.vehicleId,
                  roles: {'driver': [], 'operator': [], 'hose': []},
                ));
                widget.onChangeDraft(WorkAssignmentDraft(
                  workDate: widget.draft.workDate,
                  pumpAssignments: newAssignments,
                  updatedAt: widget.draft.updatedAt,
                ));
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Thêm xe bơm'),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(PumpAssignmentItem assignment, int index, ThemeData theme, ColorScheme colorScheme) {
    final assignments = widget.draft.pumpAssignments;
    final vehicle = widget.vehicles.firstWhere(
      (v) => v.vehicleId == assignment.vehicleId,
      orElse: () => WorkVehicle(vehicleId: 0, vehicleLicensePlate: 'Unknown'),
    );

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
                Icon(Icons.local_shipping, color: colorScheme.primary),
                SizedBox(width: 8.w),
                Text(
                  vehicle.vehicleLicensePlate ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    final newAssignments = List<PumpAssignmentItem>.from(assignments);
                    newAssignments.removeAt(index);
                    widget.onChangeDraft(WorkAssignmentDraft(
                      workDate: widget.draft.workDate,
                      pumpAssignments: newAssignments,
                      updatedAt: widget.draft.updatedAt,
                    ));
                  },
                ),
              ],
            ),
            Divider(color: colorScheme.outlineVariant),
            _buildRoleRow('Lái xe', 'driver', assignment, theme, colorScheme),
            _buildRoleRow('Vận hành', 'operator', assignment, theme, colorScheme),
            _buildRoleRow('Phụ vòi', 'hose', assignment, theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleRow(String label, String roleKey, PumpAssignmentItem assignment, ThemeData theme, ColorScheme colorScheme) {
    final userIds = assignment.roles[roleKey] ?? [];
    final assignedUsers = widget.personnel.where((p) => userIds.contains(p.userId)).toList();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              label,
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
                ...assignedUsers.map((u) => Chip(
                      label: Text(u.userFullName),
                      onDeleted: () {
                        // Remove user
                        final newRoles = Map<String, List<int>>.from(assignment.roles);
                        newRoles[roleKey] = List<int>.from(newRoles[roleKey] ?? [])..remove(u.userId);
                        
                        final newAssignments = List<PumpAssignmentItem>.from(widget.draft.pumpAssignments);
                        final index = newAssignments.indexWhere((a) => a.assignmentId == assignment.assignmentId);
                        newAssignments[index] = PumpAssignmentItem(
                          assignmentId: assignment.assignmentId,
                          vehicleId: assignment.vehicleId,
                          roles: newRoles,
                        );

                        widget.onChangeDraft(WorkAssignmentDraft(
                          workDate: widget.draft.workDate,
                          pumpAssignments: newAssignments,
                          updatedAt: widget.draft.updatedAt,
                        ));
                      },
                      deleteIcon: const Icon(Icons.close, size: 16),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    )),
                ActionChip(
                  label: const Icon(Icons.add, size: 16),
                  onPressed: () => _showPersonnelSelector(assignment, roleKey),
                  backgroundColor: colorScheme.primaryContainer.withOpacity(0.5),
                  shape: const CircleBorder(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPersonnelSelector(PumpAssignmentItem assignment, String roleKey) {
    final unassigned = widget.personnel.where((p) => !widget.assignedUserIds.contains(p.userId)).toList();
    PersonnelSelectorSheet.show(context, unassigned, (p) {
      final newRoles = Map<String, List<int>>.from(assignment.roles);
      newRoles[roleKey] = List<int>.from(newRoles[roleKey] ?? [])..add(p.userId);
      
      final newAssignments = List<PumpAssignmentItem>.from(widget.draft.pumpAssignments);
      final idx = newAssignments.indexWhere((a) => a.assignmentId == assignment.assignmentId);
      newAssignments[idx] = PumpAssignmentItem(
        assignmentId: assignment.assignmentId,
        vehicleId: assignment.vehicleId,
        roles: newRoles,
      );

      widget.onChangeDraft(WorkAssignmentDraft(
        workDate: widget.draft.workDate,
        pumpAssignments: newAssignments,
        updatedAt: widget.draft.updatedAt,
      ));
    });
  }
}
