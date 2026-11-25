import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/meal/data/models/meal_model.dart';
import 'package:nguyenanh/features/meal/data/services/meal_service.dart';
import 'package:nguyenanh/features/meal/presentation/meal_check_page.dart' show PendingMealChange;
import 'package:nguyenanh/features/meal/presentation/v2/mx_widgets.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Cơm ca" screen (v2). Same constructor, state, API calls, export/share flows, dialogs and sheet as
/// `MealCheckPage`; only the widget tree is redesigned.
class MealCheckPageV2 extends StatefulWidget {
  const MealCheckPageV2({super.key});

  @override
  State<MealCheckPageV2> createState() => _MealCheckPageV2State();
}

class _MealCheckPageV2State extends State<MealCheckPageV2> {
  final MealService _mealService = MealService();

  int _activeTabIndex = 0; // 0 = Chấm theo ngày, 1 = Tổng quan
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedMonth = DateTime.now();

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;
  bool _checked = false;
  String? _error;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  bool _isSyncing = false;

  List<Personnel> _personnel = [];
  MealDataMap _mealData = {};
  MealDataMap _baselineMealData = {};
  final Map<String, PendingMealChange> _pendingChanges = {};
  bool _isSaving = false;

  List<UserAssignment> _roster = [];
  bool _showLocationSettings = false;
  double _latitude = 17.490144886448913;
  double _longitude = 106.55922219182935;
  double _radius = 150.0;

  // Filters
  String _nameFilter = '';
  int? _departmentFilter;
  int? _skillFilter;

  final Set<String> _selectedSlots = {'sang', 'trua', 'toi'};
  final Set<String> _expandedDepts = {};

  // Overview states
  bool _isOverviewLoading = false;
  Map<String, dynamic>? _overviewReport;

  // v2 (UI only): keeps the search text in sync with [_nameFilter] when the daily tab is rebuilt.
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoster();
    _loadReport();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data & logic (verbatim from MealCheckPage) ────────────────────────────

  Future<void> _loadRoster() async {
    try {
      final list = await _mealService.fetchUserAssignments();
      if (mounted) {
        setState(() {
          _roster = list;
        });
      }
    } catch (e) {
      debugPrint('[MEAL] Roster load error: $e');
    }
  }

  MealDataMap _cloneMealData(MealDataMap src) {
    final copy = <String, Map<String, DayMeals>>{};
    src.forEach((name, dateMap) {
      copy[name] = dateMap.map((date, dm) => MapEntry(date, dm.clone()));
    });
    return copy;
  }

