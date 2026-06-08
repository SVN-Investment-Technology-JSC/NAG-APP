import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:nguyenanh/features/meal/data/models/meal_model.dart';
import 'package:nguyenanh/features/meal/data/services/meal_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class MealCheckPage extends StatefulWidget {
  const MealCheckPage({super.key});

  @override
  State<MealCheckPage> createState() => _MealCheckPageState();
}

class _MealCheckPageState extends State<MealCheckPage> {
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

  @override
  void initState() {
    super.initState();
    _loadRoster();
    _loadReport();
  }

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
      builder: (ctx) => AlertDialog(
        title: const Text('Thay đổi chưa lưu'),
        content: const Text('Bạn có thay đổi chưa lưu. Bạn có chắc chắn muốn bỏ qua các thay đổi này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ qua'),
          ),
        ],
      ),
    ) ?? false;
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
            if (activeSlots.any((s) => s.key == 'sang') && dm.sang) { slotMap['sang'] = true; personTotal++; }
            if (activeSlots.any((s) => s.key == 'trua') && dm.trua) { slotMap['trua'] = true; personTotal++; }
            if (activeSlots.any((s) => s.key == 'toi') && dm.toi) { slotMap['toi'] = true; personTotal++; }
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
      final tableHeight = titleH + dateH + headerH + rowH + rowH +
          (sectionRows * sectionH) + (dataRows * rowH) + totalRowH;

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
      final dateStr = '${l10n.mealFromDate} ${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${l10n.mealToDate} ${DateFormat('dd/MM/yyyy').format(_toDate)}';
      drawText(canvas, dateStr, 0, y, tableWidth, dateH,
          fontSize: 13, bold: true, color: const Color(0xFF1E40AF));
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
        drawText(canvas, '', 0, y, colSTT, sectionH,
            fontSize: 11, bold: true, color: const Color(0xFFB45309));
        canvas.drawRect(Rect.fromLTWH(colSTT, y, tableWidth - colSTT, sectionH), borderPaint);
        drawText(canvas, g.departmentName, colSTT, y, colName, sectionH,
            fontSize: 11, bold: true, color: const Color(0xFFB45309), align: TextAlign.left);
        y += sectionH;

        for (final member in g.members) {
          canvas.drawRect(Rect.fromLTWH(0, y, colSTT, rowH), borderPaint);
          drawText(canvas, '$stt', 0, y, colSTT, rowH, fontSize: 10);
          canvas.drawRect(Rect.fromLTWH(colSTT, y, colName, rowH), borderPaint);
          drawText(canvas, member.hoTen, colSTT, y, colName, rowH,
              fontSize: 10, align: TextAlign.left);

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
                drawText(canvas, '/', dx, y, colSlot, rowH,
                    fontSize: 12, bold: true, color: const Color(0xFFFFFFFF));
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
      final fileName = 'com_ca_${DateFormat('dd-MM-yyyy').format(_fromDate)}_${DateFormat('dd-MM-yyyy').format(_toDate)}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      await Share.shareXFiles(
        [XFile(file.path)], 
        subject: 'Com Ca ${DateFormat('dd/MM').format(_fromDate)} - ${DateFormat('dd/MM').format(_toDate)}',
        sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
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
          sheet.appendRow([
            TextCellValue(row['stt'].toString()),
            TextCellValue(row['hoTen'].toString())
          ]);
        } else {
          List<CellValue> r = [
            TextCellValue(row['stt'].toString()),
            TextCellValue(row['hoTen'].toString())
          ];
          
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
      for (int i=0; i<days.length * activeSlots.length; i++) {
        totalRow.add(TextCellValue(''));
      }
      totalRow.add(IntCellValue(_totalMeals));
      sheet.appendRow(totalRow);
      
      final bytes = excel.encode();
      if (bytes == null) return;
      
      final dir = await getTemporaryDirectory();
      final fileName = 'com_ca_${DateFormat('dd-MM-yyyy').format(_fromDate)}_${DateFormat('dd-MM-yyyy').format(_toDate)}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      await Share.shareXFiles(
        [XFile(file.path)], 
        subject: 'Bảng Cơm Ca ${DateFormat('dd/MM').format(_fromDate)} - ${DateFormat('dd/MM').format(_toDate)}',
        sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
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
          builder: (ctx) => AlertDialog(
            title: Text('Cảnh báo thiếu phân công', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            content: Text('Ngày $dateStr chưa có đầy đủ phân công Xe Bơm, Xe Bồn hoặc Công Việc.\n\nNếu quét GPS, hệ thống có thể không chấm đúng người.\nBạn có chắc chắn muốn quét GPS không?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vẫn quét')),
            ],
          ),
        ) ?? false;
      } else {
        shouldProceed = true;
      }
      
      if (!shouldProceed) {
        setState(() => _isSyncing = false);
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

  // ──────────── Build ────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

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
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: Text(
            l10n.mealCheck,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.menu_rounded, color: colorScheme.primary),
              tooltip: 'Thao tác',
              onSelected: (value) {
                if (value == 'excel') _exportExcel();
                if (value == 'image') _shareImage();
                if (value == 'sync') _syncGPS();
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
                  value: 'image',
                  child: Row(
                    children: [
                      Icon(Icons.image_rounded, size: 20.sp, color: colorScheme.onSurface),
                      SizedBox(width: 12.w),
                      const Text('Xuất Ảnh'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'sync',
                  child: Row(
                    children: [
                      Icon(Icons.sync_rounded, size: 20.sp, color: colorScheme.onSurface),
                      SizedBox(width: 12.w),
                      const Text('Quét GPS'),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(width: 4.w),
          ],
        ),
        body: Column(
          children: [
            _buildTabBar(colorScheme, theme),
            Expanded(
              child: _activeTabIndex == 0
                  ? _buildDailyTab(theme, colorScheme, l10n)
                  : _buildOverviewTab(colorScheme, theme),
            ),
          ],
        ),
      ),
    ),);
  }

  Widget _buildTabBar(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _isSaving || _isLoading
                  ? null
                  : () {
                      setState(() {
                        _activeTabIndex = 0;
                        _fromDate = _selectedDate;
                        _toDate = _selectedDate;
                      });
                    },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 0 ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: Text(
                    'Chấm theo ngày',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _activeTabIndex == 0 ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: _isSaving || _isLoading
                  ? null
                  : () {
                      setState(() {
                        _activeTabIndex = 1;
                      });
                      if (_overviewReport == null) {
                        _loadOverviewReport();
                      }
                    },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  color: _activeTabIndex == 1 ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Center(
                  child: Text(
                    'Tổng quan',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _activeTabIndex == 1 ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTab(ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    final hasActiveFilter = _nameFilter.isNotEmpty || _departmentFilter != null || _skillFilter != null;
    
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateNavigator(colorScheme, theme),
              _buildDailyStatsRow(colorScheme, theme),
              _buildActionToolbar(colorScheme, theme),
              _buildLocationSettings(colorScheme, theme),
              _buildFiltersRow(colorScheme, theme),
              SizedBox(height: 8.h),
            ],
          ),
        ),
        if (_isLoading && _progressTotal > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _progressCurrent / _progressTotal,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: colorScheme.primary,
                    minHeight: 4.h,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '$_progressCurrent / $_progressTotal',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_checked && _isLoading)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: colorScheme.primary),
                  SizedBox(height: 16.h),
                  Text(
                    l10n.mealCheckLoading,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null && !_checked)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18.sp, color: colorScheme.error),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_checked && !_isLoading)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu_rounded,
                      size: 48.sp,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                  SizedBox(height: 12.h),
                  Text(
                    l10n.mealCheckHint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_checked && _roster.isNotEmpty) ...[
          ...(_groupedRoster.expand((g) => [
                SliverToBoxAdapter(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (_expandedDepts.contains(g.departmentName)) {
                          _expandedDepts.remove(g.departmentName);
                        } else {
                          _expandedDepts.add(g.departmentName);
                        }
                      });
                    },
                    child: _buildGroupHeader(
                        g.departmentName,
                        g.members.map((m) => Personnel(userId: m.userId, tenVT: '', hoTen: m.userFullName, boPhan: m.departmentName ?? '')).toList(),
                        theme,
                        colorScheme,
                        _expandedDepts.contains(g.departmentName) || hasActiveFilter),
                  ),
                ),
                if (_expandedDepts.contains(g.departmentName) || hasActiveFilter)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPersonItem(
                          g.members[index], theme, colorScheme),
                      childCount: g.members.length,
                    ),
                  ),
              ])),
          SliverToBoxAdapter(
            child: _buildLegend(theme, colorScheme),
          ),
        ],
        if (_checked && _roster.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                l10n.mealCheckNoData,
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDateNavigator(ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            onPressed: _isSaving || _isLoading
                ? null
                : () => _changeDate(_selectedDate.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          SizedBox(width: 12.w),
          TextButton(
            onPressed: _isSaving || _isLoading ? null : _pickSingleDate,
            child: Text(
              DateFormat('dd/MM/yyyy').format(_selectedDate),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          IconButton.outlined(
            onPressed: _isSaving || _isLoading
                ? null
                : () => _changeDate(_selectedDate.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStatsRow(ColorScheme colorScheme, ThemeData theme) {
    final synced = _isSyncedDaily;
    final pendingCount = _pendingChanges.length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: synced ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: synced ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(
                      color: synced ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    synced ? 'Đã đồng bộ' : 'Chưa đồng bộ',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: synced ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              'Nhân viên: ${_filteredRoster.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              'Tổng suất: $_grandTotalDaily',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            if (pendingCount > 0) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  'Chưa lưu ($pendingCount)',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionToolbar(ColorScheme colorScheme, ThemeData theme) {
    final hasPending = _pendingChanges.isNotEmpty;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _showLocationSettings = !_showLocationSettings;
              });
            },
            icon: const Icon(Icons.location_on_rounded),
            label: Row(
              children: [
                const Text('Điểm ăn'),
                Icon(
                  _showLocationSettings ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 16.sp,
                ),
              ],
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            ),
          ),
          const Spacer(),
          IconButton.outlined(
            onPressed: _isSaving || _isSyncing || _isLoading ? null : _syncGPS,
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Quét định vị GPS',
          ),
          SizedBox(width: 8.w),
          FilledButton.icon(
            onPressed: !hasPending || _isSaving || _isLoading ? null : _saveChanges,
            icon: _isSaving
                ? SizedBox(
                    width: 14.sp,
                    height: 14.sp,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Lưu'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSettings(ColorScheme colorScheme, ThemeData theme) {
    if (!_showLocationSettings) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputNumber(
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
                  label: 'KINH ĐỘ',
                  value: _longitude,
                  onChanged: (val) {
                    setState(() {
                      _longitude = val;
                    });
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildInputNumber(
                  label: 'BÁN KÍNH (M)',
                  value: _radius,
                  onChanged: (val) {
                    setState(() {
                      _radius = val;
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '* Trống tọa độ sẽ dùng tọa độ trạm chính mặc định.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputNumber({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 4.h),
        SizedBox(
          height: 36.h,
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 12.sp),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onChanged: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null) {
                onChanged(parsed);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersRow(ColorScheme colorScheme, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm họ tên, bộ phận, tay nghề...',
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: EdgeInsets.symmetric(vertical: 8.h),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
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
                child: DropdownButtonFormField<int?>(
                  isExpanded: true,
                  menuMaxHeight: 300.h,
                  value: _departmentFilter,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  hint: const Text('Tất cả bộ phận'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tất cả bộ phận'),
                    ),
                    ..._departmentOptions.map((opt) => DropdownMenuItem<int?>(
                          value: opt.id,
                          child: Text(opt.name),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _departmentFilter = val;
                    });
                  },
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  isExpanded: true,
                  menuMaxHeight: 300.h,
                  value: _skillFilter,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  hint: const Text('Tất cả tay nghề'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tất cả tay nghề'),
                    ),
                    ..._skillOptions.map((opt) => DropdownMenuItem<int?>(
                          value: opt.id,
                          child: Text(opt.name),
                        )),
                  ],
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

  Widget _buildOverviewTab(ColorScheme colorScheme, ThemeData theme) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickMonth,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          DateFormat('MM/yyyy').format(_selectedMonth),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    IconButton.outlined(
                      onPressed: _loadOverviewReport,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Tải lại',
                    ),
                    SizedBox(width: 8.w),
                    IconButton.filledTonal(
                      onPressed: _isOverviewLoading ? null : _exportMonthlyExcel,
                      icon: const Icon(Icons.download_rounded),
                      tooltip: 'Xuất Excel tháng',
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                _buildOverviewStats(colorScheme, theme),
                SizedBox(height: 16.h),
                Row(
                  children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((day) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        ),
        if (_isOverviewLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else if (_overviewReport == null)
          const SliverFillRemaining(
            child: Center(
              child: Text('Không có dữ liệu tổng quan.'),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6.h,
                crossAxisSpacing: 6.w,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildListDelegate(
                _buildCalendarCells(colorScheme, theme),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      width: 14.w,
                      height: 14.w,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text('Ngày có suất ăn', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.sp)),
                    SizedBox(width: 24.w),
                    Container(
                      width: 14.w,
                      height: 14.w,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text('Không có dữ liệu', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.sp)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStats(ColorScheme colorScheme, ThemeData theme) {
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

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                '$daysWithPortions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
              Text(
                'Số ngày có suất ăn',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
          Container(width: 1.w, height: 32.h, color: colorScheme.outlineVariant),
          Column(
            children: [
              Text(
                '$totalPortions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
              Text(
                'Tổng suất ăn',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarCells(ColorScheme colorScheme, ThemeData theme) {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    
    final lead = start.weekday - 1; 
    
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
      
      cells.add(
        InkWell(
          onTap: () => _showDayDetailBottomSheet(dateStr),
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: portions > 0
                  ? Colors.green.withValues(alpha: 0.1)
                  : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: isToday
                    ? colorScheme.primary
                    : (portions > 0 ? Colors.green.withValues(alpha: 0.3) : Colors.transparent),
                width: isToday ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 2,
                  left: 2,
                  child: Text(
                    '$d',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                      color: isToday ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (portions > 0)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$portions',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 8.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
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
      final userId = m['user_id'] is int ? m['user_id'] as int : int.parse(m['user_id'].toString());
      final name = m['user_full_name']?.toString() ?? '';
      final shortName = m['user_short_name']?.toString();
      final slot = m['meal_slot']?.toString() ?? '';
      final source = m['source']?.toString() ?? 'auto';
      
      users.putIfAbsent(userId, () => (name: name, shortName: shortName, slots: []));
      users[userId]!.slots.add({'slot': slot, 'source': source});
    }
    
    final sortedUsers = users.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.7,
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chi tiết ngày ${DateFormat('dd/MM/yyyy').format(DateTime.parse(dateStr))}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: sortedUsers.isEmpty
                    ? const Center(child: Text('Không có suất ăn nào trong ngày này.'))
                    : ListView.builder(
                        itemCount: sortedUsers.length,
                        itemBuilder: (context, index) {
                          final u = sortedUsers[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(u.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            subtitle: u.shortName != null ? Text(u.shortName!) : null,
                            trailing: Wrap(
                              spacing: 4.w,
                              children: u.slots.map((s) {
                                final isManual = s['source'] == 'manual';
                                final label = s['slot'] == 'sang' ? 'S' : s['slot'] == 'trua' ? 'Tr' : 'T';
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: isManual ? const Color(0xFFFEF3C7) : Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4.r),
                                    border: Border.all(
                                      color: isManual ? const Color(0xFFFBBF24) : Colors.green.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isManual ? const Color(0xFFB45309) : Colors.green,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(),
              SizedBox(
                width: double.infinity,
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
                  icon: const Icon(Icons.edit_calendar_rounded),
                  label: const Text('Chấm ngày này'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupHeader(String departmentName, List<Personnel> members,
      ThemeData theme, ColorScheme colorScheme, bool isExpanded) {
    final color = _getGroupColor(departmentName, colorScheme);
    final icon = _getGroupIcon(departmentName);

    int groupMeals = 0;
    for (final m in members) {
      if (m.userId != null) {
        groupMeals += _personTotal(m.userId!);
      }
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04)
          ],
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
                  departmentName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${members.length} nhân sự · $groupMeals suất',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Color _getGroupColor(String deptName, ColorScheme colorScheme) {
    final lower = deptName.toLowerCase();
    if (lower.contains('qlsx') || lower.contains('bld') || lower.contains('quản lý')) return const Color(0xFF6366F1);
    if (lower.contains('vp') || lower.contains('văn phòng')) return const Color(0xFF0EA5E9);
    if (lower.contains('vht') || lower.contains('vận hành')) return const Color(0xFF8B5CF6);
    if (lower.contains('qa') || lower.contains('qc')) return const Color(0xFFF97316);
    if (lower.contains('bơm') && !lower.contains('tĩnh')) return const Color(0xFF14B8A6);
    if (lower.contains('bơm tĩnh') || lower.contains('tĩnh')) return const Color(0xFFEC4899);
    if (lower.contains('xe bồn') || lower.contains('bồn')) return const Color(0xFFF59E0B);
    return colorScheme.primary;
  }

  IconData _getGroupIcon(String deptName) {
    final lower = deptName.toLowerCase();
    if (lower.contains('qlsx') || lower.contains('bld') || lower.contains('quản lý')) return Icons.admin_panel_settings_rounded;
    if (lower.contains('vp') || lower.contains('văn phòng')) return Icons.business_rounded;
    if (lower.contains('vht') || lower.contains('vận hành')) return Icons.precision_manufacturing_rounded;
    if (lower.contains('qa') || lower.contains('qc')) return Icons.science_rounded;
    if (lower.contains('bơm') && !lower.contains('tĩnh')) return Icons.local_shipping_rounded;
    if (lower.contains('bơm tĩnh') || lower.contains('tĩnh')) return Icons.plumbing_rounded;
    if (lower.contains('xe bồn') || lower.contains('bồn')) return Icons.local_shipping_outlined;
    return Icons.group_rounded;
  }

  Widget _buildPersonItem(
      UserAssignment person, ThemeData theme, ColorScheme colorScheme) {
    final totalCount = _personTotal(person.userId);
    final hasMeal = totalCount > 0;
    
    final isSingleDay = _fromDate.year == _toDate.year &&
        _fromDate.month == _toDate.month &&
        _fromDate.day == _toDate.day;

    final String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dm = isSingleDay ? (_mealData[person.userId.toString()]?[dateKey]) : null;

    final bool isSang = isSingleDay ? (dm?.sang ?? false) : _aggregated(person.userId.toString()).sang;
    final String? sangSource = isSingleDay ? dm?.sangSource : null;

    final bool isTrua = isSingleDay ? (dm?.trua ?? false) : _aggregated(person.userId.toString()).trua;
    final String? truaSource = isSingleDay ? dm?.truaSource : null;

    final bool isToi = isSingleDay ? (dm?.toi ?? false) : _aggregated(person.userId.toString()).toi;
    final String? toiSource = isSingleDay ? dm?.toiSource : null;

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
              color: hasMeal
                  ? Colors.green.withValues(alpha: 0.1)
                  : colorScheme.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_rounded,
              size: 18.sp,
              color: hasMeal ? Colors.green : colorScheme.error,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.userFullName,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                if (person.departmentName != null && person.departmentName!.isNotEmpty)
                  Text(
                    person.departmentName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (_selectedSlots.contains('sang'))
            _mealDot(
              'S',
              isSang,
              const Color(0xFFF59E0B),
              theme,
              colorScheme,
              isManual: sangSource == 'manual',
              onTap: () => _toggleCell(person, 'sang'),
            ),
          if (_selectedSlots.contains('trua')) ...[
            SizedBox(width: 4.w),
            _mealDot(
              'Tr',
              isTrua,
              const Color(0xFF0EA5E9),
              theme,
              colorScheme,
              isManual: truaSource == 'manual',
              onTap: () => _toggleCell(person, 'trua'),
            ),
          ],
          if (_selectedSlots.contains('toi')) ...[
            SizedBox(width: 4.w),
            _mealDot(
              'T',
              isToi,
              const Color(0xFF8B5CF6),
              theme,
              colorScheme,
              isManual: toiSource == 'manual',
              onTap: () => _toggleCell(person, 'toi'),
            ),
          ],
          SizedBox(width: 6.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: hasMeal
                  ? Colors.green.withValues(alpha: 0.1)
                  : colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: hasMeal
                    ? Colors.green.withValues(alpha: 0.25)
                    : colorScheme.error.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              '$totalCount',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: hasMeal ? Colors.green : colorScheme.error,
                fontSize: 10.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealDot(
    String label,
    bool active,
    Color color,
    ThemeData theme,
    ColorScheme colorScheme, {
    bool isManual = false,
    VoidCallback? onTap,
  }) {
    final isSingleDay = _fromDate.year == _toDate.year &&
        _fromDate.month == _toDate.month &&
        _fromDate.day == _toDate.day;

    return InkWell(
      onTap: isSingleDay ? onTap : null,
      borderRadius: BorderRadius.circular(6.r),
      child: Container(
        width: 24.w,
        height: 24.w,
        decoration: BoxDecoration(
          color: active
              ? (isManual
                  ? const Color(0xFFFEF3C7)
                  : color.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: active
                ? (isManual
                    ? const Color(0xFFFBBF24)
                    : color.withValues(alpha: 0.4))
                : colorScheme.outlineVariant,
            width: isManual ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 8.sp,
              fontWeight: FontWeight.w800,
              color: active
                  ? (isManual
                      ? const Color(0xFFB45309)
                      : color)
                  : colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          SizedBox(height: 8.h),
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
              SizedBox(width: 4.w),
              Text('Tự động', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.sp)),
              SizedBox(width: 16.w),
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: const Color(0xFFFBBF24)),
                ),
                child: const Center(
                  child: Icon(Icons.check_rounded, color: Color(0xFFB45309), size: 10),
                ),
              ),
              SizedBox(width: 4.w),
              Text('Chấm tay', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10.sp)),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '* Bấm vào các ký hiệu S, Tr, T để thêm/bỏ suất ăn của nhân viên, rồi nhấn Lưu.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class PendingMealChange {
  final int userId;
  final String date;
  final String slot;
  final bool isAllowance;

  PendingMealChange({
    required this.userId,
    required this.date,
    required this.slot,
    required this.isAllowance,
  });
}
