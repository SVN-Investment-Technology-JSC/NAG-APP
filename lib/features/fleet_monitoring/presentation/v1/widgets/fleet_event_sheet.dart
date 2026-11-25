import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_video_player.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_common.dart';

/// Detail of one fuel / concrete event (port of FleetEventDialog.tsx). Opens as a bottom sheet.
Future<void> showFleetEventSheet(
  BuildContext context, {
  required String eventId,
  required String category, // fuel | concrete
  bool cameraAllowed = false,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, scroll) => _FleetEventBody(
        eventId: eventId,
        category: category,
        cameraAllowed: cameraAllowed,
        onChanged: onChanged,
        scroll: scroll,
      ),
    ),
  );
}

class _FleetEventBody extends StatefulWidget {
  final String eventId;
  final String category;
  final bool cameraAllowed;
  final VoidCallback? onChanged;
  final ScrollController scroll;

  const _FleetEventBody({
    required this.eventId,
    required this.category,
    required this.cameraAllowed,
    required this.onChanged,
    required this.scroll,
  });

  @override
  State<_FleetEventBody> createState() => _FleetEventBodyState();
}

class _FleetEventBodyState extends State<_FleetEventBody> {
  final _api = FleetMonitoringService();
  FleetEvent? _ev;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = widget.category == 'fuel' ? await _api.fuelEvent(widget.eventId) : await _api.concreteEvent(widget.eventId);
      if (!mounted) return;
      setState(() {
        _ev = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được sự kiện';
        _loading = false;
      });
    }
  }

  Future<void> _askCamera(String kind) async {
    final ev = _ev;
    if (ev == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.cameraJob(ev.id, kind);
      messenger.showSnackBar(SnackBar(
        content: Text(kind == 'clip'
            ? 'Đã yêu cầu video — video ghi lại cần thời gian bằng độ dài đoạn quay'
            : 'Đã yêu cầu ảnh từ camera'),
      ));
      widget.onChanged?.call();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _load();
      });
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Không gửi được yêu cầu camera')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _ev == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final ev = _ev;
    if (ev == null) {
      return Center(child: FleetEmpty(_error ?? 'Không có dữ liệu', icon: Icons.error_outline_rounded));
    }
    final cs = Theme.of(context).colorScheme;
    final evd = ev.evidence;
    final risk = ev.risk;
    final tone = risk != null ? riskOf(risk.level) : severityOf(ev.severity);
    final title = risk != null
        ? (risk.level == 'delivery'
            ? 'Điểm giao của chuyến'
            : risk.level == 'check'
                ? 'Lần dừng cần kiểm tra'
                : 'Lần dừng bình thường')
        : ev.title;
    final images = ev.media.where((m) => m.contentType.startsWith('image/')).toList();
    final videos = ev.media.where((m) => m.contentType.startsWith('video/')).toList();
    final pending = ev.cameraJobStatuses.any((s) => s == 'pending' || s == 'running');

    num? n(String k) => evd[k] is num ? evd[k] as num : null;

    Widget? discharge;
    if (evd['discharge_signature'] != null) {
      final yes = evd['discharge_signature'] == true;
      final c = yes ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
      discharge = Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10.r)),
        child: Text(
          yes
              ? 'Đứng yên với vòng tua ≥ ${fmtNum(n('discharge_rpm'), 0)} rpm trong ${fmtDur(n('rpm_high_s'))} — dấu hiệu bồn quay nhanh để xả.'
              : 'Vòng tua không vượt ${fmtNum(n('discharge_rpm'), 0)} rpm khi đứng yên — không có dấu hiệu xả.',
          style: TextStyle(fontSize: 12.sp, color: c),
        ),
      );
    }

    final facts = <(IconData, String, String)>[
      (Icons.schedule_rounded, 'Thời gian', '${fmtTime(ev.startedAt, withDate: true)} → ${fmtTime(ev.endedAt)}'),
      (Icons.timer_outlined, 'Thời lượng', fmtDur(ev.durationS)),
      if (widget.category == 'fuel')
        (
          Icons.speed_rounded,
          'Mức tụt',
          n('delta_pct') != null
              ? '${fmtNum(n('delta_pct'), 1)}%${n('drop_l') != null ? ' ≈ ${fmtNum(n('drop_l'), 0)} L' : ' (chưa có dung tích bình)'}'
              : '—'
        )
      else
        (Icons.speed_rounded, 'Vòng tua tối đa', n('rpm_max') != null ? '${fmtNum(n('rpm_max'), 0)} rpm' : 'Xe không gửi RPM'),
      if (widget.category == 'concrete')
        (
          Icons.power_settings_new_rounded,
          'Máy',
          ev.engineOn == true
              ? 'Nổ máy'
              : ev.engineOn == false
                  ? 'Tắt máy'
                  : 'Chưa rõ'
        ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: widget.scroll,
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
        children: [
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ToneChip(label: tone.label, color: tone.color),
              if (ev.status == 'reviewed') ToneChip(label: 'Đã duyệt: ${reviewLabel(ev.reviewLabel)}', color: cs.primary),
            ],
          ),
          SizedBox(height: 8.h),
          Text(title, style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w900)),
          SizedBox(height: 2.h),
          Text('${ev.vehicleCode} · ${ev.vehiclePlate}  ·  ${ev.code}', style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 12.h),
          FleetSection(
            child: Column(
              children: [
                for (final f in facts)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      children: [
                        Icon(f.$1, size: 16.sp, color: cs.outline),
                        SizedBox(width: 8.w),
                        SizedBox(width: 110.w, child: Text(f.$2, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant))),
                        Expanded(child: Text(f.$3, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                if (ev.address != null && ev.address!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined, size: 16.sp, color: cs.outline),
                        SizedBox(width: 8.w),
                        Expanded(child: Text(ev.address!, style: TextStyle(fontSize: 12.sp))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (ev.lat != null && ev.lon != null) _EventMap(lat: ev.lat!, lon: ev.lon!, color: tone.color),
          FleetSection(
            title: risk != null ? 'Đánh giá' : 'Vì sao hệ thống đánh dấu',
            trailing: risk?.position != null ? Text(risk!.position!, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(risk != null ? (risk.reason ?? risk.note ?? '') : ev.reason, style: TextStyle(fontSize: 13.sp, height: 1.4)),
                if (discharge != null) discharge,
              ],
            ),
          ),
          FleetSection(
            title: 'Ảnh & video camera',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.cameraAllowed && widget.category == 'concrete' && ev.cameraCount > 0)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _askCamera('snapshot'),
                          icon: const Icon(Icons.photo_camera_outlined, size: 16),
                          label: const Text('Chụp ảnh'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _askCamera('frame'),
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: const Text('Ảnh lúc bắt đầu dừng'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _askCamera('clip'),
                          icon: const Icon(Icons.videocam_outlined, size: 16),
                          label: const Text('Lấy video'),
                        ),
                      ],
                    ),
                  ),
                if (images.isEmpty && videos.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text(
                      ev.cameraCount > 0 ? 'Chưa có ảnh/video cho sự kiện này' : 'Xe chưa gắn camera',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
                    ),
                  ),
                for (final v in videos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline_rounded, size: 32),
                    title: const Text('Mở video'),
                    subtitle: Text('${fmtTime(v.capturedFrom, withDate: true)} → ${fmtTime(v.capturedTo)}'),
                    onTap: () => openFleetVideo(context, FleetMonitoringService.mediaUrl(v.url),
                        title: 'Video camera ${ev.vehicleCode}', subtitle: '${fmtTime(v.capturedFrom, withDate: true)} → ${fmtTime(v.capturedTo)}'),
                  ),
                if (images.isNotEmpty)
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8.h,
                    crossAxisSpacing: 8.w,
                    childAspectRatio: 1.15,
                    children: [
                      for (final m in images)
                        GestureDetector(
                          onTap: () => _openImage(context, FleetMonitoringService.mediaUrl(m.url)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: Image.network(
                                    FleetMonitoringService.mediaUrl(m.url),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: cs.surfaceContainerHigh,
                                      child: const Center(child: Icon(Icons.broken_image_outlined)),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                '${fmtTime(m.capturedFrom, withDate: true)} · ${m.kind == 'frame' ? 'từ bản ghi' : 'trực tiếp'}',
                                style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                if (pending)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Text('Đang chờ camera gửi ảnh/video về… (kéo xuống để tải lại)',
                        style: TextStyle(fontSize: 11.sp, color: const Color(0xFFD97706))),
                  ),
              ],
            ),
          ),
          if (ev.reviews.isNotEmpty)
            FleetSection(
              title: 'Lịch sử duyệt',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in ev.reviews)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(text: reviewLabel(r.label), style: const TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: ' · ${fmtTime(r.ts, withDate: true)}', style: TextStyle(color: cs.onSurfaceVariant)),
                          ])),
                          if (r.note.isNotEmpty) Text(r.note, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.all(8.w),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: Image.network(url, fit: BoxFit.contain))),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMap extends StatelessWidget {
  final double lat;
  final double lon;
  final Color color;
  const _EventMap({required this.lat, required this.lon, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = LatLng(lat, lon);
    return Container(
      height: 200.h,
      margin: EdgeInsets.only(bottom: 12.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16.r)),
      child: FlutterMap(
        options: MapOptions(initialCenter: p, initialZoom: 16),
        children: [
          TileLayer(
            urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
            userAgentPackageName: 'com.nguyenanh.nagapp',
          ),
          MarkerLayer(markers: [
            Marker(
              point: p,
              width: 36,
              height: 36,
              child: Icon(Icons.location_on_rounded, color: color, size: 36),
            ),
          ]),
        ],
      ),
    );
  }
}