  Future<bool> _confirmDiscard() async {
    if (_pendingChanges.isEmpty) return true;
    final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final t = FxTokens.of(ctx);
            return AlertDialog(
              backgroundColor: t.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
              titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
              contentPadding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
              actionsPadding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
              title: Row(
                children: [
                  FxIconBadge(icon: Icons.edit_note_rounded, tone: FxTokens.amber, size: 34),
                  SizedBox(width: 10.w),
                  Expanded(child: Text('Thay đổi chưa lưu', style: t.h2.copyWith(fontSize: 16.sp))),
                ],
              ),
              content: Text(
                'Bạn có thay đổi chưa lưu. Bạn có chắc chắn muốn bỏ qua các thay đổi này không?',
                style: t.body.copyWith(color: t.textMuted),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(foregroundColor: t.textMuted),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: FxTokens.red,
                    foregroundColor: Colors.white,
                    minimumSize: Size(96.w, 44.h),
                  ),
                  child: const Text('Bỏ qua'),
                ),
              ],
            );
          },
        ) ??
        false;
    return proceed;
  }

  ({List<Personnel> personnel, MealDataMap mealData}) _parseReport(Map<String, dynamic> report) {
    final byUser = report['by_user'] as List<dynamic>? ?? [];
    final listPersonnel = <Personnel>[];
    final mapMealData = <String, Map<String, DayMeals>>{};

    for (var u in byUser) {
      final name = u['user_full_name']?.toString() ?? 'Không tên';
      final dept = u['department_name']?.toString() ?? 'Khác';
      final userId = u['user_id'] is int
          ? u['user_id'] as int
          : (u['user_id'] != null ? int.tryParse(u['user_id'].toString()) : null);

      listPersonnel.add(Personnel(
        userId: userId,
        tenVT: '',
        hoTen: name,
        boPhan: dept,
      ));

      final userIdStr = userId?.toString() ?? name;
      mapMealData[userIdStr] = {};

      final cells = u['cells'] as List<dynamic>? ?? [];
      for (var c in cells) {
        final workDate = c['work_date']?.toString().substring(0, 10);
        final slot = c['meal_slot']?.toString();
        final source = c['source']?.toString();
        if (workDate != null && slot != null) {
          mapMealData[userIdStr]!.putIfAbsent(workDate, () => DayMeals());
          if (slot == 'sang') {
            mapMealData[userIdStr]![workDate]!.sang = true;
            mapMealData[userIdStr]![workDate]!.sangSource = source;
          }
          if (slot == 'trua') {
            mapMealData[userIdStr]![workDate]!.trua = true;
            mapMealData[userIdStr]![workDate]!.truaSource = source;
          }
          if (slot == 'toi') {
            mapMealData[userIdStr]![workDate]!.toi = true;
            mapMealData[userIdStr]![workDate]!.toiSource = source;
          }
        }
      }
    }
    return (personnel: listPersonnel, mealData: mapMealData);
  }

  Future<void> _loadReport({bool force = false}) async {
    if (!mounted) return;
    if (!force) {
      final proceed = await _confirmDiscard();
      if (!proceed) return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _mealData = {};
      _personnel = [];
      _baselineMealData = {};
      _pendingChanges.clear();
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final report = await _mealService.getReport(dateStr, dateStr);

      if (report == null) {
        throw Exception('Không lấy được dữ liệu báo cáo');
      }

      final parsed = _parseReport(report);

      if (!mounted) return;
      setState(() {
        _personnel = parsed.personnel;
        _mealData = parsed.mealData;
        _baselineMealData = _cloneMealData(parsed.mealData);
        _checked = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOverviewReport() async {
    if (!mounted) return;
    setState(() {
      _isOverviewLoading = true;
      _overviewReport = null;
    });
    try {
      final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final nextMonth = _selectedMonth.month == 12
          ? DateTime(_selectedMonth.year + 1, 1, 1)
          : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      final endOfMonth = nextMonth.subtract(const Duration(days: 1));

      final fromStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final toStr = DateFormat('yyyy-MM-dd').format(endOfMonth);

      final report = await _mealService.getReport(fromStr, toStr);
      if (mounted) {
        setState(() {
          _overviewReport = report;
        });
      }
    } catch (e) {
      debugPrint('[MEAL] Overview report load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isOverviewLoading = false;
        });
      }
    }
  }

  Future<void> _changeDate(DateTime newDate) async {
    final proceed = await _confirmDiscard();
    if (!proceed) return;
    setState(() {
      _selectedDate = newDate;
      _fromDate = newDate;
      _toDate = newDate;
    });
    _loadReport();
  }

  Future<void> _pickSingleDate() async {
    final proceed = await _confirmDiscard();
    if (!proceed) return;
    if (!mounted) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      _changeDate(picked);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 31)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _loadOverviewReport();
    }
  }

  // ──────────── Aggregation helpers ────────────

  DayMeals _aggregated(String userIdStr) {
    final perDay = _mealData[userIdStr];
    if (perDay == null || perDay.isEmpty) return DayMeals();
    final agg = DayMeals();
    for (final dm in perDay.values) {
      if (dm.sang) agg.sang = true;
      if (dm.trua) agg.trua = true;
      if (dm.toi) agg.toi = true;
    }
    return agg;
  }

  int _personTotal(int userId) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dm = _mealData[userId.toString()]?[dateKey];
    if (dm == null) return 0;
    int t = 0;
    if (_selectedSlots.contains('sang') && dm.sang) t++;
    if (_selectedSlots.contains('trua') && dm.trua) t++;
    if (_selectedSlots.contains('toi') && dm.toi) t++;
    return t;
  }

  int get _grandTotalDaily {
    int sum = 0;
    for (final person in _filteredRoster) {
      sum += _personTotal(person.userId);
    }
    return sum;
  }

  bool get _isSyncedDaily {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    for (final dateMap in _mealData.values) {
      final dm = dateMap[dateKey];
      if (dm != null) {
        if (dm.sang && dm.sangSource == 'auto') return true;
        if (dm.trua && dm.truaSource == 'auto') return true;
        if (dm.toi && dm.toiSource == 'auto') return true;
      }
    }
    return false;
  }

  List<({int id, String name})> get _departmentOptions {
    final opts = <int, String>{};
    for (final person in _roster) {
      if (person.departmentId != null && person.departmentName != null) {
        opts[person.departmentId!] = person.departmentName!;
      }
    }
    final sorted = opts.entries.map((e) => (id: e.key, name: e.value)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  List<({int id, String name})> get _skillOptions {
    final opts = <int, String>{};
    for (final person in _roster) {
      if (person.skillId != null && person.skillName != null) {
        opts[person.skillId!] = person.skillName!;
      }
    }
    final sorted = opts.entries.map((e) => (id: e.key, name: e.value)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return sorted;
  }

  String _normalizeSearchText(String text) {
    return text.toLowerCase();
  }

  List<UserAssignment> get _filteredRoster {
    final nameNorm = _normalizeSearchText(_nameFilter);
    return _roster.where((person) {
      if (nameNorm.isNotEmpty) {
        final haystack = _normalizeSearchText([
          person.userFullName,
          person.userShortName ?? '',
          person.departmentName ?? '',
          person.skillName ?? '',
        ].join(' '));
        if (!haystack.contains(nameNorm)) return false;
      }
      if (_departmentFilter != null && person.departmentId != _departmentFilter) return false;
      if (_skillFilter != null && person.skillId != _skillFilter) return false;
      return true;
    }).toList();
  }

  static const _preferredDepartmentOrder = ['QLSX', 'VHT', 'QA/QC', 'Tổ bơm', 'Bơm tĩnh', 'Xe bồn'];

  List<({String departmentName, List<UserAssignment> members})> get _groupedRoster {
    final groups = <String, List<UserAssignment>>{};
    for (final p in _filteredRoster) {
      final dept = p.departmentName ?? 'Không có bộ phận';
      groups.putIfAbsent(dept, () => []).add(p);
    }

    final sortedEntries = groups.entries.toList()
      ..sort((a, b) {
        final aIdx = _preferredDepartmentOrder.indexOf(a.key);
        final bIdx = _preferredDepartmentOrder.indexOf(b.key);
        if (aIdx != -1 || bIdx != -1) {
          return (aIdx == -1 ? 999 : aIdx).compareTo(bIdx == -1 ? 999 : bIdx);
        }
        return a.key.compareTo(b.key);
      });

    return sortedEntries.map((e) => (departmentName: e.key, members: e.value)).toList();
  }

  List<({String departmentName, List<Personnel> members})> get _groupedPersonnel {
    final groups = <String, List<Personnel>>{};
    for (final p in _personnel) {
      final dept = p.boPhan.isNotEmpty ? p.boPhan : 'Không có bộ phận';
      groups.putIfAbsent(dept, () => []).add(p);
    }

    final sortedEntries = groups.entries.toList()
      ..sort((a, b) {
        final aIdx = _preferredDepartmentOrder.indexOf(a.key);
        final bIdx = _preferredDepartmentOrder.indexOf(b.key);
        if (aIdx != -1 || bIdx != -1) {
          return (aIdx == -1 ? 999 : aIdx).compareTo(bIdx == -1 ? 999 : bIdx);
        }
        return a.key.compareTo(b.key);
      });

    return sortedEntries.map((e) => (departmentName: e.key, members: e.value)).toList();
  }

  List<Map<String, dynamic>> _buildFlatRows() {
    final activeSlots = mealSlots.where((s) => _selectedSlots.contains(s.key)).toList();
    final days = <DateTime>[];
    var d = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final end = DateTime(_toDate.year, _toDate.month, _toDate.day);
    while (!d.isAfter(end)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }

    final groups = _groupedPersonnel;
    final flatRows = <Map<String, dynamic>>[];
    int stt = 1;

    for (final g in groups) {
      if (g.members.isEmpty) continue;

      flatRows.add({
        'stt': '',
        'hoTen': g.departmentName,
        'licensePlate': '',
        'meals': {},
        'total': 0,
        'isSection': true,
        'sectionName': g.departmentName,
      });

      for (final member in g.members) {
        int personTotal = 0;
        final personMeals = <String, dynamic>{};

        for (final day in days) {
          final dateKey = DateFormat('yyyy-MM-dd').format(day);
          final dateStr = DateFormat('dd').format(day);
          final userIdStr = member.userId?.toString() ?? member.hoTen;
          final dm = _mealData[userIdStr]?[dateKey];

          final slotMap = <String, bool>{};
          for (final s in activeSlots) {
            slotMap[s.key] = false;
          }

          if (dm != null) {
            if (activeSlots.any((s) => s.key == 'sang') && dm.sang) {
              slotMap['sang'] = true;
              personTotal++;
            }
            if (activeSlots.any((s) => s.key == 'trua') && dm.trua) {
              slotMap['trua'] = true;
              personTotal++;
            }
            if (activeSlots.any((s) => s.key == 'toi') && dm.toi) {
              slotMap['toi'] = true;
              personTotal++;
            }
          }
          personMeals[dateStr] = slotMap;
        }

        flatRows.add({
          'stt': stt++,
          'hoTen': member.hoTen,
          'licensePlate': '',
          'meals': personMeals,
          'total': personTotal,
          'isSection': false,
        });
      }
    }

    return flatRows;
  }

  Future<void> _shareImage() async {
    if (!_checked || _personnel.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      final activeSlots = mealSlots.where((s) => _selectedSlots.contains(s.key)).toList();
      final days = <DateTime>[];
      var d = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
      final end = DateTime(_toDate.year, _toDate.month, _toDate.day);
      while (!d.isAfter(end)) {
        days.add(d);
        d = d.add(const Duration(days: 1));
      }

      final groups = _groupedPersonnel;
      int totalPersonnel = 0;
      for (final g in groups) {
        totalPersonnel += g.members.length;
      }

      const double colSTT = 50;
      const double colName = 180;
      const double colSlot = 32;
      const double colTotal = 50;
      const double rowH = 28;
      const double headerH = 44;
      const double titleH = 48;
      const double dateH = 32;
      const double sectionH = 30;
      const double totalRowH = 32;

      final dayWidth = colSlot * activeSlots.length;
      final tableWidth = colSTT + colName + (dayWidth * days.length) + colTotal;

      int dataRows = totalPersonnel;
      int sectionRows = groups.length;
      final tableHeight =
          titleH + dateH + headerH + rowH + rowH + (sectionRows * sectionH) + (dataRows * rowH) + totalRowH;

      final scale = 3.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, tableWidth * scale, tableHeight * scale));
      canvas.scale(scale);

      final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(0, 0, tableWidth, tableHeight), bgPaint);

      final borderPaint = Paint()
        ..color = const Color(0xFF999999)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      final boldBorderPaint = Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      void drawText(Canvas c, String text, double x, double y, double w, double h,
          {double fontSize = 11,
          bool bold = false,
          Color color = const Color(0xFF333333),
          TextAlign align = TextAlign.center}) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
          textAlign: align,
          maxLines: 2,
          ellipsis: '...',
        );
        tp.layout(maxWidth: w - 4);
        final dx = align == TextAlign.left
            ? x + 4
            : align == TextAlign.right
                ? x + w - tp.width - 4
                : x + (w - tp.width) / 2;
        final dy = y + (h - tp.height) / 2;
        tp.paint(c, Offset(dx, dy));
      }

      double y = 0;

      final titleBg = Paint()..color = const Color(0xFF2563EB);
      canvas.drawRect(Rect.fromLTWH(0, y, tableWidth, titleH), titleBg);
      drawText(canvas, l10n.mealTableTitle, 0, y, tableWidth, titleH,
          fontSize: 18, bold: true, color: const Color(0xFFFFFFFF));
      y += titleH;

      final dateBg = Paint()..color = const Color(0xFFEFF6FF);
      canvas.drawRect(Rect.fromLTWH(0, y, tableWidth, dateH), dateBg);
      final dateStr =
          '${l10n.mealFromDate} ${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${l10n.mealToDate} ${DateFormat('dd/MM/yyyy').format(_toDate)}';
      drawText(canvas, dateStr, 0, y, tableWidth, dateH, fontSize: 13, bold: true, color: const Color(0xFF1E40AF));
      y += dateH;

      final hdrBg = Paint()..color = const Color(0xFFF1F5F9);
      canvas.drawRect(Rect.fromLTWH(0, y, tableWidth, headerH), hdrBg);
      canvas.drawRect(Rect.fromLTWH(0, y, colSTT, headerH), boldBorderPaint);
      drawText(canvas, l10n.mealSTT, 0, y, colSTT, headerH, fontSize: 11, bold: true);
      canvas.drawRect(Rect.fromLTWH(colSTT, y, colName, headerH), boldBorderPaint);
      drawText(canvas, l10n.mealFullName, colSTT, y, colName, headerH, fontSize: 11, bold: true);

      double dx = colSTT + colName;
      for (final day in days) {
        canvas.drawRect(Rect.fromLTWH(dx, y, dayWidth, headerH), boldBorderPaint);
        drawText(canvas, '${day.day}', dx, y, dayWidth, headerH, fontSize: 11, bold: true);
        dx += dayWidth;
      }
      canvas.drawRect(Rect.fromLTWH(dx, y, colTotal, headerH), boldBorderPaint);
      drawText(canvas, l10n.mealTotal, dx, y, colTotal, headerH, fontSize: 11, bold: true);
      y += headerH;

      canvas.drawRect(Rect.fromLTWH(0, y, colSTT, rowH), borderPaint);
      canvas.drawRect(Rect.fromLTWH(colSTT, y, colName, rowH), borderPaint);
      dx = colSTT + colName;
      for (var i = 0; i < days.length; i++) {
        for (final slot in activeSlots) {
          canvas.drawRect(Rect.fromLTWH(dx, y, colSlot, rowH), borderPaint);
          drawText(canvas, slot.label[0], dx, y, colSlot, rowH, fontSize: 9, bold: false);
          dx += colSlot;
        }
      }
      canvas.drawRect(Rect.fromLTWH(dx, y, colTotal, rowH), borderPaint);
      y += rowH;

      int stt = 1;
      int grandTotal = 0;

      final sectionBg = Paint()..color = const Color(0xFFFFFBEB);

      for (final g in groups) {
        canvas.drawRect(Rect.fromLTWH(0, y, tableWidth, sectionH), sectionBg);
        canvas.drawRect(Rect.fromLTWH(0, y, colSTT, sectionH), borderPaint);
        drawText(canvas, '', 0, y, colSTT, sectionH, fontSize: 11, bold: true, color: const Color(0xFFB45309));
        canvas.drawRect(Rect.fromLTWH(colSTT, y, tableWidth - colSTT, sectionH), borderPaint);
        drawText(canvas, g.departmentName, colSTT, y, colName, sectionH,
            fontSize: 11, bold: true, color: const Color(0xFFB45309), align: TextAlign.left);
        y += sectionH;

        for (final member in g.members) {
          canvas.drawRect(Rect.fromLTWH(0, y, colSTT, rowH), borderPaint);
          drawText(canvas, '$stt', 0, y, colSTT, rowH, fontSize: 10);
          canvas.drawRect(Rect.fromLTWH(colSTT, y, colName, rowH), borderPaint);
          drawText(canvas, member.hoTen, colSTT, y, colName, rowH, fontSize: 10, align: TextAlign.left);

          int personTotal = 0;
          dx = colSTT + colName;

          for (final day in days) {
            final dateKey = DateFormat('yyyy-MM-dd').format(day);
            final userIdStr = member.userId?.toString() ?? member.hoTen;
            final dm = _mealData[userIdStr]?[dateKey];

            for (final slot in activeSlots) {
              canvas.drawRect(Rect.fromLTWH(dx, y, colSlot, rowH), borderPaint);
              bool has = false;
              if (dm != null) {
                if (slot.key == 'sang') has = dm.sang;
                if (slot.key == 'trua') has = dm.trua;
                if (slot.key == 'toi') has = dm.toi;
              }
              if (has) {
                personTotal++;
                final checkPaint = Paint()..color = const Color(0xFF10B981);
                final cx = dx + colSlot / 2;
                final cy = y + rowH / 2;
                canvas.drawCircle(Offset(cx, cy), 5, checkPaint);
                drawText(canvas, '/', dx, y, colSlot, rowH, fontSize: 12, bold: true, color: const Color(0xFFFFFFFF));
              }
              dx += colSlot;
            }
          }

          grandTotal += personTotal;
          canvas.drawRect(Rect.fromLTWH(dx, y, colTotal, rowH), borderPaint);
          drawText(canvas, '$personTotal', dx, y, colTotal, rowH,
              fontSize: 11, bold: true, color: const Color(0xFF059669));

          stt++;
          y += rowH;
        }
      }

      final totalBg = Paint()..color = const Color(0xFFECFDF5);
      canvas.drawRect(Rect.fromLTWH(0, y, tableWidth, totalRowH), totalBg);
      canvas.drawRect(Rect.fromLTWH(0, y, tableWidth, totalRowH), boldBorderPaint);
      drawText(canvas, '${l10n.mealGrandTotal}: $grandTotal ${l10n.mealUnit}', 0, y, tableWidth, totalRowH,
          fontSize: 14, bold: true, color: const Color(0xFF065F46));
      y += totalRowH;

      final picture = recorder.endRecording();
      final image = await picture.toImage((tableWidth * scale).toInt(), (y * scale).toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final fileName =
          'com_ca_${DateFormat('dd-MM-yyyy').format(_fromDate)}_${DateFormat('dd-MM-yyyy').format(_toDate)}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      // Same call as v1's Share.shareXFiles (which forwards to SharePlus.instance.share).
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Com Ca ${DateFormat('dd/MM').format(_fromDate)} - ${DateFormat('dd/MM').format(_toDate)}',
          sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
        ),
      );
    } catch (e) {
      debugPrint('Share image error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.mealShareError)),
        );
      }
    }
  }

  Future<void> _exportExcel() async {
    if (!_checked || _personnel.isEmpty) return;

    try {
      var excel = Excel.createExcel();
      var sheet = excel['Cơm ca'];
      excel.delete('Sheet1');
      excel.setDefaultSheet('Cơm ca');

      final activeSlots = mealSlots.where((s) => _selectedSlots.contains(s.key)).toList();
      final days = <DateTime>[];
      var d = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
      final end = DateTime(_toDate.year, _toDate.month, _toDate.day);
      while (!d.isAfter(end)) {
        days.add(d);
        d = d.add(const Duration(days: 1));
      }

      List<CellValue> header = [TextCellValue('STT'), TextCellValue('Họ và tên')];
      for (final day in days) {
        for (final slot in activeSlots) {
          header.add(TextCellValue('${day.day} - ${slot.label[0]}'));
        }
      }
      header.add(TextCellValue('Tổng'));
      sheet.appendRow(header);

      final flatRows = _buildFlatRows();

      for (final row in flatRows) {
        if (row['isSection'] == true) {
          sheet.appendRow([TextCellValue(row['stt'].toString()), TextCellValue(row['hoTen'].toString())]);
        } else {
          List<CellValue> r = [TextCellValue(row['stt'].toString()), TextCellValue(row['hoTen'].toString())];

          for (final day in days) {
            final dateStr = DateFormat('dd').format(day);
            final meals = row['meals'][dateStr] as Map<String, dynamic>?;
            for (final slot in activeSlots) {
              if (meals != null && meals[slot.key] == true) {
                r.add(TextCellValue('/'));
              } else {
                r.add(TextCellValue(''));
              }
            }
          }
          r.add(IntCellValue(row['total'] as int));
          sheet.appendRow(r);
        }
      }

      List<CellValue> totalRow = [TextCellValue('Tổng cộng'), TextCellValue('')];
      for (int i = 0; i < days.length * activeSlots.length; i++) {
        totalRow.add(TextCellValue(''));
      }
      totalRow.add(IntCellValue(_totalMeals));
      sheet.appendRow(totalRow);

      final bytes = excel.encode();
      if (bytes == null) return;

      final dir = await getTemporaryDirectory();
      final fileName =
          'com_ca_${DateFormat('dd-MM-yyyy').format(_fromDate)}_${DateFormat('dd-MM-yyyy').format(_toDate)}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      // Same call as v1's Share.shareXFiles (which forwards to SharePlus.instance.share).
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Bảng Cơm Ca ${DateFormat('dd/MM').format(_fromDate)} - ${DateFormat('dd/MM').format(_toDate)}',
          sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
        ),
      );
    } catch (e) {
      debugPrint('[MEAL] Excel export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất Excel: $e')),
        );
      }
    }
  }

  int get _totalMeals {
    int total = 0;
    for (final name in _mealData.keys) {
      final perDay = _mealData[name];
      if (perDay == null) continue;
      for (final dm in perDay.values) {
        total += dm.total;
      }
    }
    return total;
  }

  Future<void> _exportMonthlyExcel() async {
    if (_overviewReport == null) return;

    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final nextMonth = _selectedMonth.month == 12
        ? DateTime(_selectedMonth.year + 1, 1, 1)
        : DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    final end = nextMonth.subtract(const Duration(days: 1));

    final oldFrom = _fromDate;
    final oldTo = _toDate;
    final oldMealData = _mealData;
    final oldPersonnel = _personnel;

    final parsed = _parseReport(_overviewReport!);

    setState(() {
      _fromDate = start;
      _toDate = end;
      _mealData = parsed.mealData;
      _personnel = parsed.personnel;
    });

    await _exportExcel();

    // v2 fix: v1 called setState here without a mounted check (throws if the page was closed meanwhile).
    if (!mounted) return;
    setState(() {
      _fromDate = oldFrom;
      _toDate = oldTo;
      _mealData = oldMealData;
      _personnel = oldPersonnel;
    });
  }

  void _toggleCell(UserAssignment person, String slot) {
    if (_fromDate != _toDate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ hỗ trợ chỉnh sửa khi chọn 1 ngày duy nhất')),
      );
      return;
    }
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final nameKey = person.userId.toString();
    final userId = person.userId;

    setState(() {
      _mealData.putIfAbsent(nameKey, () => {});
      _mealData[nameKey]!.putIfAbsent(dateKey, () => DayMeals());
      final dm = _mealData[nameKey]![dateKey]!;

      bool nextVal = false;
      if (slot == 'sang') {
        dm.sang = !dm.sang;
        dm.sangSource = 'manual';
        nextVal = dm.sang;
      } else if (slot == 'trua') {
        dm.trua = !dm.trua;
        dm.truaSource = 'manual';
        nextVal = dm.trua;
      } else if (slot == 'toi') {
        dm.toi = !dm.toi;
        dm.toiSource = 'manual';
        nextVal = dm.toi;
      }

      final changeKey = '${userId}_${dateKey}_$slot';

      final baseDm = _baselineMealData[nameKey]?[dateKey];
      bool baseVal = false;
      if (baseDm != null) {
        if (slot == 'sang') baseVal = baseDm.sang;
        if (slot == 'trua') baseVal = baseDm.trua;
        if (slot == 'toi') baseVal = baseDm.toi;
      }

      if (nextVal == baseVal) {
        _pendingChanges.remove(changeKey);
        if (slot == 'sang') dm.sangSource = baseDm?.sangSource;
        if (slot == 'trua') dm.truaSource = baseDm?.truaSource;
        if (slot == 'toi') dm.toiSource = baseDm?.toiSource;
      } else {
        _pendingChanges[changeKey] = PendingMealChange(
          userId: userId,
          date: dateKey,
          slot: slot,
          isAllowance: nextVal,
        );
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_pendingChanges.isEmpty) return;
    setState(() {
      _isSaving = true;
    });

    int failedCount = 0;
    final entries = _pendingChanges.values.toList();

    try {
      for (final entry in entries) {
        final result = await _mealService.upsertUserMealStatus(
          userId: entry.userId,
          workDate: entry.date,
          mealSlot: entry.slot,
          isAllowance: entry.isAllowance,
        );
        if (result == null) {
          failedCount++;
        }
      }

      if (!mounted) return;
      if (failedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu thành công ${entries.length} thay đổi')),
        );
        await _loadReport(force: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Có $failedCount thay đổi lưu thất bại. Vui lòng thử lại.')),
        );
        await _loadReport(force: true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu thay đổi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _syncGPS() async {
    final proceed = await _confirmDiscard();
    if (!proceed) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() => _isSyncing = true);
    try {
      final configOk = await _mealService.checkConfigOk(dateStr);

      if (!mounted) return;

      bool shouldProceed = false;
      if (configOk['hasPump'] == false || configOk['hasMixer'] == false || configOk['hasTask'] == false) {
        shouldProceed = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                final t = FxTokens.of(ctx);
                return AlertDialog(
                  backgroundColor: t.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
                  titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                  contentPadding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
                  actionsPadding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                  title: Row(
                    children: [
                      FxIconBadge(icon: Icons.warning_amber_rounded, tone: FxTokens.red, size: 34),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Cảnh báo thiếu phân công',
                          style: t.h2.copyWith(fontSize: 16.sp, color: t.ink(FxTokens.red)),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'Ngày $dateStr chưa có đầy đủ phân công Xe Bơm, Xe Bồn hoặc Công Việc.\n\nNếu quét GPS, hệ thống có thể không chấm đúng người.\nBạn có chắc chắn muốn quét GPS không?',
                    style: t.body.copyWith(color: t.textMuted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(foregroundColor: t.textMuted),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: FxTokens.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(96.w, 44.h),
                      ),
                      child: const Text('Vẫn quét'),
                    ),
                  ],
                );
              },
            ) ??
            false;
      } else {
        shouldProceed = true;
      }

      if (!shouldProceed) {
        // v2 fix: mounted check (the dialog is awaited above).
        if (mounted) setState(() => _isSyncing = false);
        return;
      }

      final activeSlots = mealSlots.where((s) => _selectedSlots.contains(s.key)).map((s) => s.key).toList();
      final runId = await _mealService.createRun({
        'from': dateStr,
        'to': dateStr,
        'meal_slots': activeSlots.join(','),
        'location': {
          'lat': _latitude,
          'lng': _longitude,
          'radius': _radius,
        }
      });

      if (runId == null) throw Exception('Không tạo được tiến trình quét');

      while (mounted && _isSyncing) {
        await Future.delayed(const Duration(seconds: 2));
        final run = await _mealService.getRun(runId);
        if (run != null) {
          final status = run['status']?.toString();
          final done = run['progress_done'] ?? 0;
          final total = run['progress_total'] ?? 0;

          if (mounted) {
            setState(() {
              _progressCurrent = done is int ? done : int.tryParse(done.toString()) ?? 0;
              _progressTotal = total is int ? total : int.tryParse(total.toString()) ?? 0;
              _isLoading = true;
            });
          }

          if (status == 'done') {
            break;
          } else if (status == 'failed') {
            throw Exception(run['error_message'] ?? 'Lỗi quét GPS');
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quét GPS thành công')));
        _loadReport();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _isLoading = false;
        });
      }
    }
  }

  // ── UI helpers (presentation only) ────────────────────────────────────────

  static const _weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

  String _weekdayOf(DateTime d) => _weekdays[d.weekday - 1];

  IconData _slotIcon(String key) => key == 'sang'
      ? Icons.light_mode_rounded
      : key == 'trua'
          ? Icons.wb_twilight_rounded
          : Icons.dark_mode_rounded;

  // ──────────── Build ────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final busy = _isSaving || _isLoading;
    final showSaveBar = _activeTabIndex == 0 && _pendingChanges.isNotEmpty;

    final subtitle = _activeTabIndex == 0
        ? 'Chấm theo ngày · ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'
        : 'Tổng quan · Tháng ${DateFormat('MM/yyyy').format(_selectedMonth)}';

    return PopScope(
      canPop: _pendingChanges.isEmpty && !_isSaving && !_isLoading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isSaving || _isLoading) return;
        final proceed = await _confirmDiscard();
        if (proceed && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(
            backgroundColor: t.bg,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 4.w,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.mealCheck, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h1.copyWith(fontSize: 19.sp)),
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
              _buildActionsMenu(t),
              SizedBox(width: 10.w),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(52.h),
              child: Padding(
                padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 8.h),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: busy ? 0.55 : 1,
                  child: FxSegmented<int>(
                    segments: const [
                      FxSegment(0, 'Chấm theo ngày', icon: Icons.fact_check_rounded),
                      FxSegment(1, 'Tổng quan', icon: Icons.calendar_month_rounded),
                    ],
                    value: _activeTabIndex,
                    onChanged: (i) {
                      if (_isSaving || _isLoading) return;
                      if (i == 0) {
                        setState(() {
                          _activeTabIndex = 0;
                          _fromDate = _selectedDate;
                          _toDate = _selectedDate;
                        });
                      } else {
                        setState(() {
                          _activeTabIndex = 1;
                        });
                        if (_overviewReport == null) {
                          _loadOverviewReport();
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          body: _activeTabIndex == 0 ? _buildDailyTab(t, l10n) : _buildOverviewTab(t, l10n),
          bottomNavigationBar: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: showSaveBar ? _buildSaveBar(t) : const SizedBox(width: double.infinity),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsMenu(FxTokens t) {
    PopupMenuItem<String> item(String value, IconData icon, Color tone, String title, String sub) {
      return PopupMenuItem<String>(
        value: value,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        child: Row(
          children: [
            FxIconBadge(icon: icon, tone: tone, size: 32),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3),
                  SizedBox(height: 1.h),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final dayLabel = DateFormat('dd/MM/yyyy').format(_fromDate);
    return PopupMenuButton<String>(
      tooltip: 'Thao tác',
      position: PopupMenuPosition.under,
      constraints: BoxConstraints(minWidth: 240.w, maxWidth: 280.w),
      onSelected: (value) {
        if (value == 'excel') _exportExcel();
        if (value == 'image') _shareImage();
        if (value == 'sync') _syncGPS();
      },
      itemBuilder: (context) => [
        item('excel', Icons.table_chart_rounded, FxTokens.emerald, 'Xuất Excel', 'Bảng cơm ca ngày $dayLabel'),
        item('image', Icons.image_rounded, FxTokens.blue, 'Xuất Ảnh', 'Chia sẻ bảng dạng ảnh PNG'),
        item('sync', Icons.satellite_alt_rounded, FxTokens.violet, 'Quét GPS', 'Tự động chấm theo định vị'),
      ],
      child: Container(
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: t.border),
        ),
        child: Icon(Icons.more_horiz_rounded, size: 20.sp, color: t.text),
      ),
    );
  }

  Widget _buildSaveBar(FxTokens t) {
    final hasPending = _pendingChanges.isNotEmpty;
    final pendingCount = _pendingChanges.length;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.border)),
        boxShadow: t.dark
            ? const []
            : const [BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 10.h),
          child: Row(
            children: [
              FxIconBadge(icon: Icons.edit_note_rounded, tone: FxTokens.amber, size: 38),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chưa lưu ($pendingCount)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.h3.copyWith(color: t.ink(FxTokens.amber), fontFeatures: FxTokens.tabular),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      '$pendingCount thay đổi suất ăn đang chờ lưu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              FilledButton.icon(
                onPressed: !hasPending || _isSaving || _isLoading ? null : _saveChanges,
                icon: _isSaving
                    ? SizedBox(
                        width: 14.sp,
                        height: 14.sp,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Lưu'),
                style: FilledButton.styleFrom(
                  backgroundColor: FxTokens.amber,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: FxTokens.amber.withValues(alpha: 0.45),
                  disabledForegroundColor: Colors.white,
                  minimumSize: Size(104.w, 46.h),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Daily tab ─────────────────────────────────────────────────────────────

  Widget _buildDailyTab(FxTokens t, AppLocalizations l10n) {
    final hasActiveFilter = _nameFilter.isNotEmpty || _departmentFilter != null || _skillFilter != null;
    final filtered = _filteredRoster;

    // Presentation states derived from the v1 flags.
    final showError = !_checked && _error != null && !_isLoading;
    final reloading = _checked && _isLoading && !_isSyncing;
    final showSkeleton = (!_checked && !showError) || reloading;

    final groups = _checked && _roster.isNotEmpty && !showSkeleton ? _groupedRoster : const <({String departmentName, List<UserAssignment> members})>[];

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateNavigator(t, l10n),
            if (showSkeleton)
              Padding(padding: EdgeInsets.only(bottom: 12.h), child: FxSkeleton(height: 178.h, radius: 18))
            else if (!showError)
              _buildDailySummary(t, filtered),
            _buildToolsCard(t),
            if (_isSyncing) _buildSyncProgress(t),
            _buildFiltersRow(t),
            if (_checked && _error != null && !_isLoading) _buildErrorBanner(t),
          ],
        ),
      ),
    ];

    if (showError) {
      slivers.add(SliverToBoxAdapter(
        child: FxCard(
          child: FxEmpty(
            icon: Icons.cloud_off_rounded,
            title: 'Không tải được dữ liệu cơm ca',
            message: _error,
            action: FilledButton.tonalIcon(
              onPressed: () => _loadReport(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ),
        ),
      ));
    } else if (showSkeleton) {
      slivers.add(SliverToBoxAdapter(child: _buildListSkeleton(t, l10n)));
    } else if (_checked && _roster.isEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: FxCard(
          child: FxEmpty(
            icon: Icons.group_off_rounded,
            title: l10n.mealCheckNoData,
            message: 'Chưa có danh sách nhân sự được phân công.',
            action: OutlinedButton.icon(
              onPressed: _loadRoster,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ),
        ),
      ));
    } else if (_checked && _roster.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 8.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'NHÂN VIÊN THEO BỘ PHẬN · ${filtered.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.overline.copyWith(fontFeatures: FxTokens.tabular),
                ),
              ),
              Text('${groups.length} bộ phận', style: t.tiny.copyWith(color: t.textFaint, fontFeatures: FxTokens.tabular)),
            ],
          ),
        ),
      ));

      if (groups.isEmpty) {
        slivers.add(SliverToBoxAdapter(
          child: FxCard(
            child: FxEmpty(
              icon: Icons.search_off_rounded,
              title: 'Không tìm thấy nhân viên phù hợp',
              message: 'Thử đổi từ khóa hoặc bộ lọc.',
            ),
          ),
        ));
      }

      for (final g in groups) {
        final tone = _getGroupColor(g.departmentName);
        final expanded = _expandedDepts.contains(g.departmentName) || hasActiveFilter;
        slivers.add(SliverToBoxAdapter(
          child: _buildGroupHeader(t, g.departmentName, g.members, tone, expanded),
        ));
        if (expanded) {
          slivers.add(SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildPersonItem(
                t,
                g.members[index],
                tone,
                first: index == 0,
                last: index == g.members.length - 1,
              ),
              childCount: g.members.length,
            ),
          ));
        }
      }

      slivers.add(SliverToBoxAdapter(child: _buildLegend(t)));
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 24.h),
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
      ],
    );
  }

  Widget _buildDateNavigator(FxTokens t, AppLocalizations l10n) {
    final busy = _isSaving || _isLoading;
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    return FxCard(
      padding: EdgeInsets.all(8.w),
      child: Row(
        children: [
          MxSquareButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Ngày trước',
            onTap: busy ? null : () => _changeDate(_selectedDate.subtract(const Duration(days: 1))),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: busy ? null : _pickSingleDate,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_weekdayOf(_selectedDate).toUpperCase(), style: t.overline),
                      SizedBox(height: 3.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14.sp, color: t.ink(FxTokens.blue)),
                          SizedBox(width: 6.w),
                          Flexible(
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.num(18.sp, color: busy ? t.textMuted : t.text),
                            ),
                          ),
                          if (isToday) ...[
                            SizedBox(width: 8.w),
                            FxPill(label: l10n.today, tone: FxTokens.blue),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          MxSquareButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Ngày sau',
            onTap: busy ? null : () => _changeDate(_selectedDate.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummary(FxTokens t, List<UserAssignment> filtered) {
    final synced = _isSyncedDaily;
    final total = _grandTotalDaily;
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Display-only breakdown of the same figures (people with a meal, meals per slot).
    var withMeal = 0;
    final slotCounts = <String, int>{'sang': 0, 'trua': 0, 'toi': 0};
    for (final p in filtered) {
      if (_personTotal(p.userId) > 0) withMeal++;
      final dm = _mealData[p.userId.toString()]?[dateKey];
      if (dm == null) continue;
      if (dm.sang) slotCounts['sang'] = slotCounts['sang']! + 1;
      if (dm.trua) slotCounts['trua'] = slotCounts['trua']! + 1;
      if (dm.toi) slotCounts['toi'] = slotCounts['toi']! + 1;
    }
    final people = filtered.length;
    final pct = people == 0 ? 0 : (withMeal / people * 100).round();
    final activeSlots = mealSlots.where((s) => _selectedSlots.contains(s.key)).toList();

    Widget mini(MealSlot slot) => Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_slotIcon(slot.key), size: 13.sp, color: Colors.white.withValues(alpha: 0.85)),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        slot.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5.sp, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('${slotCounts[slot.key] ?? 0}', style: t.num(19.sp, color: Colors.white)),
              ],
            ),
          ),
        );

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FxTokens.rCard),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF4338CA)],
        ),
        boxShadow: t.dark
            ? const []
            : [BoxShadow(color: FxTokens.blue.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_rounded, size: 15.sp, color: Colors.white.withValues(alpha: 0.85)),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Tổng suất · ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontFeatures: FxTokens.tabular,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(FxTokens.rPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: synced ? const Color(0xFF6EE7B7) : const Color(0xFFFCD34D),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      synced ? 'Đã đồng bộ' : 'Chưa đồng bộ',
                      style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$total', style: t.num(38.sp, color: Colors.white)),
              SizedBox(width: 8.w),
              Padding(
                padding: EdgeInsets.only(bottom: 5.h),
                child: Text(
                  'suất',
                  style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          FxStackBar(
            height: 6,
            parts: [
              (value: withMeal.toDouble(), color: const Color(0xFF6EE7B7)),
              (value: (people - withMeal).toDouble(), color: Colors.white.withValues(alpha: 0.18)),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Nhân viên: $people · $withMeal có suất · $pct%',
            style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.8), fontFeatures: FxTokens.tabular),
          ),
          if (activeSlots.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                for (var i = 0; i < activeSlots.length; i++) ...[
                  if (i > 0) SizedBox(width: 8.w),
                  mini(activeSlots[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolsCard(FxTokens t) {
    final syncDisabled = _isSaving || _isSyncing || _isLoading;
    return FxCard(
      padding: EdgeInsets.all(12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showLocationSettings = !_showLocationSettings;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(0, 44.h),
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    backgroundColor: _showLocationSettings ? t.soft(FxTokens.blue) : null,
                    side: BorderSide(color: _showLocationSettings ? FxTokens.blue.withValues(alpha: 0.35) : t.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded, size: 18.sp, color: t.ink(FxTokens.red)),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          'Điểm ăn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: t.text),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        _showLocationSettings ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18.sp,
                        color: t.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Tooltip(
                  message: 'Quét định vị GPS',
                  child: FilledButton(
                    onPressed: syncDisabled ? null : _syncGPS,
                    style: FilledButton.styleFrom(
                      minimumSize: Size(0, 44.h),
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      backgroundColor: t.soft(FxTokens.violet),
                      foregroundColor: t.ink(FxTokens.violet),
                      disabledBackgroundColor: t.cardAlt,
                      disabledForegroundColor: t.textFaint,
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSyncing)
                          SizedBox(
                            width: 14.sp,
                            height: 14.sp,
                            child: CircularProgressIndicator(strokeWidth: 2, color: t.ink(FxTokens.violet)),
                          )
                        else
                          Icon(Icons.satellite_alt_rounded, size: 18.sp),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            _isSyncing ? 'Đang quét…' : 'Quét GPS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _buildLocationSettings(t),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSettings(FxTokens t) {
    if (!_showLocationSettings) return const SizedBox(width: double.infinity);

    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, thickness: 1, color: t.divider),
          SizedBox(height: 12.h),
          Row(
            children: [
              FxIconBadge(icon: Icons.my_location_rounded, tone: FxTokens.red, size: 28),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tọa độ điểm ăn', style: t.h3),
                    Text('Dùng khi quét GPS', style: t.tiny),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildInputNumber(
                  t,
                  label: 'VĨ ĐỘ',
                  value: _latitude,
                  onChanged: (val) {
                    setState(() {
                      _latitude = val;
                    });
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildInputNumber(
                  t,
                  label: 'KINH ĐỘ',
                  value: _longitude,
                  onChanged: (val) {
                    setState(() {
                      _longitude = val;
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _buildInputNumber(
            t,
            label: 'BÁN KÍNH (M)',
            value: _radius,
            suffix: 'm',
            onChanged: (val) {
              setState(() {
                _radius = val;
              });
            },
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 13.sp, color: t.textFaint),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  '* Trống tọa độ sẽ dùng tọa độ trạm chính mặc định.',
                  style: t.tiny.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputNumber(
    FxTokens t, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.overline),
        SizedBox(height: 5.h),
        TextFormField(
          initialValue: value.toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: t.body.copyWith(fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            suffixText: suffix,
            suffixStyle: t.small,
          ),
          onChanged: (val) {
            final parsed = double.tryParse(val);
            if (parsed != null) {
              onChanged(parsed);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSyncProgress(FxTokens t) {
    final determinate = _isLoading && _progressTotal > 0;
    final ratio = determinate ? (_progressCurrent / _progressTotal).clamp(0.0, 1.0) : null;
    return FxCard(
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.satellite_alt_rounded,
            tone: FxTokens.violet,
            title: 'Đang quét GPS',
            subtitle: determinate ? 'Đang đối chiếu định vị với điểm ăn…' : 'Đang chuẩn bị tiến trình quét…',
            trailing: determinate
                ? Text('$_progressCurrent / $_progressTotal', style: t.num(13.sp, color: t.ink(FxTokens.violet)))
                : null,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: FxTokens.violet,
              backgroundColor: t.track,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(FxTokens t) {
    Widget dropdown({
      required int? value,
      required String allLabel,
      required List<({int id, String name})> options,
      required ValueChanged<int?> onChanged,
    }) {
      return DropdownButtonFormField<int?>(
        isExpanded: true,
        menuMaxHeight: 300.h,
        initialValue: value,
        borderRadius: BorderRadius.circular(14.r),
        dropdownColor: t.card,
        icon: Icon(Icons.expand_more_rounded, size: 18.sp, color: t.textMuted),
        // merged onto the theme style so the dropdown keeps the app font family
        style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .merge(t.body.copyWith(fontWeight: FontWeight.w600)),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
          fillColor: value != null ? t.soft(FxTokens.blue) : null,
          enabledBorder: value != null
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: FxTokens.blue.withValues(alpha: 0.35)),
                )
              : null,
        ),
        hint: Text(allLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.small),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text(allLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ...options.map((opt) => DropdownMenuItem<int?>(
                value: opt.id,
                child: Text(opt.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: onChanged,
      );
    }

    return FxCard(
      padding: EdgeInsets.all(12.w),
      child: Column(
        children: [
          FxSearchField(
            controller: _searchCtrl,
            hint: 'Tìm họ tên, bộ phận, tay nghề...',
            onChanged: (val) {
              setState(() {
                _nameFilter = val;
              });
            },
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: dropdown(
                  value: _departmentFilter,
                  allLabel: 'Tất cả bộ phận',
                  options: _departmentOptions,
                  onChanged: (val) {
                    setState(() {
                      _departmentFilter = val;
                    });
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: dropdown(
                  value: _skillFilter,
                  allLabel: 'Tất cả tay nghề',
                  options: _skillOptions,
                  onChanged: (val) {
                    setState(() {
                      _skillFilter = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(FxTokens t) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 6.w, 8.h),
      decoration: BoxDecoration(
        color: t.soft(FxTokens.red),
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        border: Border.all(color: FxTokens.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18.sp, color: t.ink(FxTokens.red)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              _error ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, color: t.ink(FxTokens.red), height: 1.35),
            ),
          ),
          TextButton(
            onPressed: () => _loadReport(),
            style: TextButton.styleFrom(foregroundColor: t.ink(FxTokens.red)),
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildListSkeleton(FxTokens t, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 4.h, 4.w, 10.h),
          child: Row(
            children: [
              SizedBox(width: 12.w, height: 12.w, child: const CircularProgressIndicator(strokeWidth: 1.8)),
              SizedBox(width: 8.w),
              Expanded(child: Text(l10n.mealCheckLoading, style: t.tiny)),
            ],
          ),
        ),
        for (var i = 0; i < 4; i++) ...[
          FxSkeleton(height: 62.h, radius: 16),
          SizedBox(height: 10.h),
        ],
      ],
    );
  }

  Widget _buildGroupHeader(FxTokens t, String departmentName, List<UserAssignment> members, Color color, bool isExpanded) {
    final icon = _getGroupIcon(departmentName);

    int groupMeals = 0;
    int withMeal = 0;
    for (final m in members) {
      final n = _personTotal(m.userId);
      groupMeals += n;
      if (n > 0) withMeal++;
    }

    return MxSegment(
      top: true,
      bottom: !isExpanded,
      onTap: () {
        setState(() {
          if (_expandedDepts.contains(departmentName)) {
            _expandedDepts.remove(departmentName);
          } else {
            _expandedDepts.add(departmentName);
          }
        });
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 11.h, 10.w, 11.h),
        child: Row(
          children: [
            FxIconBadge(icon: icon, tone: color, size: 36),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(departmentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3),
                  SizedBox(height: 2.h),
                  Text(
                    '${members.length} nhân sự · $withMeal có suất',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$groupMeals', style: t.num(16.sp, color: groupMeals > 0 ? t.ink(FxTokens.emerald) : t.textMuted)),
                Text('suất', style: t.tiny.copyWith(color: t.textFaint)),
              ],
            ),
            SizedBox(width: 6.w),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, size: 22.sp, color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGroupColor(String deptName) {
    final lower = deptName.toLowerCase();
    if (lower.contains('qlsx') || lower.contains('bld') || lower.contains('quản lý')) return FxTokens.indigo;
    if (lower.contains('vp') || lower.contains('văn phòng')) return FxTokens.blue;
    if (lower.contains('vht') || lower.contains('vận hành')) return FxTokens.violet;
    if (lower.contains('qa') || lower.contains('qc')) return FxTokens.orange;
    if (lower.contains('bơm') && !lower.contains('tĩnh')) return FxTokens.emerald;
    if (lower.contains('bơm tĩnh') || lower.contains('tĩnh')) return FxTokens.cyan;
    if (lower.contains('xe bồn') || lower.contains('bồn')) return FxTokens.amber;
    return FxTokens.slate;
  }

  IconData _getGroupIcon(String deptName) {
    final lower = deptName.toLowerCase();
    if (lower.contains('qlsx') || lower.contains('bld') || lower.contains('quản lý')) {
      return Icons.admin_panel_settings_rounded;
    }
    if (lower.contains('vp') || lower.contains('văn phòng')) return Icons.business_rounded;
    if (lower.contains('vht') || lower.contains('vận hành')) return Icons.precision_manufacturing_rounded;
    if (lower.contains('qa') || lower.contains('qc')) return Icons.science_rounded;
    if (lower.contains('bơm') && !lower.contains('tĩnh')) return Icons.local_shipping_rounded;
    if (lower.contains('bơm tĩnh') || lower.contains('tĩnh')) return Icons.plumbing_rounded;
    if (lower.contains('xe bồn') || lower.contains('bồn')) return Icons.local_shipping_outlined;
    return Icons.group_rounded;
  }

  Widget _buildPersonItem(FxTokens t, UserAssignment person, Color tone, {required bool first, required bool last}) {
    final totalCount = _personTotal(person.userId);
    final hasMeal = totalCount > 0;

    final isSingleDay = _fromDate.year == _toDate.year && _fromDate.month == _toDate.month && _fromDate.day == _toDate.day;

    final String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dm = isSingleDay ? (_mealData[person.userId.toString()]?[dateKey]) : null;

    final bool isSang = isSingleDay ? (dm?.sang ?? false) : _aggregated(person.userId.toString()).sang;
    final String? sangSource = isSingleDay ? dm?.sangSource : null;

    final bool isTrua = isSingleDay ? (dm?.trua ?? false) : _aggregated(person.userId.toString()).trua;
    final String? truaSource = isSingleDay ? dm?.truaSource : null;

    final bool isToi = isSingleDay ? (dm?.toi ?? false) : _aggregated(person.userId.toString()).toi;
    final String? toiSource = isSingleDay ? dm?.toiSource : null;

    bool pending(String slot) => _pendingChanges.containsKey('${person.userId}_${dateKey}_$slot');

    // v1 shows the department under the name; inside a department card the skill is more useful,
    // so it is shown first when available.
    final sub = (person.skillName != null && person.skillName!.isNotEmpty)
        ? person.skillName!
        : (person.departmentName ?? '');

    Widget slot(String key, String label, bool active, String? source) => MxSlotToggle(
          label: label,
          active: active,
          manual: source == 'manual',
          pending: pending(key),
          onTap: isSingleDay ? () => _toggleCell(person, key) : null,
        );

    return MxSegment(
      bottom: last,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, margin: EdgeInsets.only(left: first ? 0 : 58.w), color: t.divider),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 9.h, 10.w, 9.h),
            child: Row(
              children: [
                MxAvatar(name: person.userFullName, tone: tone, size: 34),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        person.userFullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.body.copyWith(fontWeight: FontWeight.w700, height: 1.25),
                      ),
                      if (sub.isNotEmpty)
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                if (_selectedSlots.contains('sang')) slot('sang', 'Tr', isSang, sangSource),
                if (_selectedSlots.contains('trua')) ...[
                  SizedBox(width: 5.w),
                  slot('trua', 'Ch', isTrua, truaSource),
                ],
                if (_selectedSlots.contains('toi')) ...[
                  SizedBox(width: 5.w),
                  slot('toi', 'T', isToi, toiSource),
                ],
                SizedBox(width: 8.w),
                Container(
                  constraints: BoxConstraints(minWidth: 26.w),
                  height: 24.h,
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.soft(hasMeal ? FxTokens.emerald : FxTokens.red),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '$totalCount',
                    style: t.num(12.sp, color: t.ink(hasMeal ? FxTokens.emerald : FxTokens.red)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(FxTokens t) {
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            SizedBox(width: 6.w),
            Text(label, style: t.small),
          ],
        );

    return FxCard(
      margin: EdgeInsets.only(top: 2.h),
      padding: EdgeInsets.all(14.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHÚ THÍCH', style: t.overline),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 8.h,
            children: [
              item(const MxSlotToggle(label: 'Tr', active: true, size: 22), 'Tự động'),
              item(const MxSlotToggle(label: 'Tr', active: true, manual: true, size: 22), 'Chấm tay'),
              item(const MxSlotToggle(label: 'Tr', active: false, size: 22), 'Không có suất'),
              item(const MxSlotToggle(label: 'Tr', active: true, pending: true, size: 22), 'Chưa lưu'),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            mealSlots.map((s) => '${mxSlotShort(s.key)} = ${s.label}').join(' · '),
            style: t.tiny.copyWith(color: t.text, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4.h),
          Text(
            '* Bấm vào các ký hiệu Tr, Ch, T để thêm/bỏ suất ăn của nhân viên, rồi nhấn Lưu.',
            style: t.tiny.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  // ── Overview tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab(FxTokens t, AppLocalizations l10n) {
    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 24.h),
      children: [
        _buildOverviewToolbar(t),
        SizedBox(height: 12.h),
        if (_isOverviewLoading) ...[
          Row(
            children: [
              Expanded(child: FxSkeleton(height: 112.h, radius: 18)),
              SizedBox(width: 10.w),
              Expanded(child: FxSkeleton(height: 112.h, radius: 18)),
            ],
          ),
          SizedBox(height: 12.h),
          FxSkeleton(height: 400.h, radius: 18),
        ] else if (_overviewReport == null)
          FxCard(
            child: FxEmpty(
              icon: Icons.event_busy_rounded,
              title: 'Không có dữ liệu tổng quan.',
              message: 'Chọn tháng khác hoặc tải lại.',
              action: FilledButton.tonalIcon(
                onPressed: _loadOverviewReport,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retry),
              ),
            ),
          )
        else ...[
          _buildOverviewStats(t),
          _buildCalendarCard(t),
        ],
      ],
    );
  }

  Widget _buildOverviewToolbar(FxTokens t) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: t.card,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: BorderSide(color: t.border),
            ),
            child: InkWell(
              onTap: _pickMonth,
              child: SizedBox(
                height: 44.h,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 17.sp, color: t.ink(FxTokens.blue)),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'Tháng ${DateFormat('MM/yyyy').format(_selectedMonth)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.h3.copyWith(fontFeatures: FxTokens.tabular),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18.sp, color: t.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        MxSquareButton(icon: Icons.refresh_rounded, tooltip: 'Tải lại', onTap: _loadOverviewReport, size: 44),
        SizedBox(width: 8.w),
        Tooltip(
          message: 'Xuất Excel tháng',
          child: Material(
            color: _isOverviewLoading ? t.cardAlt : t.soft(FxTokens.emerald),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
              side: BorderSide(color: _isOverviewLoading ? t.border : FxTokens.emerald.withValues(alpha: 0.3)),
            ),
            child: InkWell(
              onTap: _isOverviewLoading ? null : _exportMonthlyExcel,
              child: SizedBox(
                height: 44.h,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        size: 18.sp,
                        color: _isOverviewLoading ? t.textFaint : t.ink(FxTokens.emerald),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Excel',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w800,
                          color: _isOverviewLoading ? t.textFaint : t.ink(FxTokens.emerald),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStats(FxTokens t) {
    int daysWithPortions = 0;
    int totalPortions = 0;

    if (_overviewReport != null && _overviewReport!['by_date'] != null) {
      final byDate = _overviewReport!['by_date'] as List<dynamic>;
      for (final day in byDate) {
        final count = day['allowance_count'] is int
            ? day['allowance_count'] as int
            : (int.tryParse(day['allowance_count'].toString()) ?? 0);
        if (count > 0) {
          daysWithPortions++;
        }
        totalPortions += count;
      }
    }

    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final avg = daysWithPortions == 0 ? 0.0 : totalPortions / daysWithPortions;

    return FxGrid(
      columns: 2,
      children: [
        FxKpi(
          icon: Icons.event_available_rounded,
          label: 'Số ngày có suất ăn',
          value: '$daysWithPortions',
          unit: 'ngày',
          sub: 'Trong $daysInMonth ngày của tháng',
          tone: FxTokens.blue,
        ),
        FxKpi(
          icon: Icons.restaurant_rounded,
          label: 'Tổng suất ăn',
          value: NumberFormat('#,##0', 'vi').format(totalPortions),
          unit: 'suất',
          sub: 'TB ${NumberFormat('#,##0.#', 'vi').format(avg)} suất / ngày có suất',
          tone: FxTokens.emerald,
        ),
      ],
    );
  }

  Widget _buildCalendarCard(FxTokens t) {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return FxCard(
      padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.calendar_view_month_rounded,
            tone: FxTokens.indigo,
            title: 'Lịch suất ăn',
            subtitle: 'Chạm vào một ngày để xem chi tiết',
          ),
          Row(
            children: weekdays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: t.overline.copyWith(
                      fontSize: 10.5.sp,
                      color: day == 'CN' ? t.ink(FxTokens.red) : t.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 8.h),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: 5.w,
            crossAxisSpacing: 5.w,
            childAspectRatio: 0.84,
            children: _buildCalendarCells(t),
          ),
          SizedBox(height: 14.h),
          Divider(height: 1, thickness: 1, color: t.divider),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 6.h,
            children: [
              const FxLegend(color: FxTokens.emerald, label: 'Ngày có suất ăn'),
              FxLegend(color: t.border, label: 'Không có dữ liệu'),
              const FxLegend(color: FxTokens.blue, label: 'Hôm nay'),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarCells(FxTokens t) {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);

    final lead = start.weekday - 1;

    // Display-only: the month's highest daily count, used to shade the cells.
    var maxPortions = 0;
    if (_overviewReport != null && _overviewReport!['by_date'] != null) {
      for (final day in _overviewReport!['by_date'] as List<dynamic>) {
        final c = day['allowance_count'] is int
            ? day['allowance_count'] as int
            : (int.tryParse(day['allowance_count'].toString()) ?? 0);
        if (c > maxPortions) maxPortions = c;
      }
    }

    final cells = <Widget>[];
    for (int i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_selectedMonth.year, _selectedMonth.month, d);
      final dateStr = DateFormat('yyyy-MM-dd').format(day);

      int portions = 0;
      if (_overviewReport != null && _overviewReport!['by_date'] != null) {
        final byDate = _overviewReport!['by_date'] as List<dynamic>;
        final match = byDate.firstWhere(
          (element) => element['work_date']?.toString().substring(0, 10) == dateStr,
          orElse: () => null,
        );
        if (match != null) {
          portions = match['allowance_count'] is int
              ? match['allowance_count'] as int
              : (int.tryParse(match['allowance_count'].toString()) ?? 0);
        }
      }

      final isToday = DateUtils.isSameDay(day, DateTime.now());
      final ratio = maxPortions == 0 ? 0.0 : portions / maxPortions;
      final bg = portions > 0
          ? FxTokens.emerald.withValues(alpha: (t.dark ? 0.16 : 0.08) + (t.dark ? 0.30 : 0.22) * ratio)
          : t.cardAlt;
      final borderColor = isToday
          ? FxTokens.blue
          : (portions > 0 ? FxTokens.emerald.withValues(alpha: 0.3) : t.border.withValues(alpha: 0.7));

      cells.add(
        Material(
          color: bg,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
            side: BorderSide(color: borderColor, width: isToday ? 1.6 : 1),
          ),
          child: InkWell(
            onTap: () => _showDayDetailBottomSheet(dateStr),
            child: Padding(
              padding: EdgeInsets.fromLTRB(5.w, 4.h, 5.w, 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$d',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                      color: isToday ? t.ink(FxTokens.blue) : (portions > 0 ? t.text : t.textMuted),
                      fontFeatures: FxTokens.tabular,
                      height: 1.1,
                    ),
                  ),
                  const Spacer(),
                  if (portions > 0)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('$portions', style: t.num(13.sp, color: t.ink(FxTokens.emerald))),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return cells;
  }

  void _showDayDetailBottomSheet(String dateStr) {
    if (_overviewReport == null || _overviewReport!['by_date'] == null) return;
    final byDate = _overviewReport!['by_date'] as List<dynamic>;
    final match = byDate.firstWhere(
      (element) => element['work_date']?.toString().substring(0, 10) == dateStr,
      orElse: () => null,
    );

    final meta = match != null ? (match['meta'] as List<dynamic>? ?? []) : [];

    final users = <int, ({String name, String? shortName, List<Map<String, dynamic>> slots})>{};
    for (final m in meta) {
      // v2 fix: v1 used int.parse, which throws (and the sheet never opens) when user_id is missing.
      final userId = m['user_id'] is int ? m['user_id'] as int : int.tryParse(m['user_id'].toString());
      if (userId == null) continue;
      final name = m['user_full_name']?.toString() ?? '';
      final shortName = m['user_short_name']?.toString();
      final slot = m['meal_slot']?.toString() ?? '';
      final source = m['source']?.toString() ?? 'auto';

      users.putIfAbsent(userId, () => (name: name, shortName: shortName, slots: []));
      users[userId]!.slots.add({'slot': slot, 'source': source});
    }

    final sortedUsers = users.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FxTokens.of(context).card,
      builder: (ctx) {
        final t = FxTokens.of(ctx);
        final date = DateTime.parse(dateStr);

        // Display-only summary of the same entries.
        final slotCounts = <String, int>{};
        var manualCount = 0;
        var totalSlots = 0;
        for (final u in sortedUsers) {
          for (final s in u.slots) {
            final key = s['slot'] as String;
            slotCounts[key] = (slotCounts[key] ?? 0) + 1;
            if (s['source'] == 'manual') manualCount++;
            totalSlots++;
          }
        }

        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 10.h),
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 10.h),
                child: Row(
                  children: [
                    FxIconBadge(icon: Icons.event_note_rounded, tone: FxTokens.blue, size: 42),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết ngày ${DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr))}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.h2.copyWith(fontSize: 16.sp, fontFeatures: FxTokens.tabular),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${_weekdayOf(date)} · ${sortedUsers.length} người · $totalSlots suất',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              if (sortedUsers.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
                  child: Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      for (final s in mealSlots)
                        if ((slotCounts[s.key] ?? 0) > 0)
                          FxPill(label: '${s.label} · ${slotCounts[s.key]}', tone: FxTokens.emerald, icon: _slotIcon(s.key)),
                      if (manualCount > 0)
                        FxPill(label: 'Chấm tay · $manualCount', tone: FxTokens.amber, icon: Icons.edit_rounded),
                    ],
                  ),
                ),
              Divider(height: 1, thickness: 1, color: t.divider),
              Expanded(
                child: sortedUsers.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: FxEmpty(
                            icon: Icons.no_meals_rounded,
                            title: 'Không có suất ăn nào trong ngày này.',
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        itemCount: sortedUsers.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          thickness: 1,
                          color: t.divider,
                          indent: 64.w,
                          endIndent: 16.w,
                        ),
                        itemBuilder: (context, index) {
                          final u = sortedUsers[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
                            child: Row(
                              children: [
                                MxAvatar(name: u.name, tone: MxAvatar.toneFor(u.name), size: 36),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h3),
                                      if (u.shortName != null && u.shortName!.isNotEmpty)
                                        Text(u.shortName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.tiny),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Wrap(
                                  spacing: 4.w,
                                  runSpacing: 4.h,
                                  children: u.slots.map((s) {
                                    final isManual = s['source'] == 'manual';
                                    final label = s['slot'] == 'sang'
                                        ? 'Tr'
                                        : s['slot'] == 'trua'
                                            ? 'Ch'
                                            : 'T';
                                    return MxSlotChip(label: label, manual: isManual);
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.divider))),
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
                child: SafeArea(
                  top: false,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _activeTabIndex = 0;
                        _selectedDate = DateTime.parse(dateStr);
                        _fromDate = _selectedDate;
                        _toDate = _selectedDate;
                      });
                      _loadReport();
                    },
                    style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 48.h)),
                    icon: const Icon(Icons.edit_calendar_rounded),
                    label: const Text('Chấm ngày này'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
