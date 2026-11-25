import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/models/parking_idle_engine_models.dart';

/// Shared bits of the v2 "Giám sát nổ máy" screens (dashboard, detail sheet).

// ─── Formatting ─────────────────────────────────────────────────────────────

final Map<int, NumberFormat> _numCache = {};

String pieFmtNum(num? v, [int digits = 1]) {
  if (v == null || v.isNaN || v.isInfinite) return '—';
  final f = _numCache.putIfAbsent(digits, () => NumberFormat('#,##0${digits > 0 ? '.${'#' * digits}' : ''}', 'vi'));
  return f.format(v);
}

/// Same display as the v1 live timer: `H:MM:SS` from one hour, `MM:SS` below.
String pieFmtElapsed(int seconds) {
  final hours = seconds ~/ 3600;
  final mins = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  String pad(int n) => n.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:${pad(mins)}:${pad(secs)}' : '${pad(mins)}:${pad(secs)}';
}

/// "HH:mm dd/MM" of an ISO timestamp, or '—'.
String pieFmtStamp(String? iso, {String pattern = 'HH:mm dd/MM'}) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return '—';
  return DateFormat(pattern).format(d.toLocal());
}

// ─── Axis helpers (same rules as the fleet-monitoring v2 charts) ────────────

/// A "nice" step (1, 2, 2.5, 5 × 10^n) giving about [ticks] intervals over [range].
double pieNiceStep(double range, int ticks) {
  if (range <= 0 || !range.isFinite) return 1;
  final raw = range / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / mag;
  final nf = f <= 1 ? 1.0 : (f <= 2 ? 2.0 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5.0 : 10.0)));
  return nf * mag;
}

/// [lo, hi] widened to multiples of a nice step.
({double lo, double hi, double step}) pieNiceScale(double lo, double hi, {int ticks = 4}) {
  if (hi <= lo) hi = lo + 1;
  final step = pieNiceStep(hi - lo, ticks);
  return (lo: (lo / step).floor() * step, hi: (hi / step).ceil() * step, step: step);
}

bool pieOnStep(double v, double s) {
  final r = (v / s).round() * s;
  return (v - r).abs() < s * 1e-6;
}

// ─── Engine state ───────────────────────────────────────────────────────────

/// Tone of a vehicle: red when warning in yard, amber when the engine is on, slate otherwise.
Color pieToneOf(ParkingIdleEngineAlert a) {
  if (a.warningActive && a.inYard) return FxTokens.red;
  if (a.engineState == 'on') return FxTokens.amber;
  return FxTokens.slate;
}

/// Engine-state pill ('Đang nổ máy' / 'Tắt máy', as v1).
class PieEnginePill extends StatelessWidget {
  final ParkingIdleEngineAlert alert;
  const PieEnginePill({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final on = alert.engineState == 'on';
    return FxPill(
      label: on ? 'Đang nổ máy' : 'Tắt máy',
      tone: on ? (alert.warningActive ? FxTokens.red : FxTokens.amber) : FxTokens.slate,
      icon: Icons.bolt_rounded,
    );
  }
}

/// In-yard pill ('Trong bãi' / 'Ngoài bãi', as v1).
class PieYardPill extends StatelessWidget {
  final bool inYard;
  const PieYardPill({super.key, required this.inYard});

  @override
  Widget build(BuildContext context) {
    return FxPill(
      label: inYard ? 'Trong bãi' : 'Ngoài bãi',
      tone: inYard ? FxTokens.emerald : FxTokens.slate,
      icon: Icons.pin_drop_rounded,
    );
  }
}

/// Warning / watching pill ('Cảnh báo' / 'Theo dõi', as v1).
class PieWarningPill extends StatelessWidget {
  final bool warning;
  const PieWarningPill({super.key, required this.warning});

