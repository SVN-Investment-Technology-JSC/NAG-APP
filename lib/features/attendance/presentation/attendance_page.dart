import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vehicle_management/core/network/api_client.dart';
import 'package:vehicle_management/core/network/app_endpoints.dart';
import 'package:vehicle_management/features/attendance/data/models/attendance_model.dart';
import 'package:vehicle_management/features/attendance/data/services/attendance_service.dart';
import 'package:vehicle_management/features/shell/presentation/main_shell.dart';
import 'package:vehicle_management/l10n/app_localizations.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AttendanceService _service = AttendanceService(ApiClient.dio);

  AttendanceResponse? _data;
  final Set<String> _expandedGroups = {};
  bool _isLoading = true;
  String? _error;

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
    final data = _data;
    if (data == null || data.results.isEmpty) return;

    final excel = Excel.createExcel();
    final sheetName = DateFormat('dd-MM-yyyy').format(DateTime.now());
    final sheet = excel[sheetName];
    excel.delete('Sheet1');

    final headers = ['STT', 'Ho ten', 'Bo phan', 'Trang thai'];
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
          statusText = 'Di lam';
        } else if (r.isHalf) {
          statusText = 'Nua ngay';
        } else {
          statusText = 'Nghi';
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
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Cham cong $sheetName',
    );
  }

  Future<void> _openSheet() async {
    final uri = Uri.parse(AppEndpoints.attendanceSheetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        title: Text(
          l10n.attendance,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => mainShellScaffoldKey.currentState?.openDrawer(),
          icon: Icon(Icons.menu_rounded, color: colorScheme.primary),
          tooltip: 'Menu',
        ),
        actions: [
          IconButton(
            onPressed: (_data == null || _data!.results.isEmpty) ? null : _exportExcel,
            icon: Icon(
              Icons.table_chart_outlined,
              color: (_data == null || _data!.results.isEmpty)
                  ? colorScheme.outlineVariant
                  : colorScheme.primary,
            ),
            tooltip: 'Xuất Excel',
          ),
          IconButton(
            onPressed: _openSheet,
            icon: Icon(Icons.open_in_new_rounded, color: colorScheme.primary),
            tooltip: 'Mở Google Sheet',
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
              label: const Text('Thử lại'),
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
          SliverToBoxAdapter(child: _buildHeader(data, theme, colorScheme, l10n)),
          ...data.nhomNS.where((g) => g.nhanSu.isNotEmpty).expand((group) {
            final members = group.nhanSu
                .map((hoTen) => recordByHoTen[hoTen])
                .whereType<AttendanceRecord>()
                .toList();
            final working = members.where((r) => r.isWorking).length;
            final half = members.where((r) => r.isHalf).length;

            return [
              SliverToBoxAdapter(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      if (_expandedGroups.contains(group.key)) {
                        _expandedGroups.remove(group.key);
                      } else {
                        _expandedGroups.add(group.key);
                      }
                    });
                  },
                  child: _buildGroupHeader(
                    group: group,
                    total: members.length,
                    working: working,
                    half: half,
                    theme: theme,
                    colorScheme: colorScheme,
                    isExpanded: _expandedGroups.contains(group.key),
                  ),
                ),
              ),
              if (_expandedGroups.contains(group.key))
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildEmployeeItem(members[index], theme, colorScheme),
                    childCount: members.length,
                  ),
                ),
            ];
          }),
          SliverToBoxAdapter(child: SizedBox(height: 16.h)),
        ],
      ),
    );
  }

  Widget _buildHeader(AttendanceResponse data, ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    final s = data.summary;
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          _summaryChip(
            label: l10n.attendanceTotal,
            value: '${s.total}',
            color: colorScheme.primary,
            theme: theme,
            colorScheme: colorScheme,
          ),
          SizedBox(width: 8.w),
          _summaryChip(
            label: l10n.attendanceWorking,
            value: '${s.working}',
            color: Colors.green,
            theme: theme,
            colorScheme: colorScheme,
          ),
          SizedBox(width: 8.w),
          _summaryChip(
            label: l10n.attendanceOff,
            value: '${s.off}',
            color: colorScheme.error,
            theme: theme,
            colorScheme: colorScheme,
          ),
          SizedBox(width: 8.w),
          _summaryChip(
            label: l10n.attendanceHalf,
            value: '${s.half}',
            color: const Color(0xFFF59E0B),
            theme: theme,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip({
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9.sp,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
    required bool isExpanded,
  }) {
    final color = _groupColors[group.key] ?? colorScheme.primary;
    final icon = _groupIcons[group.key] ?? Icons.group_rounded;
    final off = total - working - half;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 16.sp, color: color),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${group.key}. ${group.ten}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '$working đi làm${half > 0 ? ' · $half nửa ngày' : ''}${off > 0 ? ' · $off nghỉ' : ''}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '$total',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Icon(
            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: color,
            size: 20.sp,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeItem(AttendanceRecord record, ThemeData theme, ColorScheme colorScheme) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (record.isWorking) {
      statusColor = Colors.green;
      statusLabel = 'Đi làm';
      statusIcon = Icons.check_circle_rounded;
    } else if (record.isHalf) {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Nửa ngày';
      statusIcon = Icons.timelapse_rounded;
    } else {
      statusColor = colorScheme.error;
      statusLabel = 'Nghỉ';
      statusIcon = Icons.cancel_rounded;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 3.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, size: 18.sp, color: statusColor),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.hoTen,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                if (record.boPhan.isNotEmpty)
                  Text(
                    record.boPhan,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 12.sp, color: statusColor),
                SizedBox(width: 4.w),
                Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
