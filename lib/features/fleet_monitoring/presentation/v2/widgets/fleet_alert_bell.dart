import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:nguyenanh/core/push/fleet_push.dart';
import 'package:nguyenanh/core/theme/ui_version_provider.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_reads.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_monitoring_entry.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_event_sheet.dart' as v1;
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_alert_day.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_event_sheet.dart';

/// Open alerts of the fleet overview ("Cảnh báo cần xử lý"), shared by every bell. Reloads every 60 s while
/// someone listens, and right away when a fleet push arrives.
class FleetAlertsStore extends ChangeNotifier {
  FleetAlertsStore._() {
    FleetPush.instance.addListener(_onPush);
  }
  static final FleetAlertsStore instance = FleetAlertsStore._();

  final _api = FleetMonitoringService();
  List<FleetAlert> alerts = const [];
  bool loading = false;
  bool failed = false;
  DateTime? updatedAt;
  Timer? _timer;
  int _listeners = 0;
  int _lastTick = 0;

  void attach() {
    _listeners++;
    if (_listeners == 1) {
      load();
      _timer = Timer.periodic(const Duration(seconds: 60), (_) => load());
    }
  }

  void detach() {
    _listeners = (_listeners - 1).clamp(0, 1 << 20);
    if (_listeners == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _onPush() {
    if (FleetPush.instance.pushTick != _lastTick) {
      _lastTick = FleetPush.instance.pushTick;
      load();
    }
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    notifyListeners();
    try {
      final o = await _api.overview(fuelDays: 7);
      alerts = o.alerts;
      failed = false;
      FleetReads.instance.lookup(alerts.map((a) => a.id));
      updatedAt = DateTime.now();
    } catch (_) {
      failed = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

/// Opens one alert (from the bell or from a tapped push): the fleet screens + the alert detail on top.
void openFleetAlert(BuildContext context, {String? eventId, required String category, FleetPermissions? perms}) {
  final nav = Navigator.of(context);
  final newUi = context.read<UiVersionProvider>().isNewUi;
  nav.push(MaterialPageRoute(builder: (_) => FleetMonitoringEntry(perms: perms)));
  if (eventId == null || eventId.isEmpty) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = nav.context;
    if (!ctx.mounted) return;
    final review = perms?.concreteReview ?? false;
    if (newUi) {
      showFxEventSheet(ctx, eventId: eventId, category: category, cameraAllowed: review);
    } else {
      v1.showFleetEventSheet(ctx, eventId: eventId, category: category, cameraAllowed: review);
    }
  });
}

/// App-bar bell for fleet-monitoring alerts (replaces the old notification bell in the new UI).
/// Only built for users with a fleet-monitoring permission.
class FleetAlertBell extends StatefulWidget {
  final FleetPermissions perms;
  const FleetAlertBell({super.key, required this.perms});

  @override
  State<FleetAlertBell> createState() => _FleetAlertBellState();
}

class _FleetAlertBellState extends State<FleetAlertBell> {
  final _store = FleetAlertsStore.instance;

  @override
  void initState() {
    super.initState();
    _store.attach();
    _store.addListener(_changed);
    FleetReads.instance.addListener(_changed);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    FleetReads.instance.removeListener(_changed);
    _store.detach();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  List<FleetAlert> get _visible => _store.alerts
      .where((a) => a.category == 'fuel' ? (widget.perms.fuel || widget.perms.overview) : (widget.perms.concrete || widget.perms.overview))
      .toList();

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final n = FleetReads.instance.unread(_visible.map((a) => a.id)); // badge = alerts I have not opened yet
    return IconButton(
      tooltip: 'Cảnh báo giám sát xe',
      onPressed: () => _openSheet(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(_visible.isNotEmpty ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: t.text, size: 24.sp),
          if (n > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: FxTokens.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.bg, width: 1.5),
                ),
                child: Text(n > 99 ? '99+' : '$n',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, height: 1.3)),
              ),
            ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final t = FxTokens.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: t.bg,
      builder: (_) => _AlertsSheet(perms: widget.perms, parent: context),
    );
  }
}

class _AlertsSheet extends StatefulWidget {
  final FleetPermissions perms;
  final BuildContext parent;
  const _AlertsSheet({required this.perms, required this.parent});

