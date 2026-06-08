import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';
import 'package:nguyenanh/features/work_arrangement/data/services/work_arrangement_service.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/mixer_assignment_board.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/pump_assignment_board.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class WorkAssignmentManager extends StatefulWidget {
  final Function(VoidCallback) onRegisterChup;
  final Function(bool) onChupLoadingChange;

  const WorkAssignmentManager({
    super.key,
    required this.onRegisterChup,
    required this.onChupLoadingChange,
  });

  @override
  State<WorkAssignmentManager> createState() => _WorkAssignmentManagerState();
}

class _WorkAssignmentManagerState extends State<WorkAssignmentManager> with SingleTickerProviderStateMixin {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
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

  Future<void> _savePump() async {
    setState(() => _savingPump = true);
    try {
      final saved = await _service.savePumpAssignment(_pumpDraft);
      if (mounted) {
        setState(() {
          _pumpDraft = saved;
          _pumpDirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu phân công xe bơm')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu phân công xe trộn')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMixer = false);
    }
  }

  Future<void> _handleChupLich() async {
    if (_pumpDirty || _mixerDirty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng lưu thay đổi trước khi chụp lịch')),
      );
      return;
    }
    
    widget.onChupLoadingChange(true);
    try {
      // NOTE: Export to Excel/Image logic goes here.
      // Currently simulating network call.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tính năng chụp lịch đã được giả lập thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chụp lịch: $e')),
        );
      }
    } finally {
      widget.onChupLoadingChange(false);
    }
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
              Container(
                height: 36.h,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  labelPadding: EdgeInsets.symmetric(horizontal: 16.w),
                  labelColor: colorScheme.onPrimary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicator: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Xe bơm'),
                    Tab(text: 'Xe trộn'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    PumpAssignmentBoard(
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
                    ),
                    MixerAssignmentBoard(
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
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
