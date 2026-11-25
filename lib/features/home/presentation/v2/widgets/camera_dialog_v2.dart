import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/home/presentation/widgets/camera_dialog.dart'
    show CameraFeedConfig, CameraSnapshotService, getStationCameras;
import 'package:nguyenanh/features/stations/data/models/station_model.dart';

/// Station camera dialog (v2). Same camera list per station ([getStationCameras]) and the same snapshot
/// fetch ([CameraSnapshotService], digest/basic auth, HTTP then HTTPS) as [CameraDialog]; new presentation.
class CameraDialogV2 extends StatelessWidget {
  final Station station;

  const CameraDialogV2({super.key, required this.station});

  static void show(BuildContext context, Station station) {
    showDialog(
      context: context,
      builder: (_) => CameraDialogV2(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final activeCameras = getStationCameras(station);
    final hasIp = station.stationIpAddress != null && station.stationIpAddress!.isNotEmpty;

    return Dialog(
      backgroundColor: t.card,
      insetPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 10.w, 14.h),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
              child: Row(
                children: [
                  const FxIconBadge(icon: Icons.videocam_rounded, tone: FxTokens.blue, size: 42),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CAMERA GIÁM SÁT', style: t.overline),
                        SizedBox(height: 2.h),
                        Text(
                          station.stationName,
                          style: t.h1.copyWith(fontSize: 18.sp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          hasIp
                              ? 'IP: ${station.stationIpAddress}${activeCameras.length == 1 ? ' | Port: ${activeCameras[0].port}' : ''}'
                              : 'Chưa cấu hình IP',
                          style: t.small.copyWith(fontFeatures: FxTokens.tabular),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  if (activeCameras.length > 1) ...[
                    FxPill(label: '${activeCameras.length} camera', tone: FxTokens.blue),
                    SizedBox(width: 4.w),
                  ],
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: t.text, size: 20.sp),
                    style: IconButton.styleFrom(backgroundColor: t.cardAlt, side: BorderSide(color: t.border)),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 14.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < activeCameras.length; i++) ...[
                      if (i > 0) SizedBox(height: 12.h),
                      CameraFrameWidgetV2(station: station, config: activeCameras[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status ─────────────────────────────────────────────────────────────────

enum _CamStatus { live, connecting, error, unconfigured }

_CamStatus _statusOf({required bool hasConfig, required bool fetching, required bool error, required bool hasFrame}) {
  if (!hasConfig) return _CamStatus.unconfigured;
  if (fetching) return _CamStatus.connecting;
  if (error) return _CamStatus.error;
  if (hasFrame) return _CamStatus.live;
  return _CamStatus.connecting;
}

({String label, Color color}) _statusStyle(_CamStatus s) {
  switch (s) {
    case _CamStatus.live:
      return (label: 'Đã kết nối', color: const Color(0xFF22C55E));
    case _CamStatus.connecting:
      return (label: 'Đang kết nối', color: const Color(0xFFF59E0B));
    case _CamStatus.error:
      return (label: 'Mất kết nối', color: const Color(0xFFEF4444));
    case _CamStatus.unconfigured:
      return (label: 'Chưa cấu hình', color: const Color(0xFF94A3B8));
  }
}

/// Status pill drawn over the (always dark) media frame.
class _MediaStatusPill extends StatelessWidget {
  final _CamStatus status;
  const _MediaStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: s.color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == _CamStatus.connecting)
            SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.6, color: s.color))
          else
            Container(width: 7, height: 7, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
          SizedBox(width: 6.w),
          Text(s.label, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

/// Small dark chip over the media frame (address, capture time).
class _MediaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MediaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: Colors.white70),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular),
          ),
        ],
      ),
    );
  }
}

const _mediaBg = Color(0xFF020617);

/// Centered message on the dark media frame.
Widget _mediaMessage({required IconData icon, required String title, String? detail, double iconSize = 40}) {
  return Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white38, size: iconSize.sp),
          SizedBox(height: 8.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
          if (detail != null && detail.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              detail,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: const Color(0xFFFCA5A5), fontSize: 11.sp),
            ),
          ],
        ],
      ),
    ),
  );
}

// ─── Frame ──────────────────────────────────────────────────────────────────

class CameraFrameWidgetV2 extends StatefulWidget {
  final Station station;
  final CameraFeedConfig config;

  const CameraFrameWidgetV2({
    super.key,
    required this.station,
    required this.config,
  });

  @override
  State<CameraFrameWidgetV2> createState() => _CameraFrameWidgetV2State();
}

class _CameraFrameWidgetV2State extends State<CameraFrameWidgetV2> {
  bool _isDisposed = false;
  Uint8List? _currentFrame;
  bool _isError = false;
  String _errorMessage = '';
  bool _isLoading = true;
  bool _isFetching = false;

  // presentation only
  DateTime? _capturedAt;