  @override
  State<_AlertsSheet> createState() => _AlertsSheetState();
}

class _AlertsSheetState extends State<_AlertsSheet> {
  final _store = FleetAlertsStore.instance;
  Map<String, dynamic>? _status;
  bool _testing = false;
  String _filter = 'all';
  late final FleetAlertDay _day = FleetAlertDay(widget.perms)..addListener(_changed);

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
    FleetPush.instance.addListener(_changed);
    FleetReads.instance.addListener(_changed);
    Future.microtask(_store.load); // not during the build that opens the sheet
    FleetPush.instance.status().then((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    FleetPush.instance.removeListener(_changed);
    FleetReads.instance.removeListener(_changed);
    _day.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final messenger = ScaffoldMessenger.of(context);
    if (!FleetPush.instance.registered) await FleetPush.instance.syncForUser(allowed: true);
    final n = await FleetPush.instance.sendTest();
    if (!mounted) return;
    setState(() => _testing = false);
    messenger.showSnackBar(SnackBar(
      content: Text(n == null
          ? 'Không gửi được thông báo thử'
          : n > 0
              ? 'Đã gửi thông báo thử tới $n điện thoại'
              : 'Chưa có điện thoại nào đăng ký nhận thông báo'),
    ));
    FleetPush.instance.status().then((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final live = _day.live;
    final all = (live ? _store.alerts : _day.alerts)
        .where((a) => a.category == 'fuel' ? (widget.perms.fuel || widget.perms.overview) : (widget.perms.concrete || widget.perms.overview))
        .toList();
    final fuel = all.where((a) => a.category == 'fuel').length;
    final concrete = all.length - fuel;
    final shown = _filter == 'all' ? all : all.where((a) => a.category == _filter).toList();
    final unread = FleetReads.instance.unread(shown.map((a) => a.id));
    final pushOn = FleetPush.instance.available && FleetPush.instance.registered && (_status?['fcm_configured'] == true);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 8.w, 8.h),
            child: Row(children: [
              const FxIconBadge(icon: Icons.notifications_active_rounded, tone: FxTokens.red, size: 36),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Cảnh báo giám sát xe', style: t.h1.copyWith(fontSize: 18.sp)),
                  Text(_day.subtitle, style: t.tiny),
                ]),
              ),
              if (unread > 0)
                IconButton(
                  tooltip: 'Đánh dấu đã đọc tất cả ($unread)',
                  onPressed: () => FleetReads.instance.markRead(shown.map((a) => a.id), source: 'all'),
                  icon: Icon(Icons.done_all_rounded, color: t.textMuted),
                ),
              IconButton(
                tooltip: 'Tải lại',
                onPressed: live ? _store.load : _day.load,
                icon: (live ? _store.loading : _day.loading)
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh_rounded, color: t.textMuted),
              ),
            ]),
          ),
          // push status (tạm thời ẩn)
          if (false)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: t.soft(pushOn ? FxTokens.emerald : FxTokens.amber),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(children: [
                Icon(pushOn ? Icons.phonelink_ring_rounded : Icons.notifications_off_outlined,
                    size: 18.sp, color: t.ink(pushOn ? FxTokens.emerald : FxTokens.amber)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    pushOn
                        ? 'Điện thoại này đang nhận thông báo tức thời'
                        : !FleetPush.instance.available
                            ? 'Thông báo đẩy chưa được bật trên bản app này'
                            : (_status?['fcm_configured'] == false
                                ? 'Máy chủ chưa cấu hình Firebase'
                                : 'Chưa đăng ký nhận thông báo trên điện thoại này'),
                    style: TextStyle(fontSize: 12.sp, color: t.ink(pushOn ? FxTokens.emerald : FxTokens.amber), fontWeight: FontWeight.w600),
                  ),
                ),
                if (FleetPush.instance.available)
                  TextButton(
                    onPressed: _testing ? null : _test,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: _testing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Gửi thử'),
                  ),
              ]),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 0),
            child: FxAlertDayBar(ctl: _day),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
            child: FxSegmented<String>(
              dense: true,
              segments: [
                FxSegment('all', 'Tất cả · ${all.length}'),
                if (widget.perms.fuel || widget.perms.overview) FxSegment('fuel', 'Dầu · $fuel'),
                if (widget.perms.concrete || widget.perms.overview) FxSegment('concrete', 'Bê tông · $concrete'),
              ],
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          if (!live && _day.error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
              child: FxBanner(text: _day.error!, tone: FxTokens.red, icon: Icons.cloud_off_rounded),
            ),
          Expanded(
            child: !live && _day.loading && shown.isEmpty
                ? const FxLoadingView()
                : shown.isEmpty
                ? (live && _store.failed
                    ? FxEmpty(
                        icon: Icons.cloud_off_rounded,
                        title: 'Không tải được cảnh báo',
                        action: FilledButton.tonal(onPressed: _store.load, child: const Text('Thử lại')),
                      )
                    : FxEmpty(
                        icon: Icons.verified_outlined,
                        title: 'Không có cảnh báo',
                        message: live ? 'Mọi xe đang hoạt động bình thường.' : 'Ngày này không có tụt dầu hay bê tông cần kiểm tra.'))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _tile(t, shown[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  openFleetAlert(widget.parent, category: 'fuel', perms: widget.perms);
                },
                icon: const Icon(Icons.local_shipping_rounded),
                label: const Text('Mở Giám sát xe'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(FxTokens t, FleetAlert a) {
    final fuel = a.category == 'fuel';
    final tone = a.riskLevel != null ? riskOf(a.riskLevel!) : severityOf(a.severity);
    final head = a.riskLevel != null ? (a.riskReason ?? a.title) : a.title;
    final meta = <String>[fmtTime(a.startedAt, withDate: true)];
    if (fuel && a.deltaPct != null) meta.add('tụt ${fmtNum(a.deltaPct!.abs(), 1)}%${a.dropL != null ? ' ≈ ${fmtNum(a.dropL!.abs(), 0)} L' : ''}');
    if (!fuel) meta.add(fmtDur(a.durationS));
    final read = FleetReads.instance.isRead(a.id);
    final seen = FleetReads.instance.readers(a.id);
    if (seen > 0) meta.add('$seen người đã xem');
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: t.card,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () {
            FleetReads.instance.markRead([a.id], source: 'bell');
            Navigator.of(context).pop();
            openFleetAlert(widget.parent, eventId: a.id, category: a.category, perms: widget.perms);
          },
          child: Container(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 8.w, 10.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border(left: BorderSide(color: tone.color, width: 4)),
            ),
            child: Row(children: [
              FxIconBadge(icon: fuel ? Icons.local_gas_station_rounded : Icons.blender_rounded, tone: fuel ? FxTokens.red : FxTokens.amber, size: 34),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (!read) ...[
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: FxTokens.blue, shape: BoxShape.circle)),
                      SizedBox(width: 6.w),
                    ],
                    Flexible(child: Text(a.vehicleCode, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: 6.w),
                    FxPill(label: fuel ? 'Tụt dầu' : tone.label, tone: tone.color),
                    if (a.reviewed) ...[SizedBox(width: 4.w), const FxReviewedPill()],
                  ]),
                  SizedBox(height: 3.h),
                  Text(head,
                      style: t.small.copyWith(color: t.text, fontWeight: read ? FontWeight.w400 : FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2.h),
                  Text(meta.join(' · '), style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: t.textFaint),
            ]),
          ),
        ),
      ),
    );
  }
}
