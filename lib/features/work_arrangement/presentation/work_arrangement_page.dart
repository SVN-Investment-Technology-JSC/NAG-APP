import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/work_assignment_manager.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/work_task_manager.dart';
import 'package:nguyenanh/features/work_arrangement/presentation/widgets/work_attendance_manager.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class WorkArrangementPage extends StatefulWidget {
  const WorkArrangementPage({super.key});

  @override
  State<WorkArrangementPage> createState() => _WorkArrangementPageState();
}

class _WorkArrangementPageState extends State<WorkArrangementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  VoidCallback? _doChupLich;
  bool _isChupLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Bố trí công việc',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_tabController.index == 0) // Only show in "Phân công" tab
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
              setState(() {}); // Re-render to show/hide actions based on tab
            },
            tabs: const [
              Tab(text: 'Phân công'),
              Tab(text: 'Công việc'),
              Tab(text: 'Chấm công'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe to avoid gesture conflicts with drag-and-drop
        children: [
          WorkAssignmentManager(
            onRegisterChup: (fn) {
              _doChupLich = fn;
            },
            onChupLoadingChange: (loading) {
              setState(() {
                _isChupLoading = loading;
              });
            },
          ),
          const WorkTaskManager(),
          const WorkAttendanceManager(),
        ],
      ),
    );
  }
}

