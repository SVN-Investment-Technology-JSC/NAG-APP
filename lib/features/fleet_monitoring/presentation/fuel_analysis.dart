import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';

/// Port of fuel-analysis.ts of the web frontend: split the CAN series into moving / standing phases.

class FuelRow {
  final int ts;
  final double? level; // filtered level, % (settled readings only)
  final double? levelRaw; // realtime level, % (every CAN reading, for charts)
  final double? rate; // fuel rate, L/h
  final double? speed;
  final double? rpm;
  final double? total; // Total Fuel Used counter (L)
  final double? odo; // km

  const FuelRow({required this.ts, this.level, this.levelRaw, this.rate, this.speed, this.rpm, this.total, this.odo});
}

enum PhaseKind { moving, standingOn, standingOff, standing }

const Map<PhaseKind, String> kPhaseLabel = {
  PhaseKind.moving: 'Di chuyển',
  PhaseKind.standingOn: 'Dừng, nổ máy',
  PhaseKind.standingOff: 'Dừng, tắt máy',
  PhaseKind.standing: 'Dừng',
};

class Phase {
  final int from;
  final int to;
  final PhaseKind kind;
  final double? distanceKm;
  final double? fuelL;
  final double? levelStart;
  final double? levelEnd;
  final double? l100;

  const Phase({
    required this.from,
    required this.to,
    required this.kind,
    this.distanceKm,
    this.fuelL,
    this.levelStart,
    this.levelEnd,
    this.l100,
  });
}

const double _movingKmh = 1;
const int _gapS = 120; // a hole in the data longer than this ends a phase
const int _minStopS = 120; // a stop shorter than this between two moving phases is traffic
const int _rateGapS = 30; // integrate the fuel rate only across gaps up to this

T? _at<T>(List<T?>? l, int i) => l != null && i < l.length ? l[i] : null;

List<FuelRow> toRows(FleetSeries? s) {
  if (s == null) return const [];
  return List.generate(
    s.ts.length,
    (i) => FuelRow(
      ts: s.ts[i],
      level: _at(s.levelFiltered, i),
      levelRaw: _at(s.levelRaw, i),
      rate: _at(s.fuelRateLph, i),
      speed: _at(s.speed, i),
      rpm: _at(s.rpm, i),
      total: _at(s.totalFuelL, i),
      odo: _at(s.odo, i),
    ),
  );
}

PhaseKind? _stateOf(FuelRow r) {
  if (r.speed != null && r.speed! > _movingKmh) return PhaseKind.moving;
  if (r.rpm != null) return r.rpm! > 100 ? PhaseKind.standingOn : PhaseKind.standingOff;
  if (r.speed != null) return PhaseKind.standing;
  return null;
}

Phase _stats(List<FuelRow> rows, int a, int b, PhaseKind kind) {
  final seg = rows.where((r) => r.ts >= a && r.ts <= b).toList();
  ({double first, double last})? firstLast(double? Function(FuelRow) get) {
    final v = seg.map(get).whereType<double>().toList();
    return v.isEmpty ? null : (first: v.first, last: v.last);
  }

  final odo = firstLast((r) => r.odo);
  final distanceKm = odo != null && odo.last >= odo.first && odo.last - odo.first < 1000 ? odo.last - odo.first : null;
  final tot = firstLast((r) => r.total);
  double? fuelL = tot != null && tot.last >= tot.first ? tot.last - tot.first : null;
  if (fuelL == null) {
    double acc = 0;
    bool covered = false;
    for (var i = 1; i < seg.length; i++) {
      final p = seg[i - 1], q = seg[i], dt = q.ts - p.ts;
      if (p.rate != null && dt > 0 && dt <= _rateGapS) {
        acc += (p.rate! * dt) / 3600;
        covered = true;
      }
    }
    fuelL = covered ? acc : null;
  }
  final lv = firstLast((r) => r.level);
  final l100 = fuelL != null && distanceKm != null && distanceKm >= 0.5 ? (fuelL / distanceKm) * 100 : null;
  return Phase(
    from: a,
    to: b,
    kind: kind,
    distanceKm: distanceKm,
    fuelL: fuelL,
    levelStart: lv?.first,
    levelEnd: lv?.last,
    l100: l100,
  );
}

class _Seg {
  int from;
  int to;
  PhaseKind kind;
  _Seg(this.from, this.to, this.kind);
}

/// Split the session into moving / standing phases from speed and engine RPM.
List<Phase> derivePhases(List<FuelRow> rows) {
  final segs = <_Seg>[];
  int? lastTs;
  for (final r in rows) {
    final k = _stateOf(r);
    if (k == null) continue;
    final cur = segs.isEmpty ? null : segs.last;
    if (cur != null && cur.kind == k && lastTs != null && r.ts - lastTs <= _gapS) {
      cur.to = r.ts;
    } else {
      segs.add(_Seg(r.ts, r.ts, k));
    }
    lastTs = r.ts;
  }
  // short stops between two moving phases that touch each other are traffic: fold them into the movement
  for (var i = 1; i < segs.length - 1; i++) {
    final p = segs[i - 1], c = segs[i], n = segs[i + 1];
    if (c.kind != PhaseKind.moving &&
        p.kind == PhaseKind.moving &&
        n.kind == PhaseKind.moving &&
        c.to - c.from < _minStopS &&
        c.from - p.to <= _gapS &&
        n.from - c.to <= _gapS) {
      c.kind = PhaseKind.moving;
    }
  }
  final merged = <_Seg>[];
  for (final s in segs) {
    final m = merged.isEmpty ? null : merged.last;
    if (m != null && m.kind == s.kind && s.from - m.to <= _gapS) {
      m.to = s.to;
    } else {
      merged.add(_Seg(s.from, s.to, s.kind));
    }
  }
  return merged.map((s) => _stats(rows, s.from, s.to, s.kind)).toList();
}

class TimeSplit {
  double moving = 0, standingOn = 0, standingOff = 0, unknown = 0, total = 0;
}

/// Seconds observed in each state (gaps in the data are not counted as any state).
TimeSplit timeSplit(List<Phase> phases) {
  final t = TimeSplit();
  for (final p in phases) {
    final d = (p.to - p.from).clamp(0, 1 << 31).toDouble();
    switch (p.kind) {
      case PhaseKind.moving:
        t.moving += d;
      case PhaseKind.standingOn:
        t.standingOn += d;
      case PhaseKind.standingOff:
        t.standingOff += d;
      case PhaseKind.standing:
        t.unknown += d;
    }
    t.total += d;
  }
  return t;
}

/// The latest known level (%) and when it was read.
({double value, int ts})? currentLevel(List<FuelRow> rows) {
  for (var i = rows.length - 1; i >= 0; i--) {
    if (rows[i].level != null) return (value: rows[i].level!, ts: rows[i].ts);
  }
  return null;
}

/// Evenly thin a long series for drawing (keeps the last point).
List<T> decimate<T>(List<T> rows, int max) {
  if (rows.length <= max) return rows;
  final step = (rows.length / max).ceil();
  final out = <T>[];
  for (var i = 0; i < rows.length; i += step) {
    out.add(rows[i]);
  }
  if (!identical(out.last, rows.last)) out.add(rows.last);
  return out;
}
