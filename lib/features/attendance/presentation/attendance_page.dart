import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/attendance/data/models/attendance_model.dart';
import 'package:nguyenanh/features/attendance/data/services/attendance_service.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AttendanceService _service = AttendanceService(ApiClient.dio);

  AttendanceResponse? _data;
  bool _isLoading = true;
  String? _error;
  bool _isSyncing = false;
  String? _sheetUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.getAttendance(date: DateTime.now());
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportExcel() async {
    final l10n = AppLocalizations.of(context)!;
    final data = _data;
    if (data == null || data.results.isEmpty) return;

    final excel = Excel.createExcel();
    final sheetName = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final sheet = excel[sheetName];
    excel.delete('Sheet1');

    final headers = [l10n.stt, l10n.fullName, l10n.department, l10n.status];
    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    for (var col = 0; col < headers.length; col++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    final groupStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#D9E2F3'),
    );

    final recordMap = <String, AttendanceRecord>{};
    for (final r in data.results) {
      recordMap[r.tenVT] = r;
    }

    var rowIdx = 1;
    var stt = 1;
    for (final group in data.nhomNS) {
      if (group.nhanSu.isEmpty) continue;

      // Group header row
      final groupCell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx));
      groupCell.value = TextCellValue('${group.key}. ${group.ten}');
      groupCell.cellStyle = groupStyle;
      for (var col = 1; col < 4; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx))
            .cellStyle = groupStyle;
      }
      rowIdx++;

      for (final tenVT in group.nhanSu) {
        final r = recordMap[tenVT];
        if (r == null) continue;

        String statusText;
        if (r.isWorking) {
          statusText = l10n.attendanceWorking;
        } else if (r.isHalf) {
          statusText = l10n.attendanceHalf;
        } else {
          statusText = l10n.attendanceOff;
        }

        final values = [
          TextCellValue('$stt'),
          TextCellValue(r.hoTen),
          TextCellValue(r.boPhan),
          TextCellValue(statusText),
        ];
        for (var col = 0; col < values.length; col++) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                  columnIndex: col, rowIndex: rowIdx))
              .value = values[col];
        }
        rowIdx++;
        stt++;
      }
    }

    sheet.setColumnWidth(0, 6);
    sheet.setColumnWidth(1, 24);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 12);

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final dir = await getTemporaryDirectory();
    final fileName = 'cham_cong_$sheetName.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(fileBytes);

    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Cham cong $sheetName',
      sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
    );
  }

  Future<void> _syncSheet() async {
    if (_data == null || _data!.results.isEmpty) return;
    setState(() => _isSyncing = true);
    try {
      final payload = {
        'date': _data!.sheetDate,
        'results': _data!.results.map((e) => e.toJson()).toList(),
        'nhomNS': _data!.nhomNS.map((e) => e.toJson()).toList(),
      };

      final url = await _service.syncSheet(payload);
      if (mounted) {
        setState(() {
          _sheetUrl = url.isNotEmpty ? url : null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đồng bộ thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đồng bộ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _openSheet() async {
    final url = _sheetUrl ?? AppEndpoints.attendanceSheetUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          l10n.attendance,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.menu_rounded, color: colorScheme.primary),
            tooltip: 'Thao tác',
            enabled: _data != null && _data!.results.isNotEmpty,
            onSelected: (value) {
              if (value == 'excel') _exportExcel();
              if (value == 'sync') _syncSheet();
              if (value == 'open') _openSheet();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 20.sp, color: colorScheme.onSurface),
                    SizedBox(width: 12.w),
                    const Text('Xuất Excel'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    _isSyncing
                      ? SizedBox(width: 20.sp, height: 20.sp, child: const CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.sync_rounded, size: 20.sp, color: colorScheme.onSurface),
                    SizedBox(width: 12.w),
                    const Text('Đồng bộ Sheet'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 20.sp, color: colorScheme.onSurface),
                    SizedBox(width: 12.w),
                    const Text('Mở Sheet'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: _buildBody(theme, colorScheme, l10n),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: colorScheme.error.withValues(alpha: 0.5)),
            SizedBox(height: 12.h),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final data = _data;
    if (data == null || data.results.isEmpty) {
      return Center(
        child: Text(
          l10n.noAttendanceData,
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    // Build grouped sections from nhomNS (nhanSu now contains hoTen)
    final recordByHoTen = <String, AttendanceRecord>{};
    for (final r in data.results) {
      recordByHoTen[r.hoTen] = r;
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context, data, theme, colorScheme, l10n, data.results)),
          ...data.nhomNS.where((g) => g.nhanSu.isNotEmpty).map((group) {
            final members = group.nhanSu
                .map((hoTen) => recordByHoTen[hoTen])
                .whereType<AttendanceRecord>()
                .toList();
            final working = members.where((r) => r.isWorking).length;
            final half = members.where((r) => r.isHalf).length;

            return SliverToBoxAdapter(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showMembersBottomSheet(
                  context: context,
                  title: group.ten,
                  icon: _groupIcons[group.key] ?? Icons.group_rounded,
                  members: members,
                  initialFilter: l10n.all,
                  theme: theme,
                  colorScheme: colorScheme,
                ),
                child: _buildGroupHeader(
                  group: group,
                  total: members.length,
                  working: working,
                  half: half,
                  theme: theme,
                  colorScheme: colorScheme,
                ),
              ),
            );
          }),
          SliverToBoxAdapter(child: SizedBox(height: 16.h)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AttendanceResponse data, ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n, List<AttendanceRecord> allMembers) {
    final s = data.summary;
    final total = s.total;
    final working = s.working;
    final off = s.off;
    final half = s.half;

    final now = DateTime.now();
    final dateStr = '${l10n.today}, ${now.day.toString().padLeft(2, '0')} ${l10n.monthLabel} ${now.month}';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16.h),
          Text(
            dateStr,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.attendanceStats,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100.r),
                ),
                child: Row(
                  children: [
                    Container(width: 6.w, height: 6.w, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    SizedBox(width: 6.w),
                    Text(
                      l10n.updating,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w800,
                        fontSize: 9.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // 2x2 Grid
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 800.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _statCard1(
                          title: l10n.totalPersonnel,
                          value: '$total',
                          sub: l10n.allSystems,
                          icon: Icons.groups_rounded,
                          onTap: () => _showMembersBottomSheet(
                            context: context,
                            title: l10n.allPersonnel,
                            icon: Icons.groups_rounded,
                            members: allMembers,
                            initialFilter: 'Tất cả',
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                          theme: theme,
                          colorScheme: colorScheme,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _statCard2(
                          title: l10n.workingStatus,
                          value: '$working',
                          progress: total > 0 ? working / total : 0,
                          icon: Icons.how_to_reg_rounded,
                          onTap: () => _showMembersBottomSheet(
                            context: context,
                            title: l10n.personnelWorking,
                            icon: Icons.how_to_reg_rounded,
                            members: allMembers,
                            initialFilter: 'Đi làm',
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                          theme: theme,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard3(
                          title: l10n.offStatus,
                          value: '${off < 10 ? '0$off' : off}',
                          sub: '${total > 0 ? (off / total * 100).toStringAsFixed(1) : 0}% VẮNG MẶT',
                          icon: Icons.person_off_rounded,
                          color: colorScheme.error,
                          onTap: () => _showMembersBottomSheet(
                            context: context,
                            title: l10n.personnelOff,
                            icon: Icons.person_off_rounded,
                            members: allMembers,
                            initialFilter: 'Nghỉ',
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                          theme: theme,
                          colorScheme: colorScheme,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _statCard3(
                          title: l10n.halfDayStatus,
                          value: '${half < 10 ? '0$half' : half}',
                          sub: 'ĐÃ PHÊ DUYỆT',
                          icon: Icons.wb_sunny_rounded,
                          color: const Color(0xFF10B981),
                          onTap: () => _showMembersBottomSheet(
                            context: context,
                            title: l10n.personnelHalfDay,
                            icon: Icons.wb_sunny_rounded,
                            members: allMembers,
                            initialFilter: 'Nửa ngày',
                            theme: theme,
                            colorScheme: colorScheme,
                          ),
                          theme: theme,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.groupList,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showMembersBottomSheet(
                  context: context,
                  title: 'Tất cả nhân sự',
                  icon: Icons.groups_rounded,
                  members: allMembers,
                  initialFilter: 'Tất cả',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
                child: Text(
                  l10n.viewAll,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  Widget _statCard1({required String title, required String value, required String sub, required IconData icon, required VoidCallback onTap, required ThemeData theme, required ColorScheme colorScheme}) {
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16.sp, color: colorScheme.onSurfaceVariant),
                  SizedBox(width: 8.w),
                  Text(title, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              SizedBox(height: 12.h),
              Text(value, style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onSurface)),
              SizedBox(height: 4.h),
              Text(sub, style: theme.textTheme.labelSmall?.copyWith(fontSize: 8.sp, fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard2({required String title, required String value, required double progress, required IconData icon, required VoidCallback onTap, required ThemeData theme, required ColorScheme colorScheme}) {
    return Material(
      color: colorScheme.primary, // Blue background
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16.sp, color: colorScheme.onPrimary),
                  SizedBox(width: 8.w),
                  Text(title, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onPrimary)),
                ],
              ),
              SizedBox(height: 12.h),
              Text(value, style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: colorScheme.onPrimary)),
              SizedBox(height: 8.h),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                minHeight: 4.h,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard3({required String title, required String value, required String sub, required IconData icon, required Color color, required VoidCallback onTap, required ThemeData theme, required ColorScheme colorScheme}) {
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16.sp, color: colorScheme.onSurfaceVariant),
                  SizedBox(width: 8.w),
                  Text(title, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: colorScheme.onSurfaceVariant)),
                ],
              ),
              SizedBox(height: 12.h),
              Text(value, style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: color)),
              SizedBox(height: 4.h),
              Text(sub, style: theme.textTheme.labelSmall?.copyWith(fontSize: 8.sp, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  static const _groupColors = <String, Color>{
    'A': Color(0xFF6366F1), // indigo
    'B': Color(0xFF0EA5E9), // sky
    'C': Color(0xFF8B5CF6), // violet
    'D': Color(0xFFF97316), // orange
    'E': Color(0xFF14B8A6), // teal
    'F': Color(0xFFEC4899), // pink
  };

  static const _groupIcons = <String, IconData>{
    'A': Icons.admin_panel_settings_rounded,
    'B': Icons.precision_manufacturing_rounded,
    'C': Icons.science_rounded,
    'D': Icons.local_shipping_rounded,
    'E': Icons.plumbing_rounded,
    'F': Icons.fire_truck_rounded,
  };

  Widget _buildGroupHeader({
    required AttendanceGroup group,
    required int total,
    required int working,
    required int half,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final color = _groupColors[group.key] ?? colorScheme.primary;
    final icon = _groupIcons[group.key] ?? Icons.group_rounded;
    final performance = total > 0 ? (working / total * 100).round() : 0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800.w),
        child: Container(
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24.sp, color: color),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.ten,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          '$total Nhân viên',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.w),
                          child: Icon(Icons.circle, size: 4.sp, color: colorScheme.outlineVariant),
                        ),
                        Text(
                          '$working Đang làm',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$performance%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    l10n.performance,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.outlineVariant,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMembersBottomSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<AttendanceRecord> members,
    required String initialFilter,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        String selectedFilter = initialFilter;
        final filters = [l10n.all, l10n.attendanceWorking, l10n.attendanceHalf, l10n.attendanceOff];

        Color _getFilterColor(String filter) {
          switch (filter) {
            case 'Đi làm':
              return const Color(0xFF10B981);
            case 'Nửa ngày':
              return const Color(0xFFF59E0B);
            case 'Nghỉ':
              return const Color(0xFFEF4444);
            default:
              return colorScheme.primary;
          }
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final filteredMembers = members.where((m) {
              if (selectedFilter == 'Tất cả') return true;
              if (selectedFilter == 'Đi làm') return m.isWorking;
              if (selectedFilter == 'Nửa ngày') return m.isHalf;
              return !m.isWorking && !m.isHalf;
            }).toList();

            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 12.h),
                  Container(
                    width: 48.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.group_rounded, color: colorScheme.primary, size: 20.sp),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                l10n.personnelList,
                                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant),
                          style: IconButton.styleFrom(backgroundColor: colorScheme.surfaceContainerHighest),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: filters.map((filter) {
                        final isSelected = selectedFilter == filter;
                        final filterColor = _getFilterColor(filter);
                        
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: FilterChip(
                            label: Text(
                              filter,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() => selectedFilter = filter);
                            },
                            backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            selectedColor: filterColor,
                            checkmarkColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100.r),
                              side: BorderSide.none,
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: filteredMembers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_rounded, size: 48.sp, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                SizedBox(height: 12.h),
                                Text(
                                  'Không có nhân sự nào',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(bottom: 24.h),
                            itemCount: filteredMembers.length,
                            itemBuilder: (context, index) => _buildEmployeeItem(filteredMembers[index], theme, colorScheme),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmployeeItem(AttendanceRecord record, ThemeData theme, ColorScheme colorScheme) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (record.isWorking) {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Đi làm';
      statusIcon = Icons.check_circle_rounded;
    } else if (record.isHalf) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Nửa ngày';
      statusIcon = Icons.timelapse_rounded;
    } else {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Nghỉ';
      statusIcon = Icons.cancel_rounded;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600.w),
        child: Container(
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5.w,
                  color: statusColor,
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                record.hoTen,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (record.boPhan.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  record.boPhan,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14.sp, color: statusColor),
                              SizedBox(width: 4.w),
                              Text(
                                statusLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
