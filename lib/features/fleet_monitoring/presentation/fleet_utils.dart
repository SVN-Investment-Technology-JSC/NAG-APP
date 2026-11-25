import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

/// Severity / risk labels and number/time formatting — same as fleet-utils.ts of the web frontend.

class FleetTone {
  final String label;
  final Color color;
  const FleetTone(this.label, this.color);
}

const Map<String, FleetTone> kSeverity = {
  'info': FleetTone('Thông tin', Color(0xFF16A34A)),
  'notable': FleetTone('Đáng chú ý', Color(0xFFCA8A04)),
  'review': FleetTone('Cần rà soát', Color(0xFFF59E0B)),
  'strong': FleetTone('Mạnh', Color(0xFFDC2626)),
  'suspect': FleetTone('Bất thường', Color(0xFFDC2626)),
};

const Map<String, FleetTone> kRisk = {
  'check': FleetTone('Cần kiểm tra', Color(0xFFDC2626)),
  'delivery': FleetTone('Điểm giao', Color(0xFF16A34A)),
  'normal': FleetTone('Bình thường', Color(0xFF94A3B8)),
};

const Map<String, FleetTone> kActivity = {
  'moving': FleetTone('Đang chạy', Color(0xFF16A34A)),
  'idle': FleetTone('Nổ máy đứng yên', Color(0xFFCA8A04)),
  'stopped': FleetTone('Dừng, tắt máy', Color(0xFF64748B)),
  'stationary': FleetTone('Đứng yên', Color(0xFF64748B)),
  'no_data': FleetTone('Mất tín hiệu', Color(0xFFDC2626)),
  'unknown': FleetTone('Chưa rõ', Color(0xFF64748B)),
};

FleetTone severityOf(String s) => kSeverity[s] ?? FleetTone(s, const Color(0xFF64748B));
FleetTone riskOf(String s) => kRisk[s] ?? FleetTone(s, const Color(0xFF64748B));
FleetTone activityOf(String s) => kActivity[s] ?? FleetTone(s, const Color(0xFF64748B));

/// Trip route: outbound (yard -> delivery) and return (delivery -> yard).
const Color kRouteGo = Color(0xFF2563EB);
const Color kRouteBack = Color(0xFFF97316);

const Map<String, String> kReviewLabels = {
  'discharge': 'Có xả bê tông',
  'no_discharge': 'Không xả',
  'traffic': 'Kẹt xe / chờ',
  'washout': 'Rửa bồn',
  'needs_check': 'Cần kiểm tra thêm',
};

String reviewLabel(String? v) => kReviewLabels[v] ?? v ?? '';

final Map<int, NumberFormat> _fmtCache = {};

String fmtNum(num? v, [int digits = 1, String unit = '']) {
  if (v == null || v.isNaN || v.isInfinite) return '—';
  final f = _fmtCache.putIfAbsent(digits, () => NumberFormat('#,##0${digits > 0 ? '.${'#' * digits}' : ''}', 'vi'));
  return '${f.format(v)}${unit.isNotEmpty ? ' $unit' : ''}';
}

String fmtDur(num? s) {
  if (s == null) return '—';
  if (s < 120) return '${s.round()} giây';
  if (s < 7200) return '${(s / 60).round()} phút';
  return '${(s / 3600).toStringAsFixed(1)} giờ';
}

DateTime? parseTime(String? iso) => iso == null || iso.isEmpty ? null : DateTime.tryParse(iso)?.toLocal();

DateTime fromUnix(int s) => DateTime.fromMillisecondsSinceEpoch(s * 1000);

int toUnix(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

String fmtTime(String? iso, {bool withDate = false}) {
  final d = parseTime(iso);
  if (d == null) return '—';
  return DateFormat(withDate ? 'HH:mm dd/MM' : 'HH:mm').format(d);
}

String fmtUnix(int ts, {bool withDate = false}) => DateFormat(withDate ? 'HH:mm dd/MM' : 'HH:mm').format(fromUnix(ts));

/// Day range [00:00, 24:00) in local time, as epoch seconds.
({int from, int to}) dayRange(DateTime d) {
  final start = DateTime(d.year, d.month, d.day);
  final end = DateTime(d.year, d.month, d.day, 23, 59, 59);
  return (from: toUnix(start), to: toUnix(end));
}

/// What the logged-in user may see in "Giám sát xe" (same keys as the web sidebar: page key, or page key + "__view").
class FleetPermissions {
  final bool overview;
  final bool fuel;
  final bool concrete;
  final bool concreteReview;

  const FleetPermissions({this.overview = false, this.fuel = false, this.concrete = false, this.concreteReview = false});

  bool get any => overview || fuel || concrete;

  static const overviewKey = '/fleet-monitoring/overview';
  static const fuelKey = '/fleet-monitoring/fuel';
  static const concreteKey = '/fleet-monitoring/concrete';

  static FleetPermissions fromList(String role, List<String> perms) {
    final admin = role == 'admin';
    bool page(String k) => admin || perms.contains(k) || perms.contains('${k}__view');
    return FleetPermissions(
      overview: page(overviewKey),
      fuel: page(fuelKey),
      concrete: page(concreteKey),
      concreteReview: admin || perms.contains('${concreteKey}__review'),
    );
  }

  static Future<FleetPermissions> load() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? '';
    if (role == 'admin') return fromList(role, const []);
    final perms = await UserManageService().getPermissions();
    return fromList(role, perms[role] ?? const []);
  }
}
