import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/personnel_selector_sheet_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/vehicle_selector_sheet_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/wa_widgets_v2.dart';

/// v2 of `MixerAssignmentBoard` ("Xe trộn"). Same constructor and the same draft edits
/// (add / remove / reorder vehicles, set / clear the driver); only the layout changes.
class MixerAssignmentBoardV2 extends StatefulWidget {
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

  const MixerAssignmentBoardV2({
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
  State<MixerAssignmentBoardV2> createState() => _MixerAssignmentBoardV2State();
}

class _MixerAssignmentBoardV2State extends State<MixerAssignmentBoardV2> {
  String _selectedView = 'assigned'; // 'available_vehicles', 'unassigned_personnel', 'assigned'

  static const _tone = FxTokens.orange;

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    return Column(
      children: [
        _buildHeader(t),
        Expanded(child: _buildContent(t)),
        if (widget.dirty && !widget.readOnly)
          WaSaveBar(
            title: 'Có thay đổi chưa lưu',
            subtitle: 'Phân công xe trộn',
            saving: widget.saving,
            onSave: widget.onSave,
          ),
      ],
    );
  }

  Widget _buildHeader(FxTokens t) {
    final assignedVehicleIds = widget.draft.mixerAssignments.map((e) => e.vehicleId).toSet();
    final availableCount = widget.vehicles.where((v) => !assignedVehicleIds.contains(v.vehicleId)).length;
    final unassignedCount = widget.personnel.where((p) => !widget.assignedUserIds.contains(p.userId)).length;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 10.h),
      child: WaViewChips<String>(
        value: _selectedView,
        onChanged: (val) => setState(() => _selectedView = val),
        options: [
          WaViewOption('assigned', 'Bố trí', count: widget.draft.mixerAssignments.length),
          WaViewOption('available_vehicles', 'Xe trống', count: availableCount),
          WaViewOption('unassigned_personnel', 'Chưa gán', count: unassignedCount),
        ],
      ),
    );
  }

  Widget _buildContent(FxTokens t) {
    switch (_selectedView) {
      case 'available_vehicles':
        return _buildAvailableVehicles(t);
      case 'unassigned_personnel':
        return _buildUnassignedPersonnel(t);
      case 'assigned':
      default:
        return _buildAssignedList(t);
    }
  }

  Widget _centered(Widget child) => Center(
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: child,
    ),
  );

  Widget _buildAvailableVehicles(FxTokens t) {
    final assignedVehicleIds = widget.draft.mixerAssignments.map((e) => e.vehicleId).toSet();
    final available = widget.vehicles.where((v) => !assignedVehicleIds.contains(v.vehicleId)).toList();

    if (available.isEmpty) {
      return _centered(
        const FxEmpty(
          icon: Icons.fire_truck_outlined,
          title: 'Không có xe trống',
          message: 'Tất cả xe trộn đã có trong bảng bố trí.',
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 24.h),
      itemCount: available.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return WaListCaption(
            icon: Icons.info_outline_rounded,
            text: '${available.length} xe trộn chưa được bố trí · nhấn + để thêm vào bảng',
          );
        }
        final v = available[i - 1];
        return FxCard(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: WaVehicleRow(
            plate: v.vehicleLicensePlate ?? '',
            name: v.vehicleName,
            type: v.vehicleTypeName,
            icon: Icons.fire_truck_rounded,
            tone: _tone,
            trailing: WaIconAction(
              icon: Icons.add_rounded,
              tooltip: 'Thêm vào bảng bố trí',
              tone: FxTokens.blue,
              onTap: () {
                final newAssignments = List<MixerAssignmentItem>.from(widget.draft.mixerAssignments);
                newAssignments.add(
                  MixerAssignmentItem(
                    assignmentId: DateTime.now().millisecondsSinceEpoch.toString(),
                    vehicleId: v.vehicleId,
                    userId: null,
                  ),
                );
                widget.onChangeDraft(
                  WorkMixerAssignmentDraft(
                    workDate: widget.draft.workDate,
                    mixerAssignments: newAssignments,
                    updatedAt: widget.draft.updatedAt,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnassignedPersonnel(FxTokens t) {
    final unassigned = widget.personnel.where((p) => !widget.assignedUserIds.contains(p.userId)).toList();

    if (unassigned.isEmpty) {
      return _centered(const FxEmpty(icon: Icons.task_alt_rounded, title: 'Tất cả nhân sự đã được phân công'));
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 24.h),
      itemCount: unassigned.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return WaListCaption(
            icon: Icons.person_off_outlined,
            text: '${unassigned.length} nhân sự chưa có trong bảng xe bơm / xe trộn',
          );
        }
        final p = unassigned[i - 1];
        final isHalfDay = widget.halfDaySet.contains(p.userId);
        return FxCard(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: WaPersonRow(
            name: p.userFullName,
            subtitle: [p.departmentName ?? '---', if ((p.skillName ?? '').isNotEmpty) p.skillName!].join(' · '),
            pills: [if (isHalfDay) const FxPill(label: 'Nửa ngày', tone: FxTokens.amber, dot: true)],
          ),
        );
      },
    );
  }

  Widget _buildAssignedList(FxTokens t) {
    final assignments = widget.draft.mixerAssignments;

    if (assignments.isEmpty) {
      return _centered(
        FxEmpty(
          icon: Icons.assignment_ind_outlined,
          title: 'Chưa có phân công nào',
          message: 'Chọn xe trộn đang trống để bắt đầu bố trí lái xe.',
          action: OutlinedButton.icon(
            onPressed: () => setState(() => _selectedView = 'available_vehicles'),
            icon: Icon(Icons.add_rounded, size: 18.sp),
            label: const Text('Thêm từ danh sách xe trống'),
          ),
        ),
      );
    }

    final withDriver = assignments.where((a) => a.userId != null).length;

    return Stack(
      children: [
        ReorderableListView(
          padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 96.h),
          header: WaStatStrip(
            stats: [
              WaStat('Xe đã bố trí', '${assignments.length}', suffix: '/${widget.vehicles.length}', tone: _tone),
              WaStat('Có lái xe', '$withDriver', tone: FxTokens.emerald),
              WaStat('Thiếu lái xe', '${assignments.length - withDriver}', tone: FxTokens.amber),
            ],
            footer: assignments.length > 1
                ? Row(
                    children: [
                      Icon(Icons.swipe_vertical_rounded, size: 13.sp, color: t.textFaint),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          'Giữ và kéo thẻ xe để đổi thứ tự',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.tiny,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          proxyDecorator: (child, index, animation) => AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final v = Curves.easeOut.transform(animation.value);
              return Transform.scale(
                scale: 1 + 0.02 * v,
                child: Material(type: MaterialType.transparency, child: child),
              );
            },
            child: child,
          ),
          onReorder: (oldIndex, newIndex) {
            if (oldIndex >= assignments.length) return;
            if (newIndex > assignments.length) newIndex = assignments.length;
            if (oldIndex < newIndex) newIndex -= 1;
            if (oldIndex == newIndex) return;

            final newAssignments = List<MixerAssignmentItem>.from(assignments);
            final item = newAssignments.removeAt(oldIndex);
            newAssignments.insert(newIndex, item);

            widget.onChangeDraft(
              WorkMixerAssignmentDraft(
                workDate: widget.draft.workDate,
                mixerAssignments: newAssignments,
                updatedAt: widget.draft.updatedAt,
              ),
            );
          },
          children: [
            for (int index = 0; index < assignments.length; index++) _buildAssignmentCard(assignments[index], index, t),
          ],
        ),
        Positioned(
          bottom: 16.h,
          right: 16.w,
          child: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () {
              final assignedVehicleIds = widget.draft.mixerAssignments.map((e) => e.vehicleId).toSet();
              final available = widget.vehicles.where((v) => !assignedVehicleIds.contains(v.vehicleId)).toList();
              VehicleSelectorSheetV2.show(context, available, (v) {
                final newAssignments = List<MixerAssignmentItem>.from(widget.draft.mixerAssignments);
                newAssignments.add(
                  MixerAssignmentItem(
                    assignmentId: DateTime.now().millisecondsSinceEpoch.toString(),
                    vehicleId: v.vehicleId,
                    userId: null,
                  ),
                );
                widget.onChangeDraft(
                  WorkMixerAssignmentDraft(
                    workDate: widget.draft.workDate,
                    mixerAssignments: newAssignments,
                    updatedAt: widget.draft.updatedAt,
                  ),
                );
              });
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm xe trộn'),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentCard(MixerAssignmentItem assignment, int index, FxTokens t) {
    final assignments = widget.draft.mixerAssignments;
    final vehicle = widget.vehicles.firstWhere(
      (v) => v.vehicleId == assignment.vehicleId,
      orElse: () => WorkVehicle(vehicleId: 0, vehicleLicensePlate: 'Unknown'),
    );

    final assignedUser = assignment.userId != null
        ? widget.personnel.where((p) => p.userId == assignment.userId).firstOrNull
        : null;
    final name = vehicle.vehicleName ?? '';

    Widget driver;
    if (assignedUser != null) {
      driver = WaPersonChip(
        name: assignedUser.userFullName,
        onRemove: widget.readOnly
            ? null
            : () {
                final newAssignments = List<MixerAssignmentItem>.from(widget.draft.mixerAssignments);
                newAssignments[index] = MixerAssignmentItem(
                  assignmentId: assignment.assignmentId,
                  vehicleId: assignment.vehicleId,
                  userId: null,
                );
                widget.onChangeDraft(
                  WorkMixerAssignmentDraft(
                    workDate: widget.draft.workDate,
                    mixerAssignments: newAssignments,
                    updatedAt: widget.draft.updatedAt,
                  ),
                );
              },
      );
    } else if (!widget.readOnly) {
      driver = WaAddChip(label: 'Thêm', onTap: () => _showPersonnelSelector(assignment, index));
    } else {
      driver = SizedBox(
        height: 30.w,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Chưa có', style: t.tiny.copyWith(color: t.textFaint)),
        ),
      );
    }

    return FxCard(
      key: ValueKey(assignment.assignmentId),
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.fromLTRB(10.w, 12.h, 12.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.drag_indicator_rounded, size: 18.sp, color: t.textFaint),
              SizedBox(width: 4.w),
              const FxIconBadge(icon: Icons.fire_truck_rounded, tone: _tone, size: 36),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.vehicleLicensePlate ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.h2.copyWith(fontFeatures: FxTokens.tabular, letterSpacing: 0.2),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      name.isEmpty ? 'Thứ tự #${index + 1}' : 'Thứ tự #${index + 1} · $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              FxPill(
                label: assignedUser != null ? 'Có lái xe' : 'Thiếu lái xe',
                tone: assignedUser != null ? FxTokens.emerald : FxTokens.amber,
                dot: true,
              ),
              SizedBox(width: 6.w),
              WaIconAction(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Bỏ xe khỏi bảng',
                tone: FxTokens.red,
                onTap: () {
                  final newAssignments = List<MixerAssignmentItem>.from(assignments);
                  newAssignments.removeAt(index);
                  widget.onChangeDraft(
                    WorkMixerAssignmentDraft(
                      workDate: widget.draft.workDate,
                      mixerAssignments: newAssignments,
                      updatedAt: widget.draft.updatedAt,
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: t.cardAlt,
              borderRadius: BorderRadius.circular(FxTokens.rTile),
              border: Border.all(color: t.border.withValues(alpha: 0.8)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 82.w,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: FxPill(label: 'Lái xe', tone: FxTokens.blue),
                  ),
                ),
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: driver),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPersonnelSelector(MixerAssignmentItem assignment, int index) {
    final unassigned = widget.personnel.where((p) => !widget.assignedUserIds.contains(p.userId)).toList();
    PersonnelSelectorSheetV2.show(context, unassigned, (p) {
      final newAssignments = List<MixerAssignmentItem>.from(widget.draft.mixerAssignments);
      newAssignments[index] = MixerAssignmentItem(
        assignmentId: assignment.assignmentId,
        vehicleId: assignment.vehicleId,
        userId: p.userId,
      );

      widget.onChangeDraft(
        WorkMixerAssignmentDraft(
          workDate: widget.draft.workDate,
          mixerAssignments: newAssignments,
          updatedAt: widget.draft.updatedAt,
        ),
      );
    });
  }
}
