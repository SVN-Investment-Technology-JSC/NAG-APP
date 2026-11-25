import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/data/services/work_arrangement_service.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/mixer_assignment_board_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/pump_assignment_board_v2.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/v2/wa_widgets_v2.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// v2 of `WorkAssignmentManager` ("Phân công" tab). Same constructor, state, API calls, save and
/// "Chụp lịch" flow; only the widget tree is redesigned (and uses the v2 boards).
class WorkAssignmentManagerV2 extends StatefulWidget {
  final Function(VoidCallback) onRegisterChup;
  final Function(bool) onChupLoadingChange;
  final bool readOnly;

  const WorkAssignmentManagerV2({
    super.key,
    required this.onRegisterChup,
    required this.onChupLoadingChange,
    this.readOnly = false,
  });

  @override
  State<WorkAssignmentManagerV2> createState() => _WorkAssignmentManagerV2State();
}

class _WorkAssignmentManagerV2State extends State<WorkAssignmentManagerV2> with SingleTickerProviderStateMixin {
  final WorkArrangementService _service = WorkArrangementService(ApiClient.dio);

  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _savingPump = false;
  bool _savingMixer = false;
  bool _pumpDirty = false;
  bool _mixerDirty = false;

  List<WorkPersonnel> _personnel = [];
  Set<int> _halfDayUserIds = {};
  List<WorkVehicle> _pumpVehicles = [];
  List<WorkVehicle> _mixerVehicles = [];

  WorkAssignmentDraft _pumpDraft = WorkAssignmentDraft(workDate: '', pumpAssignments: []);
  WorkMixerAssignmentDraft _mixerDraft = WorkMixerAssignmentDraft(workDate: '', mixerAssignments: []);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    widget.onRegisterChup(_handleChupLich);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Logic (verbatim from WorkAssignmentManager) ───────────────────────────

  Set<int> get _assignedUserIds {
    final set = <int>{};
    for (final a in _pumpDraft.pumpAssignments) {
      for (final ids in a.roles.values) {
        set.addAll(ids);
      }
    }
    for (final a in _mixerDraft.mixerAssignments) {
      if (a.userId != null) set.add(a.userId!);
    }
    return set;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final bootstrap = await _service.getAssignmentBootstrap(dateStr);
      if (mounted) {
        setState(() {
          _personnel = bootstrap.personnel;
          _halfDayUserIds = bootstrap.halfDayUserIds.toSet();
          _pumpVehicles = bootstrap.pumpVehicles;
          _mixerVehicles = bootstrap.mixerVehicles;
          _pumpDraft = bootstrap.pumpDraft;
          _mixerDraft = bootstrap.mixerDraft;
          _pumpDirty = false;
          _mixerDirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
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

  Future<void> _savePump() async {
    setState(() => _savingPump = true);
    try {
      final saved = await _service.savePumpAssignment(_pumpDraft);
      if (mounted) {
        setState(() {
          _pumpDraft = saved;
          _pumpDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu phân công xe bơm')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingPump = false);
    }
  }

  Future<void> _saveMixer() async {
    setState(() => _savingMixer = true);
    try {
      final saved = await _service.saveMixerAssignment(_mixerDraft);
      if (mounted) {
        setState(() {
          _mixerDraft = saved;
          _mixerDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu phân công xe trộn')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingMixer = false);
    }
  }

  Future<void> _handleChupLich() async {
    if (_pumpDirty || _mixerDirty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng lưu thay đổi trước khi chụp lịch')));
      return;
    }

    widget.onChupLoadingChange(true);
    try {
      // NOTE: Export to Excel/Image logic goes here.
      // Currently simulating network call.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tính năng chụp lịch đã được giả lập thành công')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi chụp lịch: $e')));
      }
    } finally {
      widget.onChupLoadingChange(false);
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 6.h),
          child: Row(
            children: [
              WaDateChip(label: isToday ? l10n.today : DateFormat('dd/MM').format(_selectedDate), onTap: _pickDate),
              SizedBox(width: 8.w),
              WaToolButton(icon: Icons.refresh_rounded, tooltip: 'Tải lại', onTap: _loadData),
              SizedBox(width: 10.w),
              Expanded(
                child: WaPillTabBar(
                  controller: _tabController,
                  dense: true,
                  tabs: const [
                    (icon: Icons.local_shipping_rounded, label: 'Xe bơm'),
                    (icon: Icons.fire_truck_rounded, label: 'Xe trộn'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const _BoardSkeleton()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    PumpAssignmentBoardV2(
                      personnel: _personnel,
                      assignedUserIds: _assignedUserIds,
                      vehicles: _pumpVehicles,
                      halfDaySet: _halfDayUserIds,
                      draft: _pumpDraft,
                      saving: _savingPump,
                      dirty: _pumpDirty,
                      onChangeDraft: (draft) {
                        setState(() {
                          _pumpDraft = draft;
                          _pumpDirty = true;
                        });
                      },
                      onSave: _savePump,
                      readOnly: widget.readOnly,
                    ),
                    MixerAssignmentBoardV2(
                      personnel: _personnel,
                      assignedUserIds: _assignedUserIds,
                      vehicles: _mixerVehicles,
                      halfDaySet: _halfDayUserIds,
                      draft: _mixerDraft,
                      saving: _savingMixer,
                      dirty: _mixerDirty,
                      onChangeDraft: (draft) {
                        setState(() {
                          _mixerDraft = draft;
                          _mixerDirty = true;
                        });
                      },
                      onSave: _saveMixer,
                      readOnly: widget.readOnly,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Loading state of the boards: view chips + summary + cards.
class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 10.h),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: 6.w),
                Expanded(child: FxSkeleton(height: 36.h, radius: 11)),
              ],
            ],
          ),
        ),
        const Expanded(child: WaListSkeleton(count: 3, itemHeight: 150)),
      ],
    );
  }
}