  // ── Logic (identical to v1) ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchFrame();
  }

  Future<void> _fetchFrame() async {
    final ip = widget.config.overrideIp ?? widget.station.stationIpAddress;
    final port = widget.config.port;

    if (ip == null || ip.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isFetching = true;
        _isError = false;
        _errorMessage = '';
      });
    }

    try {
      final bytes = await CameraSnapshotService.fetchCameraSnapshot(ip, port);
      if (!_isDisposed && mounted) {
        if (bytes != null) {
          setState(() {
            _currentFrame = bytes;
            _isLoading = false;
            _isError = false;
            _capturedAt = DateTime.now();
          });
        } else {
          setState(() {
            _isError = true;
            _errorMessage = 'Dữ liệu ảnh rỗng';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _openFullScreen() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullScreenCameraPageV2(
        station: widget.station,
        config: widget.config,
      ),
    ));
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final ip = widget.config.overrideIp ?? widget.station.stationIpAddress;
    final port = widget.config.port;
    final bool hasConfig = ip != null && ip.isNotEmpty;
    final status = _statusOf(hasConfig: hasConfig, fetching: _isFetching, error: _isError, hasFrame: _currentFrame != null);

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 8.h),
            child: Row(
              children: [
                Icon(Icons.videocam_outlined, size: 16.sp, color: t.textMuted),
                SizedBox(width: 6.w),
                Expanded(child: Text(widget.config.name, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (hasConfig) Text('$ip:$port', style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: _mediaBg,
                child: !hasConfig
                    ? _mediaMessage(
                        icon: Icons.settings_input_antenna_rounded,
                        title: 'Vui lòng cấu hình IP và Port cho camera của trạm này trong phần quản lý trạm.',
                        iconSize: 32,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_currentFrame != null)
                            Image.memory(
                              _currentFrame!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          if (_isLoading && _currentFrame == null)
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70),
                                  ),
                                  SizedBox(height: 10.h),
                                  Text('Đang kết nối camera…', style: TextStyle(color: Colors.white60, fontSize: 12.sp)),
                                ],
                              ),
                            ),
                          if (_isError && _currentFrame == null)
                            _mediaMessage(icon: Icons.videocam_off_rounded, title: 'Mất kết nối Camera', detail: _errorMessage),
                          if (_isFetching && _currentFrame != null)
                            const Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              child: LinearProgressIndicator(minHeight: 2, color: Colors.white70, backgroundColor: Colors.transparent),
                            ),
                          Positioned(top: 8.h, left: 8.w, child: _MediaStatusPill(status: status)),
                          if (_currentFrame != null && _capturedAt != null)
                            Positioned(
                              bottom: 8.h,
                              left: 8.w,
                              child: _MediaChip(icon: Icons.schedule_rounded, text: DateFormat('HH:mm:ss').format(_capturedAt!)),
                            ),
                        ],
                      ),
              ),
            ),
          ),
          if (hasConfig) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isFetching ? null : _fetchFrame,
                    icon: _isFetching
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.refresh_rounded, size: 18.sp),
                    label: Text(_isFetching ? 'Đang tải...' : 'Làm mới'),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _currentFrame != null ? _openFullScreen : null,
                    icon: Icon(Icons.fullscreen_rounded, size: 18.sp),
                    label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Toàn màn hình', maxLines: 1)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Full screen ────────────────────────────────────────────────────────────

class FullScreenCameraPageV2 extends StatefulWidget {
  final Station station;
  final CameraFeedConfig config;

  const FullScreenCameraPageV2({
    super.key,
    required this.station,
    required this.config,
  });

  @override
  State<FullScreenCameraPageV2> createState() => _FullScreenCameraPageV2State();
}

class _FullScreenCameraPageV2State extends State<FullScreenCameraPageV2> {
  bool _isDisposed = false;
  Uint8List? _currentFrame;
  bool _isError = false;
  String _errorMessage = '';
  bool _isLoading = true;
  bool _isFetching = false;

  // presentation only
  DateTime? _capturedAt;

  // ── Logic (identical to v1) ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchFrame();
  }

  Future<void> _fetchFrame() async {
    final ip = widget.config.overrideIp ?? widget.station.stationIpAddress;
    final port = widget.config.port;

    if (ip == null || ip.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isFetching = true;
        _isError = false;
        _errorMessage = '';
      });
    }

    try {
      final bytes = await CameraSnapshotService.fetchCameraSnapshot(ip, port);
      if (!_isDisposed && mounted) {
        if (bytes != null) {
          setState(() {
            _currentFrame = bytes;
            _isLoading = false;
            _isError = false;
            _capturedAt = DateTime.now();
          });
        } else {
          setState(() {
            _isError = true;
            _errorMessage = 'Dữ liệu ảnh rỗng';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ip = widget.config.overrideIp ?? widget.station.stationIpAddress;
    final hasConfig = ip != null && ip.isNotEmpty;
    final status = _statusOf(hasConfig: hasConfig, fetching: _isFetching, error: _isError, hasFrame: _currentFrame != null);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.config.name,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              widget.station.stationName,
              style: TextStyle(color: Colors.white60, fontSize: 11.5.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Center(child: _MediaStatusPill(status: status)),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _isFetching ? null : _fetchFrame,
            icon: _isFetching
                ? SizedBox(width: 18.sp, height: 18.sp, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: Center(
                child: !hasConfig
                    ? Center(
                        child: Text(
                          'Chưa cấu hình IP Camera',
                          style: TextStyle(color: Colors.white54, fontSize: 16.sp),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_currentFrame != null)
                            Image.memory(
                              _currentFrame!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          if (_isLoading && _currentFrame == null)
                            const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.4)),
                          if (_isError && _currentFrame == null)
                            _mediaMessage(icon: Icons.videocam_off_rounded, title: 'Mất kết nối Camera', detail: _errorMessage, iconSize: 56),
                        ],
                      ),
              ),
            ),
            if (_currentFrame != null && _capturedAt != null)
              Positioned(
                left: 12.w,
                bottom: 12.h,
                child: _MediaChip(icon: Icons.schedule_rounded, text: 'Ảnh lúc ${DateFormat('HH:mm:ss').format(_capturedAt!)}'),
              ),
            if (_currentFrame != null)
              Positioned(
                right: 12.w,
                bottom: 12.h,
                child: IgnorePointer(
                  child: _MediaChip(icon: Icons.pinch_rounded, text: 'Chụm để phóng to'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