  @override
  Widget build(BuildContext context) {
    return warning
        ? const FxPill(label: 'Cảnh báo', tone: FxTokens.red, icon: Icons.warning_amber_rounded, solid: true)
        : const FxPill(label: 'Theo dõi', tone: FxTokens.slate, icon: Icons.visibility_outlined);
  }
}

// ─── Live elapsed timer ─────────────────────────────────────────────────────

/// Live elapsed seconds since [idleStartedAt] (ticks every second), falling back to [fallbackMinutes].
/// Same timing logic as the v1 `LiveElapsedTimer`; the look is up to [builder].
class PieLiveElapsed extends StatefulWidget {
  final String? idleStartedAt;
  final double fallbackMinutes;
  final Widget Function(BuildContext context, int elapsedSeconds) builder;

  const PieLiveElapsed({
    super.key,
    required this.idleStartedAt,
    required this.fallbackMinutes,
    required this.builder,
  });

  @override
  State<PieLiveElapsed> createState() => _PieLiveElapsedState();
}

class _PieLiveElapsedState extends State<PieLiveElapsed> {
  late DateTime _startedAt;
  late int _fallbackSeconds;
  late bool _useLive;
  Timer? _timer;
  late int _elapsedSeconds;

  @override
  void initState() {
    super.initState();
    _initTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateElapsed();
        });
      }
    });
  }

  void _initTime() {
    _fallbackSeconds = (widget.fallbackMinutes * 60).round();
    if (widget.idleStartedAt != null && widget.idleStartedAt!.isNotEmpty) {
      try {
        _startedAt = DateTime.parse(widget.idleStartedAt!).toLocal();
        _useLive = true;
      } catch (_) {
        _useLive = false;
      }
    } else {
      _useLive = false;
    }
    _updateElapsed();
  }

  void _updateElapsed() {
    if (_useLive) {
      _elapsedSeconds = DateTime.now().difference(_startedAt).inSeconds;
      if (_elapsedSeconds < 0) _elapsedSeconds = 0;
    } else {
      _elapsedSeconds = _fallbackSeconds;
    }
  }

  @override
  void didUpdateWidget(covariant PieLiveElapsed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.idleStartedAt != oldWidget.idleStartedAt || widget.fallbackMinutes != oldWidget.fallbackMinutes) {
      _initTime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _elapsedSeconds);
}

/// Elapsed time block: label + big tabular time + progress bar against the warning threshold.
class PieElapsedMeter extends StatelessWidget {
  final ParkingIdleEngineAlert alert;
  final int seconds;
  final double thresholdMinutes;

  const PieElapsedMeter({super.key, required this.alert, required this.seconds, required this.thresholdMinutes});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final on = alert.engineState == 'on';
    final warn = alert.warningActive;
    final tone = warn ? FxTokens.red : (on ? FxTokens.amber : FxTokens.slate);
    final thrS = thresholdMinutes * 60;
    final frac = thrS > 0 ? (seconds / thrS).clamp(0.0, 1.0) : 0.0;

    String? right;
    Color rightColor = t.textMuted;
    if (on && thrS > 0) {
      if (seconds >= thrS) {
        right = 'Vượt ngưỡng';
        rightColor = t.ink(FxTokens.red);
      } else {
        right = 'Còn ${((thrS - seconds) / 60).ceil()} phút';
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 9.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: t.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 15.sp, color: t.ink(tone)),
              SizedBox(width: 6.w),
              Expanded(child: Text('Thời gian nổ máy', style: t.small, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(pieFmtElapsed(seconds), style: t.num(16.sp, color: warn ? t.ink(FxTokens.red) : t.text)),
            ],
          ),
          SizedBox(height: 8.h),
          LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            color: tone,
            backgroundColor: t.track,
            borderRadius: BorderRadius.circular(6),
          ),
          SizedBox(height: 5.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  thresholdMinutes > 0 ? 'Ngưỡng cảnh báo ${pieFmtNum(thresholdMinutes, 0)} phút' : 'Chưa đặt ngưỡng cảnh báo',
                  style: t.tiny,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (right != null)
                Text(
                  right,
                  style: t.tiny.copyWith(color: rightColor, fontWeight: FontWeight.w700, fontFeatures: FxTokens.tabular),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
