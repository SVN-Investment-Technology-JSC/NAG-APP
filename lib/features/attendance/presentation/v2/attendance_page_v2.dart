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
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/attendance/data/models/attendance_model.dart';
import 'package:nguyenanh/features/attendance/data/services/attendance_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Chấm công" (v2). Same constructor, state, Google-Sheets calls (load / sync / open), Excel export and
/// date handling as `AttendancePage`; only the widget tree is redesigned. The search box and status
/// filter are view-only (they never change what is loaded, exported or synced).
class AttendancePageV2 extends StatefulWidget {
  const AttendancePageV2({super.key});

  @override
  State<AttendancePageV2> createState() => _AttendancePageV2State();
}

class _AttendancePageV2State extends State<AttendancePageV2> {
  final AttendanceService _service = AttendanceService(ApiClient.dio);

  AttendanceResponse? _data;
  bool _isLoading = true;
  String? _error;
  bool _isSyncing = false;
  String? _sheetUrl;

  // v2 view-only state
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data & logic (verbatim from AttendancePage) ───────────────────────────

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
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
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
      final groupCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx));
      groupCell.value = TextCellValue('${group.key}. ${group.ten}');
      groupCell.cellStyle = groupStyle;
      for (var col = 1; col < 4; col++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx)).cellStyle = groupStyle;
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
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx)).value = values[col];
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
    // Same call as v1's `Share.shareXFiles(...)` (which only forwards to this), minus the deprecation.
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Cham cong $sheetName',
        sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
      ),
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

  // ── View helpers (v2, display only) ───────────────────────────────────────

  static const _foldGroups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  static final Map<String, String> _foldMap = {
    for (final g in _foldGroups.entries)
      for (final ch in g.value.split('')) ch: g.key,
  };

  /// Lower-case, accent-free text for search ("nguyen van an" finds "Nguyễn Văn An").
  static String _fold(String s) {
    final lower = s.toLowerCase().replaceAll(RegExp('[̀-ͯ]'), '');
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      b.write(_foldMap[ch] ?? ch);
    }
    return b.toString();
  }

  static String _fmt(num v) => v % 1 == 0 ? '${v.toInt()}' : '$v';

  bool _matchesStatus(AttendanceRecord r) => switch (_statusFilter) {
        'working' => r.isWorking,
        'half' => !r.isWorking && r.isHalf,
        'off' => !r.isWorking && !r.isHalf,
        _ => true,
      };

  // ── Layout (v2) ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final data = _data;
    final hasData = _data != null && _data!.results.isNotEmpty;

    final subtitle = data != null && data.sheetDate.isNotEmpty
        ? 'Ngày ${data.sheetDate} · đọc từ Google Sheet'
        : '${l10n.today} · ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.attendance, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h1.copyWith(fontSize: 19.sp)),
            SizedBox(height: 1.h),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, size: 22.sp, color: hasData ? t.text : t.textFaint),
            tooltip: 'Thao tác',
            position: PopupMenuPosition.under,
            enabled: hasData,
            onSelected: (value) {
              if (value == 'excel') _exportExcel();
              if (value == 'sync') _syncSheet();
              if (value == 'open') _openSheet();
            },
            itemBuilder: (context) => [
              _menuItem(t, 'excel', Icons.download_rounded, FxTokens.emerald, 'Xuất Excel'),
              _menuItem(t, 'sync', Icons.sync_rounded, FxTokens.blue, 'Đồng bộ Sheet', busy: _isSyncing),
              _menuItem(t, 'open', Icons.open_in_new_rounded, FxTokens.indigo, 'Mở Sheet'),
            ],
          ),
          SizedBox(width: 6.w),
        ],
      ),
      body: _buildBody(t, l10n),
    );
  }

  PopupMenuItem<String> _menuItem(FxTokens t, String value, IconData icon, Color tone, String label, {bool busy = false}) {
    return PopupMenuItem<String>(
      value: value,
      height: 46.h,
      child: Row(
        children: [
          busy
              ? SizedBox(
                  width: 28.w,
                  height: 28.w,
                  child: Padding(
                    padding: EdgeInsets.all(6.w),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : FxIconBadge(icon: icon, tone: tone, size: 28),
          SizedBox(width: 12.w),
          Text(label, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w600, color: t.text)),
        ],
      ),
    );
  }

  Widget _buildBody(FxTokens t, AppLocalizations l10n) {
    if (_isLoading) return const _AttendanceSkeleton();

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: FxEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Không tải được dữ liệu chấm công',
            message: 'Kiểm tra kết nối mạng rồi thử lại.',
            action: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: t.tiny.copyWith(color: t.textFaint),
                ),
                SizedBox(height: 12.h),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data;
    if (data == null || data.results.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: FxEmpty(
                  icon: Icons.event_busy_rounded,
                  title: l10n.noAttendanceData,
                  message: 'Kéo xuống hoặc nhấn Tải lại để đọc lại dữ liệu từ sheet.',
                  action: OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tải lại'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final s = data.summary;
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 760 ? (width - 720) / 2 : 14.w;
    final radius = Radius.circular(FxTokens.rCard);

    // View-only filtering of the same list v1 shows (order unchanged).
    final q = _fold(_query.trim());
    final visible = data.results.where((r) {
      if (!_matchesStatus(r)) return false;
      if (q.isEmpty) return true;
      return _fold(r.hoTen).contains(q) || _fold(r.tenVT).contains(q) || _fold(r.boPhan).contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, 6.h, side, 0),
            sliver: SliverList.list(
              children: [
                _hero(t, l10n, data),
                FxGrid(
                  columns: 4,
                  gap: 8.w,
                  children: [
                    _KpiTile(icon: Icons.groups_rounded, label: l10n.attendanceTotal, value: _fmt(s.total), tone: FxTokens.slate),
                    _KpiTile(icon: Icons.how_to_reg_rounded, label: l10n.attendanceWorking, value: _fmt(s.working), tone: FxTokens.emerald),
                    _KpiTile(icon: Icons.person_off_rounded, label: l10n.attendanceOff, value: _fmt(s.off), tone: FxTokens.red),
                    _KpiTile(icon: Icons.wb_sunny_rounded, label: l10n.attendanceHalf, value: _fmt(s.half), tone: FxTokens.amber),
                  ],
                ),
                FxGrid(
                  columns: 3,
                  gap: 8.w,
                  children: [
                    _ActionTile(
                      icon: Icons.download_rounded,
                      tone: FxTokens.emerald,
                      label: 'Xuất Excel',
                      onTap: _exportExcel,
                    ),
                    _ActionTile(
                      icon: Icons.sync_rounded,
                      tone: FxTokens.blue,
                      label: 'Đồng bộ',
                      busy: _isSyncing,
                      onTap: _isSyncing ? null : _syncSheet,
                    ),
                    _ActionTile(
                      icon: Icons.open_in_new_rounded,
                      tone: FxTokens.indigo,
                      label: 'Mở Sheet',
                      onTap: _openSheet,
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                FxSearchField(
                  controller: _searchController,
                  hint: 'Tìm theo họ tên, mã hoặc bộ phận',
                  onChanged: (v) => setState(() => _query = v),
                ),
                SizedBox(height: 10.h),
                FxSegmented<String>(
                  dense: true,
                  segments: [
                    const FxSegment('all', 'Tất cả'),
                    FxSegment('working', l10n.attendanceWorking),
                    FxSegment('half', l10n.attendanceHalf),
                    FxSegment('off', l10n.attendanceOff),
                  ],
                  value: _statusFilter,
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(4.w, 16.h, 4.w, 8.h),
                  child: Row(
                    children: [
                      Text(
                        'DANH SÁCH NHÂN SỰ · ${visible.length}',
                        style: t.overline.copyWith(fontFeatures: FxTokens.tabular),
                      ),
                      const Spacer(),
                      if (visible.length != data.results.length)
                        Text(
                          'trên ${data.results.length}',
                          style: t.tiny.copyWith(color: t.textFaint, fontFeatures: FxTokens.tabular),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (visible.isEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: SliverToBoxAdapter(
                child: FxCard(
                  padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 12.w),
                  child: const Center(
                    child: FxEmpty(
                      icon: Icons.search_off_rounded,
                      title: 'Không có nhân sự phù hợp',
                      message: 'Thử đổi bộ lọc hoặc từ khoá tìm kiếm.',
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.all(radius),
                  border: Border.all(color: t.border.withValues(alpha: 0.7)),
                  boxShadow: t.shadow,
                ),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, index) => Divider(height: 1, thickness: 1, indent: 64.w, color: t.divider),
                  itemBuilder: (context, index) {
                    final row = _AttendanceRow(record: visible[index], l10n: l10n);
                    final first = index == 0, last = index == visible.length - 1;
                    if (!first && !last) return row;
                    return ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: first ? radius : Radius.zero,
                        bottom: last ? radius : Radius.zero,
                      ),
                      child: row,
                    );
                  },
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 28.h)),
        ],
      ),
    );
  }

  /// Gradient summary: sheet date, people at work and the working / half-day / off split.
  Widget _hero(FxTokens t, AppLocalizations l10n, AttendanceResponse data) {
    final s = data.summary;
    final pct = s.total == 0 ? 0 : (s.working / s.total * 100).round();
    final c1 = t.dark ? Color.lerp(FxTokens.blue, t.bg, 0.35)! : FxTokens.blue;
    final c2 = t.dark ? Color.lerp(FxTokens.indigo, t.bg, 0.35)! : FxTokens.indigo;
    final onHero = Colors.white.withValues(alpha: 0.85);
    final workTone = Color.lerp(FxTokens.emerald, Colors.white, 0.45)!;
    final halfTone = Color.lerp(FxTokens.amber, Colors.white, 0.4)!;
    final offTone = Color.lerp(FxTokens.red, Colors.white, 0.45)!;

    Widget legend(Color c, String label, String value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            SizedBox(width: 5.w),
            Text(
              '$label $value',
              style: TextStyle(fontSize: 11.sp, color: onHero, fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular),
            ),
          ],
        );

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FxTokens.rCard),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c1, c2]),
        boxShadow: t.dark
            ? const []
            : [BoxShadow(color: FxTokens.blue.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 16.sp, color: onHero),
              SizedBox(width: 6.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dữ liệu chấm công',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.sp, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      data.sheetDate.isNotEmpty ? 'Ngày: ${data.sheetDate} (Đọc từ sheet)' : 'Chưa có dữ liệu ngày',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.sp, color: onHero, fontFeatures: FxTokens.tabular),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              FilledButton.icon(
                onPressed: _loadData,
                icon: Icon(Icons.refresh_rounded, size: 16.sp),
                label: const Text('Xử lý'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: c1,
                  minimumSize: Size(0, 36.h),
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12.5.sp, fontWeight: FontWeight.w800),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt(s.working), style: t.num(36.sp, color: Colors.white)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 4.w, bottom: 5.h),
                  child: Text(
                    '/ ${_fmt(s.total)} người đi làm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp, color: onHero, fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text('$pct%', style: t.num(15.sp, color: Colors.white)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          FxStackBar(
            height: 7,
            parts: [
              (value: s.working.toDouble(), color: workTone),
              (value: s.half.toDouble(), color: halfTone),
              (value: s.off.toDouble(), color: offTone),
            ],
          ),
          SizedBox(height: 9.h),
          Wrap(
            spacing: 14.w,
            runSpacing: 6.h,
            children: [
              legend(workTone, l10n.attendanceWorking, _fmt(s.working)),
              legend(halfTone, l10n.attendanceHalf, _fmt(s.half)),
              legend(offTone, l10n.attendanceOff, _fmt(s.off)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pieces ─────────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  const _KpiTile({required this.icon, required this.label, required this.value, required this.tone});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 8.w, 10.h),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        border: Border.all(color: t.border.withValues(alpha: 0.7)),
        boxShadow: t.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FxIconBadge(icon: icon, tone: tone, size: 26),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: t.num(19.sp, color: tone == FxTokens.slate ? t.text : t.ink(tone))),
          ),
          SizedBox(height: 2.h),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  const _ActionTile({required this.icon, required this.tone, required this.label, required this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return FxCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          busy
              ? SizedBox(
                  width: 26.w,
                  height: 26.w,
                  child: Padding(
                    padding: EdgeInsets.all(5.w),
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.ink(tone)),
                  ),
                )
              : FxIconBadge(icon: icon, tone: tone, size: 26),
          SizedBox(width: 7.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: onTap == null && !busy ? t.textFaint : t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final AttendanceRecord record;
  final AppLocalizations l10n;

  const _AttendanceRow({required this.record, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final r = record;

    // Same status mapping as v1's list tags ('1' / '0.5' / '0').
    final Color tone;
    final String label;
    final String value;
    if (r.isWorking) {
      tone = FxTokens.emerald;
      label = l10n.attendanceWorking;
      value = '1';
    } else if (r.isHalf) {
      tone = FxTokens.amber;
      label = l10n.attendanceHalf;
      value = '0.5';
    } else {
      tone = FxTokens.red;
      label = l10n.attendanceOff;
      value = '0';
    }

    final parts = r.hoTen.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1
                ? parts.first.characters.first
                : parts.first.characters.first + parts.last.characters.first)
            .toUpperCase();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.soft(tone), shape: BoxShape.circle),
            child: Text(
              initials,
              maxLines: 1,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: t.ink(tone)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.hoTen, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3.copyWith(fontSize: 14.sp)),
                SizedBox(height: 2.h),
                Text(
                  '${r.tenVT} • ${r.boPhan}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.small,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 120.w),
            child: FxPill(label: '$label · $value', tone: tone, dot: true),
          ),
        ],
      ),
    );
  }
}

class _AttendanceSkeleton extends StatelessWidget {
  const _AttendanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 760 ? (width - 720) / 2 : 14.w;

    Widget row(List<Widget> cells) => Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) SizedBox(width: 8.w),
              Expanded(child: cells[i]),
            ],
          ],
        );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(side, 6.h, side, 24.h),
      children: [
        FxSkeleton(height: 168.h, radius: 18),
        SizedBox(height: 12.h),
        row([for (var i = 0; i < 4; i++) FxSkeleton(height: 84.h, radius: 14)]),
        SizedBox(height: 10.h),
        row([for (var i = 0; i < 3; i++) FxSkeleton(height: 48.h, radius: 14)]),
        SizedBox(height: 14.h),
        FxSkeleton(height: 42.h),
        SizedBox(height: 10.h),
        FxSkeleton(height: 34.h),
        SizedBox(height: 18.h),
        Container(
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(FxTokens.rCard),
            border: Border.all(color: t.border.withValues(alpha: 0.7)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, indent: 64.w, color: t.divider),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  child: Row(
                    children: [
                      FxSkeleton(height: 38.w, width: 38.w, radius: 19),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FxSkeleton(height: 12.h, width: (i.isEven ? 150 : 120).w, radius: 6),
                            SizedBox(height: 6.h),
                            FxSkeleton(height: 9.h, width: 170.w, radius: 5),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      FxSkeleton(height: 20.h, width: 72.w, radius: 10),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
