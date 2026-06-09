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
            Icon(Icons.error_outline, size: 48.sp, color: colorScheme.error.withOpacity(0.5)),
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

    final s = data.summary;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Header / Controls
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month, color: colorScheme.primary),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Dữ liệu chấm công',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Xử lý'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  data.sheetDate.isNotEmpty ? 'Ngày: ${data.sheetDate} (Đọc từ sheet)' : 'Chưa có dữ liệu ngày',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Summary stats
          Row(
            children: [
              Expanded(child: _buildStatCard('Tổng', s.total, Colors.grey[100]!, Colors.black87, Icons.groups)),
              SizedBox(width: 8.w),
              Expanded(child: _buildStatCard('Đi làm', s.working, Colors.green[50]!, Colors.green[700]!, Icons.how_to_reg)),
              SizedBox(width: 8.w),
              Expanded(child: _buildStatCard('Nghỉ', s.off, Colors.red[50]!, Colors.red[700]!, Icons.person_off)),
              SizedBox(width: 8.w),
              Expanded(child: _buildStatCard('Nửa ngày', s.half, Colors.orange[50]!, Colors.orange[700]!, Icons.wb_sunny)),
            ],
          ),
          SizedBox(height: 16.h),

          // Actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _exportExcel,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Xuất Excel'),
                ),
                SizedBox(width: 8.w),
                OutlinedButton.icon(
                  onPressed: _isSyncing ? null : _syncSheet,
                  icon: _isSyncing 
                    ? SizedBox(width: 16, height: 16, child: const CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync, size: 16),
                  label: const Text('Đồng bộ'),
                ),
                SizedBox(width: 8.w),
                OutlinedButton.icon(
                  onPressed: _openSheet,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Mở Sheet'),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Table / List
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12.r),
              color: colorScheme.surface,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.results.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = data.results[index];
                
                Color bgColor;
                Widget statusTag;
                if (r.isWorking) {
                  bgColor = Colors.green.withOpacity(0.05);
                  statusTag = _buildTag('1', Colors.green);
                } else if (r.isHalf) {
                  bgColor = Colors.orange.withOpacity(0.05);
                  statusTag = _buildTag('0.5', Colors.orange);
                } else {
                  bgColor = Colors.red.withOpacity(0.05);
                  statusTag = _buildTag('0', Colors.red);
                }

                return Container(
                  color: bgColor,
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    title: Text(r.hoTen, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${r.tenVT} • ${r.boPhan}', style: TextStyle(fontSize: 12.sp)),
                    trailing: statusTag,
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, num value, Color bgColor, Color textColor, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: textColor),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(fontSize: 12.sp, color: textColor.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }


  Widget _buildTag(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.sp),
      ),
    );
  }
}
