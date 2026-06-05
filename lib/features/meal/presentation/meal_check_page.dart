import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:url_launcher/url_launcher.dart';

import 'package:nguyenanh/core/utils/number_utils.dart';
import 'package:nguyenanh/features/meal/data/models/meal_model.dart';
import 'package:nguyenanh/features/meal/data/services/meal_service.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class MealCheckPage extends StatefulWidget {
  const MealCheckPage({super.key});

  @override
  State<MealCheckPage> createState() => _MealCheckPageState();
}

class _MealCheckPageState extends State<MealCheckPage> {
  final MealService _mealService = MealService();

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;
  bool _checked = false;
  String? _error;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  bool _isSyncing = false;
  String? _sheetUrl;

  List<Personnel> _personnel = [];
  MealDataMap _mealData = {};
  Map<String, List<String>> _plateToNames = {};

  final Set<String> _selectedSlots = {'sang', 'trua', 'toi'};
  final Set<String> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
  }

  Future<void> _runCheck() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _progressCurrent = 0;
      _progressTotal = 0;
      _mealData = {};
    });

    try {
      // 1. Fetch prerequisites in parallel
      final results = await Future.wait([
        _mealService.fetchPersonnel(),
        _mealService.fetchPlateToNames(),
      ]);

      final personnel = results[0] as List<Personnel>;
      final plateToNames = results[1] as Map<String, List<String>>;

      if (!mounted) return;
      setState(() {
        _personnel = personnel;
        _plateToNames = plateToNames;
        _checked = true;
      });

      // 2. Progressive fetch — UI updates on each meal found
      final activeSlots =
          mealSlots.where((s) => _selectedSlots.contains(s.key)).toList();

      await _mealService.checkMeals(
        fromDate: _fromDate,
        toDate: _toDate,
        slots: activeSlots,
        personnel: personnel,
        plateToNames: plateToNames,
        mealData: _mealData,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
            });
          }
        },
        onDataUpdate: () {
          if (mounted) setState(() {});
        },
        onError: (error) {
          debugPrint('[MEAL] Error: $error');
          if (mounted) {
            setState(() => _error = error);
          }
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  // ──────────── Aggregation helpers ────────────

  /// Aggregate all days into a single DayMeals per person
  DayMeals _aggregated(String name) {
    final perDay = _mealData[name];
    if (perDay == null || perDay.isEmpty) return DayMeals();
    final agg = DayMeals();
    for (final dm in perDay.values) {
      if (dm.sang) agg.sang = true;
      if (dm.trua) agg.trua = true;
      if (dm.toi) agg.toi = true;
    }
    return agg;
  }

  /// Total meal count for a person across all days
  int _personTotal(String name) {
    final perDay = _mealData[name];
    if (perDay == null) return 0;
    int t = 0;
    for (final dm in perDay.values) {
      t += dm.total;
    }
    return t;
  }

  int get _totalMeals {
    int total = 0;
    for (final name in _mealData.keys) {
      total += _personTotal(name);
    }
    return total;
  }

  List<({NhomConfig config, List<Personnel> members})> get _groupedPersonnel {
    final groups = nhomConfigs
        .map((cfg) => (config: cfg, members: <Personnel>[]))
        .toList();

    for (final p in _personnel) {
      bool placed = false;
      for (final g in groups) {
        if (g.config.boPhanMatch.any((m) => p.boPhan.contains(m))) {
          g.members.add(p);
          placed = true;
          break;
        }
      }
      if (!placed) {
        groups.last.members.add(p);
      }
    }

    return groups.where((g) => g.members.isNotEmpty).toList();
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
        drawText(canvas, g.config.key, 0, y, colSTT, sectionH,
            fontSize: 11, bold: true, color: const Color(0xFFB45309));
        canvas.drawRect(Rect.fromLTWH(colSTT, y, tableWidth - colSTT, sectionH), borderPaint);
        drawText(canvas, g.config.ten, colSTT, y, colName, sectionH,
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
            final dm = _mealData[member.hoTen]?[dateKey];

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
        'stt': g.config.key,
        'hoTen': g.config.ten,
        'licensePlate': '',
        'meals': {},
        'total': 0,
        'isSection': true,
        'sectionName': g.config.ten,
      });
      
      for (final member in g.members) {
        int personTotal = 0;
        final personMeals = <String, dynamic>{};
        
        for (final day in days) {
          final dateKey = DateFormat('yyyy-MM-dd').format(day);
          final dateStr = DateFormat('dd').format(day);
          final dm = _mealData[member.hoTen]?[dateKey];
          
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
        
        String plate = '';
        for (final entry in _plateToNames.entries) {
          if (entry.value.contains(member.hoTen)) {
            plate = entry.key;
            break;
          }
        }
        
        flatRows.add({
          'stt': stt++,
          'hoTen': member.hoTen,
          'licensePlate': plate,
          'meals': personMeals,
          'total': personTotal,
          'isSection': false,
        });
      }
    }
    
    return flatRows;
  }

  Future<void> _syncSheet() async {
    if (!_checked || _personnel.isEmpty) return;
    
    setState(() => _isSyncing = true);
    try {
      final days = <DateTime>[];
      var d = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
      final end = DateTime(_toDate.year, _toDate.month, _toDate.day);
      while (!d.isAfter(end)) {
        days.add(d);
        d = d.add(const Duration(days: 1));
      }
      
      final daysStr = days.map((day) => DateFormat('dd').format(day)).toList();
      final dateRangeStr = [
        DateFormat('dd/MM/yyyy').format(_fromDate),
        DateFormat('dd/MM/yyyy').format(_toDate)
      ];
      
      final flatRows = _buildFlatRows();
      final grandTotal = _totalMeals;
      
      final payload = {
        'flatRows': flatRows,
        'days': daysStr,
        'dateRange': dateRangeStr,
        'grandTotal': grandTotal,
        'grandTotalText': numberToVietnamese(grandTotal),
      };
      
      final res = await _mealService.syncSheet(payload);
      if (res != null && res['sheetUrl'] != null) {
        setState(() => _sheetUrl = res['sheetUrl']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đồng bộ thành công (${res['rowCount']} dòng)')),
          );
        }
      }
    } catch (e) {
      debugPrint('[MEAL] Sync error: $e');
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
    try {
      String? url = _sheetUrl;
      if (url == null) {
        url = await _mealService.getSheetUrl();
        if (url != null && mounted) {
          setState(() => _sheetUrl = url);
        }
      }
      
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể mở URL')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa có link sheet. Hãy đồng bộ trước.')),
          );
        }
      }
    } catch (e) {
      debugPrint('[MEAL] Open sheet error: $e');
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

  // ──────────── Build ────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat('dd/MM');
    final isSameDay = DateFormat('yyyy-MM-dd').format(_fromDate) ==
        DateFormat('yyyy-MM-dd').format(_toDate);
    final isToday = isSameDay &&
        DateFormat('yyyy-MM-dd').format(_fromDate) ==
            DateFormat('yyyy-MM-dd').format(DateTime.now());

    String dateLabel;
    if (isToday) {
      dateLabel = 'Nhập ngày chấm cơm';
    } else if (isSameDay) {
      dateLabel = dateFmt.format(_fromDate);
    } else {
      dateLabel = '${dateFmt.format(_fromDate)} - ${dateFmt.format(_toDate)}';
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.mealCheck,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.menu_rounded, color: colorScheme.primary),
            tooltip: 'Thao tác',
            onSelected: (value) {
              if (value == 'excel') _exportExcel();
              if (value == 'image') _shareImage();
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
      body: _buildBody(theme, colorScheme, l10n, dateLabel),
    );
  }

  Widget _buildBody(
      ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n, String dateLabel) {
    return CustomScrollView(
      slivers: [
        // ── Controls: date picker, slot chips, check button ──
        SliverToBoxAdapter(
          child: _buildControls(theme, colorScheme, l10n, dateLabel),
        ),
        // ── Progress bar while loading ──
        if (_isLoading && _progressTotal > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
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
        // ── Loading spinner (first time) ──
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
        // ── Error ──
        if (_error != null && !_checked)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 18.sp,
                      color: colorScheme.error.withValues(alpha: 0.7)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // ── Not checked yet ──
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
        // ── Results ──
        if (_checked && _personnel.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _buildSummary(theme, colorScheme, l10n),
          ),
          ...(_groupedPersonnel.expand((g) => [
                SliverToBoxAdapter(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (_expandedGroups.contains(g.config.key)) {
                          _expandedGroups.remove(g.config.key);
                        } else {
                          _expandedGroups.add(g.config.key);
                        }
                      });
                    },
                    child: _buildGroupHeader(
                        g.config, g.members, theme, colorScheme, _expandedGroups.contains(g.config.key)),
                  ),
                ),
                if (_expandedGroups.contains(g.config.key))
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPersonItem(
                          g.members[index], theme, colorScheme),
                      childCount: g.members.length,
                    ),
                  ),
              ])),
          SliverToBoxAdapter(child: SizedBox(height: 16.h)),
        ],
        if (_checked && _personnel.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                l10n.mealCheckNoData,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControls(
      ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n, String dateLabel) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date picker row
          FilledButton.tonal(
            onPressed: _isLoading ? null : _pickDateRange,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.date_range_rounded, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  dateLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          // Slot chips
          Row(
            children: mealSlots.map((slot) {
              final selected = _selectedSlots.contains(slot.key);
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: FilterChip(
                  label: Text(slot.label),
                  selected: selected,
                  onSelected: _isLoading
                      ? null
                      : (val) {
                          setState(() {
                            if (val) {
                              _selectedSlots.add(slot.key);
                            } else {
                              _selectedSlots.remove(slot.key);
                            }
                          });
                        },
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.onPrimaryContainer,
                  labelStyle: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 8.h),
          // Check button
          FilledButton.icon(
            onPressed: _isLoading ? null : _runCheck,
            icon: _isLoading
                ? SizedBox(
                    width: 16.sp,
                    height: 16.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(_isLoading ? l10n.mealChecking : l10n.mealCheckBtn),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12.h),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(
      ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    int sangCount = 0, truaCount = 0, toiCount = 0;
    for (final perDay in _mealData.values) {
      for (final dm in perDay.values) {
        if (dm.sang) sangCount++;
        if (dm.trua) truaCount++;
        if (dm.toi) toiCount++;
      }
    }

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
            label: l10n.mealCheckTotal,
            value: '$_totalMeals',
            color: colorScheme.primary,
            theme: theme,
            colorScheme: colorScheme,
          ),
          SizedBox(width: 8.w),
          _summaryChip(
            label: l10n.mealCheckMorning,
            value: '$sangCount',
            color: const Color(0xFFF59E0B),
            theme: theme,
            colorScheme: colorScheme,
          ),
          SizedBox(width: 8.w),
          _summaryChip(
            label: l10n.mealCheckLunch,
            value: '$truaCount',
            color: const Color(0xFF0EA5E9),
            theme: theme,
            colorScheme: colorScheme,
          ),
          SizedBox(width: 8.w),
          _summaryChip(
            label: l10n.mealCheckDinner,
            value: '$toiCount',
            color: const Color(0xFF8B5CF6),
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
    'A': Color(0xFF6366F1),
    'B': Color(0xFF0EA5E9),
    'C': Color(0xFF8B5CF6),
    'D': Color(0xFFF97316),
    'E': Color(0xFF14B8A6),
    'F': Color(0xFFEC4899),
  };

  static const _groupIcons = <String, IconData>{
    'A': Icons.admin_panel_settings_rounded,
    'B': Icons.business_rounded,
    'C': Icons.precision_manufacturing_rounded,
    'D': Icons.science_rounded,
    'E': Icons.local_shipping_rounded,
    'F': Icons.plumbing_rounded,
  };

  Widget _buildGroupHeader(NhomConfig config, List<Personnel> members,
      ThemeData theme, ColorScheme colorScheme, bool isExpanded) {
    final color = _groupColors[config.key] ?? colorScheme.primary;
    final icon = _groupIcons[config.key] ?? Icons.group_rounded;

    int groupMeals = 0;
    for (final m in members) {
      groupMeals += _personTotal(m.hoTen);
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
                  config.key.isNotEmpty
                      ? '${config.key}. ${config.ten}'
                      : config.ten,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${members.length} người · $groupMeals suất',
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
              '$groupMeals',
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

  Widget _buildPersonItem(
      Personnel person, ThemeData theme, ColorScheme colorScheme) {
    final totalCount = _personTotal(person.hoTen);
    final hasMeal = totalCount > 0;
    final agg = _aggregated(person.hoTen);

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
                  person.hoTen,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                if (person.boPhan.isNotEmpty)
                  Text(
                    person.boPhan,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Meal slot indicators (aggregated across days)
          if (_selectedSlots.contains('sang'))
            _mealDot(
                'S', agg.sang, const Color(0xFFF59E0B), theme, colorScheme),
          if (_selectedSlots.contains('trua')) ...[
            SizedBox(width: 4.w),
            _mealDot(
                'T', agg.trua, const Color(0xFF0EA5E9), theme, colorScheme),
          ],
          if (_selectedSlots.contains('toi')) ...[
            SizedBox(width: 4.w),
            _mealDot(
                'To', agg.toi, const Color(0xFF8B5CF6), theme, colorScheme),
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

  Widget _mealDot(String label, bool active, Color color, ThemeData theme,
      ColorScheme colorScheme) {
    return Container(
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.4)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 8.sp,
            fontWeight: FontWeight.w800,
            color: active ? color : colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }


}
