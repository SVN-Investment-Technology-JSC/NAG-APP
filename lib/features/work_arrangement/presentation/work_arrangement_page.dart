import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/work_assignment_manager.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/work_task_manager.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/work_attendance_manager.dart';

class WorkArrangementPage extends StatefulWidget {
  const WorkArrangementPage({super.key});

  @override
  State<WorkArrangementPage> createState() => _WorkArrangementPageState();
}

class _WorkArrangementPageState extends State<WorkArrangementPage>
    with TickerProviderStateMixin {
  TabController? _tabController;
  VoidCallback? _doChupLich;
  bool _isChupLoading = false;

  final UserManageService _userManageService = UserManageService();
  String _userRole = '';
  bool _isLoading = true;
  bool _canViewArrangements = false;
  bool _canViewAttendance = false;
  bool _canUpdateArrangements = false;
  bool _canUpdateAttendance = false;

  final List<String> _activeTabNames = [];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canViewArrangements = _userRole == 'admin' || myPerms.contains('/work-arrangements__view');
          _canViewAttendance = _userRole == 'admin' || myPerms.contains('/work-attendance__view');
          _canUpdateArrangements = _userRole == 'admin' || myPerms.contains('/work-arrangements__update');
          _canUpdateAttendance = _userRole == 'admin' || myPerms.contains('/work-attendance__update');

          _activeTabNames.clear();
          if (_canViewArrangements) {
            _activeTabNames.add('Phân công');
            _activeTabNames.add('Công việc');
          }
          if (_canViewAttendance) {
            _activeTabNames.add('Chấm công');
          }

          if (_activeTabNames.isNotEmpty) {
            _tabController = TabController(length: _activeTabNames.length, vsync: this);
            _tabController!.addListener(() {
              setState(() {});
            });
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeTabNames.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Bố trí công việc',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        body: const Center(child: Text('Bạn không có quyền truy cập chức năng này')),
      );
    }

    final tabs = <Tab>[];
    final tabChildren = <Widget>[];

    if (_canViewArrangements) {
      tabs.add(const Tab(text: 'Phân công'));
      tabChildren.add(WorkAssignmentManager(
        onRegisterChup: (fn) {
          _doChupLich = fn;
        },
        onChupLoadingChange: (loading) {
          setState(() {
            _isChupLoading = loading;
          });
        },
        readOnly: !_canUpdateArrangements,
      ));

      tabs.add(const Tab(text: 'Công việc'));
      tabChildren.add(WorkTaskManager(
        readOnly: !_canUpdateArrangements,
      ));
    }

    if (_canViewAttendance) {
      tabs.add(const Tab(text: 'Chấm công'));
      tabChildren.add(WorkAttendanceManager(
        readOnly: !_canUpdateAttendance,
      ));
    }

    // Determine if we show the camera snapshot icon
    final isPhanCongTabActive = _canViewArrangements && _tabController != null && _tabController!.index == 0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Bố trí công việc',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (isPhanCongTabActive && _canUpdateArrangements)
            IconButton(
              icon: _isChupLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              tooltip: 'Chụp lịch',
              onPressed: _isChupLoading ? null : _doChupLich,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: TabBar(
            controller: _tabController,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            onTap: (index) {
              setState(() {});
            },
            tabs: tabs,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: tabChildren,
      ),
    );
  }
}
