import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/models/parking_idle_engine_models.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/services/parking_idle_engine_service.dart';
import 'package:nguyenanh/features/parking_idle_engine/presentation/widgets/parking_idle_engine_settings_dialog.dart';
import 'package:nguyenanh/features/parking_idle_engine/presentation/widgets/parking_idle_engine_detail_sheet.dart';

class ParkingIdleEngineDashboardPage extends StatefulWidget {
  const ParkingIdleEngineDashboardPage({super.key});

  @override
  State<ParkingIdleEngineDashboardPage> createState() => _ParkingIdleEngineDashboardPageState();
}

class _ParkingIdleEngineDashboardPageState extends State<ParkingIdleEngineDashboardPage> {
  final ParkingIdleEngineService _apiService = ParkingIdleEngineService();
  final UserManageService _userService = UserManageService();
  final TextEditingController _searchController = TextEditingController();

  ParkingIdleEngineAlertsResponse? _dashboardData;
  bool _isLoading = true;
  bool _warningOnly = false;
  bool _canSettings = false;
  String _searchQuery = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _checkPermissions();
    // Auto refresh every 30 seconds like React
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role') ?? '';
      final perms = await _userService.getPermissions();
      final myPerms = perms[role] ?? [];
      if (mounted) {
        setState(() {
          _canSettings = role == 'admin' || myPerms.contains('/parking-idle-engine__settings');
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final res = await _apiService.getAlerts(warningOnly: _warningOnly);
      if (mounted) {
        setState(() {
          _dashboardData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải dữ liệu giám sát nổ máy')),
        );
      }
    }
  }

  List<ParkingIdleEngineAlert> get _filteredAndSortedItems {
    if (_dashboardData == null) return [];
    var items = List<ParkingIdleEngineAlert>.from(_dashboardData!.items);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items.where((i) =>
        i.vehicleName.toLowerCase().contains(q) ||
        i.vehicleLicensePlate.toLowerCase().contains(q)
      ).toList();
    }

    items.sort((a, b) {
      // 1. In yard > Not in yard
      if (a.inYard && !b.inYard) return -1;
      if (!a.inYard && b.inYard) return 1;

      // 2. Engine ON > Engine OFF
      if (a.engineState == 'on' && b.engineState != 'on') return -1;
      if (a.engineState != 'on' && b.engineState == 'on') return 1;

      // 3. Sort by elapsed minutes descending
      return b.elapsedMinutes.compareTo(a.elapsedMinutes);
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          'Giám sát nổ máy trong bãi',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
            onPressed: () => _fetchData(),
          ),
          if (_canSettings)
            IconButton(
              icon: Icon(Icons.settings_outlined, color: colorScheme.primary),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ParkingIdleEngineSettingsDialog(
                    apiService: _apiService,
                    onSaveSuccess: () => _fetchData(),
                  ),
                );
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchData(showLoading: false),
        child: Column(
          children: [
            // Controls Section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38.h,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 16.sp, color: Colors.grey[400]),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: theme.textTheme.bodyMedium,
                              decoration: const InputDecoration(
                                hintText: 'Tìm kiếm xe...',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: Icon(Icons.close_rounded, size: 16.sp, color: Colors.grey[400]),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // KPI Grid
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildKPICard(
                          label: 'TỔNG XE BỒN',
                          value: _dashboardData?.totalVehicles ?? 0,
                          icon: Icons.local_shipping_rounded,
                          color: const Color(0xFF6366F1),
                          bgColor: const Color(0xFFEEF2FF),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildKPICard(
                          label: 'XE TRONG BÃI',
                          value: _dashboardData?.inYardCount ?? 0,
                          icon: Icons.pin_drop_rounded,
                          color: const Color(0xFF3B82F6),
                          bgColor: const Color(0xFFEFF6FF),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKPICard(
                          label: 'ĐANG NỔ MÁY',
                          value: _dashboardData?.engineOnCount ?? 0,
                          icon: Icons.power_rounded,
                          color: const Color(0xFFF59E0B),
                          bgColor: const Color(0xFFFFFBEB),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: _buildKPICard(
                          label: 'ĐANG CẢNH BÁO',
                          value: _dashboardData?.warningCount ?? 0,
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFEF4444),
                          bgColor: const Color(0xFFFEF2F2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Table Header / Subtitle
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: Row(
                children: [
                  Icon(Icons.local_gas_station_rounded, color: const Color(0xFF6366F1), size: 18.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danh sách xe bồn',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${_filteredAndSortedItems.length} xe · Nhấn để xem lịch sử',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // "Chỉ cảnh báo" Filter Chip
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _warningOnly = !_warningOnly;
                      });
                      _fetchData();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: _warningOnly ? const Color(0xFFFEF2F2) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: _warningOnly ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _warningOnly ? Icons.warning_amber_rounded : Icons.filter_alt_outlined,
                            size: 12.sp,
                            color: _warningOnly ? const Color(0xFFEF4444) : Colors.grey[600],
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Chỉ cảnh báo',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: _warningOnly ? const Color(0xFFEF4444) : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 16.h, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator.adaptive())
                  : _filteredAndSortedItems.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty ? 'Không tìm thấy xe phù hợp' : 'Không có xe nào',
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                          itemCount: _filteredAndSortedItems.length,
                          separatorBuilder: (_, _) => SizedBox(height: 6.h),
                          itemBuilder: (context, idx) {
                            final alert = _filteredAndSortedItems[idx];
                            return _buildVehicleRow(alert);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[50]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 18.sp),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[400],
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'xe',
                      style: TextStyle(fontSize: 8.sp, color: Colors.grey[400], fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBadge(ParkingIdleEngineAlert alert) {
    if (alert.warningActive) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 10.sp, color: Colors.red[700]),
            SizedBox(width: 2.w),
            Text(
              'CẢNH BÁO',
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, size: 10.sp, color: Colors.grey[500]),
            SizedBox(width: 2.w),
            Text(
              'Theo dõi',
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildEngineStateBadge(ParkingIdleEngineAlert alert) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: alert.engineState == 'on' ? Colors.orange[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 11.sp,
            color: alert.engineState == 'on' ? Colors.orange[700] : Colors.grey[400],
          ),
          SizedBox(width: 2.w),
          Text(
            alert.engineState == 'on' ? 'Đang nổ máy' : 'Tắt máy',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: alert.engineState == 'on' ? Colors.orange[700] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleRow(ParkingIdleEngineAlert alert) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Opacity(
      opacity: alert.inYard ? 1.0 : 0.5,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(
            color: alert.warningActive && alert.inYard
                ? Colors.red[100]!
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: alert.warningActive && alert.inYard ? 1.5 : 1.0,
          ),
        ),
        color: alert.warningActive && alert.inYard ? Colors.red[50]!.withValues(alpha: 0.2) : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () {
            ParkingIdleEngineDetailSheet.show(context, alert, _apiService);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Icon
                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: alert.inYard ? const Color(0xFFEEF2FF) : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: alert.inYard ? const Color(0xFF6366F1) : Colors.grey[400],
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 10.w),

                // Main Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Name and Warning/Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              alert.vehicleName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 14.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          if (alert.inYard)
                            _buildWarningBadge(alert)
                          else
                            Text(
                              '—',
                              style: TextStyle(color: Colors.grey[400], fontSize: 11.sp, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      // Bottom Row: Plate/Yard Tag (Left) & Engine/Timer (Right)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Left side: Plate & Yard Tag
                          Expanded(
                            child: Wrap(
                              spacing: 6.w,
                              runSpacing: 4.h,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  alert.vehicleLicensePlate,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: alert.inYard ? const Color(0xFFECFDF5) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.pin_drop_rounded,
                                        size: 8.sp,
                                        color: alert.inYard ? const Color(0xFF047857) : Colors.grey[500],
                                      ),
                                      SizedBox(width: 2.w),
                                      Text(
                                        alert.inYard ? 'Trong bãi' : 'Ngoài bãi',
                                        style: TextStyle(
                                          fontSize: 8.sp,
                                          fontWeight: FontWeight.bold,
                                          color: alert.inYard ? const Color(0xFF047857) : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Right side: Engine State and Timer
                          if (alert.inYard)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildEngineStateBadge(alert),
                                SizedBox(width: 6.w),
                                LiveElapsedTimer(
                                  idleStartedAt: alert.idleStartedAt,
                                  fallbackMinutes: alert.elapsedMinutes,
                                  isWarning: alert.warningActive,
                                ),
                              ],
                            )
                          else
                            Text(
                              '—',
                              style: TextStyle(color: Colors.grey[400], fontSize: 11.sp, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LiveElapsedTimer extends StatefulWidget {
  final String? idleStartedAt;
  final double fallbackMinutes;
  final bool isWarning;

  const LiveElapsedTimer({
    super.key,
    required this.idleStartedAt,
    required this.fallbackMinutes,
    required this.isWarning,
  });

  @override
  State<LiveElapsedTimer> createState() => _LiveElapsedTimerState();
}

class _LiveElapsedTimerState extends State<LiveElapsedTimer> {
  late DateTime _startedAt;
  late int _fallbackSeconds;
  late bool _useLive;
  Timer? _timer;
  late int _elapsedSeconds;

  @override
  void initState() {
    super.initState();
    _initTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateElapsed();
        });
      }
    });
  }

  void _initTime() {
    _fallbackSeconds = (widget.fallbackMinutes * 60).round();
    if (widget.idleStartedAt != null && widget.idleStartedAt!.isNotEmpty) {
      try {
        _startedAt = DateTime.parse(widget.idleStartedAt!).toLocal();
        _useLive = true;
      } catch (_) {
        _useLive = false;
      }
    } else {
      _useLive = false;
    }
    _updateElapsed();
  }

  void _updateElapsed() {
    if (_useLive) {
      _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      if (_elapsedSeconds < 0) _elapsedSeconds = 0;
    } else {
      _elapsedSeconds = _fallbackSeconds;
    }
  }

  @override
  void didUpdateWidget(covariant LiveElapsedTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.idleStartedAt != oldWidget.idleStartedAt ||
        widget.fallbackMinutes != oldWidget.fallbackMinutes) {
      _initTime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _elapsedSeconds ~/ 3600;
    final mins = (_elapsedSeconds % 3600) ~/ 60;
    final secs = _elapsedSeconds % 60;

    String pad(int n) => n.toString().padLeft(2, '0');
    final display = hours > 0
        ? '$hours:${pad(mins)}:${pad(secs)}'
        : '${pad(mins)}:${pad(secs)}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 11.sp,
          color: widget.isWarning ? Colors.red : Colors.grey[500],
        ),
        SizedBox(width: 3.w),
        Text(
          display,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w900,
            color: widget.isWarning ? Colors.red : Colors.grey[700],
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
