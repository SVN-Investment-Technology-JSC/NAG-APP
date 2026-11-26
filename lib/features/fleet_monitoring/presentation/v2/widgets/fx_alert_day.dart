import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_reads.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';

/// Which alerts a list shows: the open ones right now (overview), or every alert of one day.
/// [day] null = "Đang mở" (live overview alerts).
class FleetAlertDay extends ChangeNotifier {
  final FleetPermissions perms;
  FleetAlertDay(this.perms);

  final _api = FleetMonitoringService();
  DateTime? day;
  List<FleetAlert> alerts = const [];
  bool loading = false;
  String? error;
  int _seq = 0;

  bool get live => day == null;

  /// The fuel / concrete events list needs that page's permission: an overview-only role sees the live
  /// alerts but not a past day of that category.
  bool get canFuel => perms.fuel;
  bool get canConcrete => perms.concrete;
  bool get canPickDay => canFuel || canConcrete;

  /// Categories the user sees live but cannot list per day (no fuel/concrete page permission).
  List<String> get hiddenByPermission => [
        if (!canFuel && perms.overview) 'Nhiên liệu',
        if (!canConcrete && perms.overview) 'Bê tông thừa',
      ];

  Future<void> setDay(DateTime? d) async {
    day = d == null ? null : DateTime(d.year, d.month, d.day);
    alerts = const [];
    error = null;
    notifyListeners();
    if (day != null) await load();
  }

  Future<void> load() async {
    final d = day;
    if (d == null) return;
    final seq = ++_seq;
    loading = true;
    notifyListeners();
    try {
      final r = await _api.dayAlerts(d, fuel: canFuel, concrete: canConcrete);
      if (seq != _seq) return;
      alerts = r.alerts;
      FleetReads.instance.lookup(alerts.map((a) => a.id));
      error = r.failed.isEmpty
          ? null
          : 'Không tải được ${r.failed.map((c) => c == 'fuel' ? 'tụt dầu' : 'bê tông thừa').join(' và ')} của ngày này';
    } catch (_) {
      if (seq != _seq) return;
      error = 'Không tải được cảnh báo của ngày này';
    } finally {
      if (seq == _seq) {
        loading = false;
        notifyListeners();
      }
    }
  }

  String get subtitle {
    if (live) return 'Tụt dầu 7 ngày chưa xử lý · bê tông cần kiểm tra hôm nay';
    return 'Tất cả cảnh báo ngày ${DateFormat('dd/MM/yyyy').format(day!)} · gồm cả đã xử lý';
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Đang mở | Hôm nay | Hôm qua | Chọn ngày" — picks what [FleetAlertDay] shows.
class FxAlertDayBar extends StatelessWidget {
  final FleetAlertDay ctl;
  const FxAlertDayBar({super.key, required this.ctl});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDate: ctl.day ?? now,
      helpText: 'Xem cảnh báo theo ngày',
    );
    if (d != null) ctl.setDay(d);
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    if (!ctl.canPickDay) return const SizedBox.shrink();
    final now = DateTime.now();
    final yday = now.subtract(const Duration(days: 1));
    final d = ctl.day;
    final key = d == null
        ? 'live'
        : _sameDay(d, now)
            ? 'today'
            : _sameDay(d, yday)
                ? 'yday'
                : 'other';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxSegmented<String>(
          dense: true,
          segments: [
            const FxSegment('live', 'Đang mở'),
            const FxSegment('today', 'Hôm nay'),
            const FxSegment('yday', 'Hôm qua'),
            FxSegment('other', key == 'other' ? DateFormat('dd/MM').format(d!) : 'Chọn ngày', icon: Icons.event_rounded),
          ],
          value: key,
          onChanged: (v) {
            switch (v) {
              case 'live':
                ctl.setDay(null);
              case 'today':
                ctl.setDay(now);
              case 'yday':
                ctl.setDay(yday);
              default:
                _pick(context);
            }
          },
        ),
        if (!ctl.live && ctl.hiddenByPermission.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text('Xem theo ngày cần quyền ${ctl.hiddenByPermission.join(' / ')} — phần đó không hiện ở đây.',
                style: t.tiny.copyWith(color: t.ink(FxTokens.amber))),
          ),
      ],
    );
  }
}

/// "Đã xử lý" pill for handled alerts of a past day.
class FxReviewedPill extends StatelessWidget {
  const FxReviewedPill({super.key});
  @override
  Widget build(BuildContext context) => const FxPill(label: 'Đã xử lý', tone: FxTokens.emerald, icon: Icons.check_rounded);
}
