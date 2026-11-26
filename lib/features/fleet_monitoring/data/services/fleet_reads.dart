import 'package:flutter/foundation.dart';
import 'package:nguyenanh/core/network/api_client.dart';

/// Read receipts of fleet alerts, per logged-in user (server: /fleet-push/reads).
/// Opening an alert anywhere in the app (bell, lists, tapped push) records it, so the bell can show
/// what is still unread and the alert detail can show who has seen it.
class FleetReads extends ChangeNotifier {
  FleetReads._();
  static final FleetReads instance = FleetReads._();

  final Set<String> _read = {};
  final Map<String, int> _readers = {};
  final Map<String, DateTime> _recent = {};

  bool isRead(String id) => _read.contains(id);
  int readers(String id) => _readers[id] ?? 0;
  int unread(Iterable<String> ids) => ids.where((id) => !_read.contains(id)).length;

  /// Forget everything (logout / another user).
  void clear() {
    _read.clear();
    _readers.clear();
    _recent.clear();
    notifyListeners();
  }

  /// Read state of these alerts for me + how many people opened each one.
  Future<void> lookup(Iterable<String> ids) async {
    final list = ids.where((e) => e.isNotEmpty).toSet().toList();
    if (list.isEmpty) return;
    try {
      final r = await ApiClient.dio.post('/fleet-push/reads/lookup', data: {'event_ids': list.take(500).toList()});
      final d = r.data is Map ? (r.data['data'] ?? r.data) : null;
      if (d is! Map) return;
      final mine = (d['read'] as List?)?.whereType<String>() ?? const <String>[];
      final counts = d['readers'] is Map ? Map<String, dynamic>.from(d['readers'] as Map) : const <String, dynamic>{};
      _read.addAll(mine);
      for (final id in list) {
        final n = counts[id];
        if (n is num) _readers[id] = n.toInt();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[FleetReads] lookup failed: $e');
    }
  }

  /// I opened [ids] ([source]: bell | list | push | all). Shown as read right away; sent to the server
  /// (the same alert opened twice within a few seconds counts once).
  Future<void> markRead(Iterable<String> ids, {String source = 'list'}) async {
    final now = DateTime.now();
    final list = ids
        .where((id) => id.isNotEmpty && (_recent[id] == null || now.difference(_recent[id]!) > const Duration(seconds: 5)))
        .toSet()
        .toList();
    if (list.isEmpty) return;
    for (final id in list) {
      _recent[id] = now;
      if (_read.add(id)) _readers[id] = (_readers[id] ?? 0) + 1;
    }
    notifyListeners();
    try {
      await ApiClient.dio.post('/fleet-push/reads', data: {'event_ids': list.take(500).toList(), 'source': source});
    } catch (e) {
      debugPrint('[FleetReads] markRead failed: $e');
    }
  }

  /// Who opened one alert, first reader first.
  Future<List<FleetReader>> who(String id) async {
    final r = await ApiClient.dio.get('/fleet-push/reads/$id');
    final d = r.data is Map ? (r.data['data'] ?? r.data) : null;
    final items = d is Map ? d['items'] : null;
    return items is List ? items.whereType<Map>().map((e) => FleetReader.fromJson(Map<String, dynamic>.from(e))).toList() : [];
  }
}

class FleetReader {
  final int userId;
  final String name;
  final DateTime? firstAt;
  final DateTime? lastAt;
  final int views;

  FleetReader({required this.userId, required this.name, this.firstAt, this.lastAt, this.views = 1});

  factory FleetReader.fromJson(Map<String, dynamic> j) {
    final full = (j['full_name'] ?? '').toString().trim();
    final short = (j['short_name'] ?? '').toString().trim();
    return FleetReader(
      userId: (j['user_id'] as num?)?.toInt() ?? 0,
      name: full.isNotEmpty ? full : (short.isNotEmpty ? short : 'Người dùng #${j['user_id']}'),
      firstAt: DateTime.tryParse('${j['first_read_at']}')?.toLocal(),
      lastAt: DateTime.tryParse('${j['last_read_at']}')?.toLocal(),
      views: (j['views'] as num?)?.toInt() ?? 1,
    );
  }
}
