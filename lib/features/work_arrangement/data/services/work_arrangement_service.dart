import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/work_arrangement/data/models/work_arrangement_models.dart';

class WorkArrangementService {
  final Dio dio;

  WorkArrangementService(this.dio);

  Future<List<WorkPersonnel>> _getPersonnel() async {
    try {
      final response = await dio.get(AppEndpoints.userAssignments, queryParameters: {'limit': 1000});
      final data = _extractList(response.data);
      return data
          .where((item) => item['delete_flag'] != true && item['user_id'] != null)
          .map((item) => WorkPersonnel(
                userId: int.tryParse(item['user_id'].toString()) ?? 0,
                userFullName: item['user_full_name'] ?? '',
                userShortName: item['user_short_name'],
                departmentId: item['department_id'] != null ? int.tryParse(item['department_id'].toString()) : null,
                departmentName: item['department_name'],
                skillId: item['skill_id'] != null ? int.tryParse(item['skill_id'].toString()) : null,
                skillName: item['skill_name'],
              ))
          .where((p) => p.userId > 0)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<WorkVehicle>> _getVehicles() async {
    try {
      final response = await dio.get(AppEndpoints.vehicles, queryParameters: {'limit': 1000});
      final data = _extractList(response.data);
      return data.map((item) => WorkVehicle.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  List<dynamic> _extractList(dynamic payload) {
    if (payload is List) return payload;
    if (payload is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'results', 'rows', 'user_assignments', 'vehicles', 'works', 'work_arrangement_days', 'work_arrangement_items', 'work_arrangement_personnel']) {
        if (payload[key] is List) return payload[key];
      }
    }
    return [];
  }

  Map<String, dynamic> _extractItem(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      if (payload['data'] is Map<String, dynamic>) return payload['data'];
      return payload;
    }
    return {};
  }

  int _getId(Map<String, dynamic> item, List<String> keys) {
    for (var k in keys) {
      if (item[k] != null) {
        final val = int.tryParse(item[k].toString());
        if (val != null && val > 0) return val;
      }
    }
    return 0;
  }

  Future<int> _ensureArrangementDay(String workDate) async {
    try {
      final res = await dio.get(AppEndpoints.workArrangementDays, queryParameters: {'arrangement_date': workDate, 'limit': 1000});
      final items = _extractList(res.data);
      final existing = items.firstWhere((e) => e['delete_flag'] != true && (e['arrangement_date'] ?? '').toString().startsWith(workDate), orElse: () => null);
      if (existing != null) {
        final id = _getId(existing, ['work_arrangement_day_id', 'arrangement_day_id', 'id']);
        if (id > 0) return id;
      }
      final createRes = await dio.post(AppEndpoints.workArrangementDays, data: {
        'arrangement_date': workDate,
        'arrangement_status': 'draft',
      });
      return _getId(_extractItem(createRes.data), ['work_arrangement_day_id', 'arrangement_day_id', 'id']);
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _listArrangementItems(int dayId) async {
    try {
      final res = await dio.get(AppEndpoints.workArrangementItems, queryParameters: {'work_arrangement_day_id': dayId, 'limit': 1000});
      return _extractList(res.data).cast<Map<String, dynamic>>().where((e) => e['delete_flag'] != true && _getId(e, ['work_arrangement_day_id', 'arrangement_day_id', 'day_id', 'id']) == dayId).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _listArrangementPersonnel(int itemId) async {
    try {
      final res = await dio.get(AppEndpoints.workArrangementPersonnel, queryParameters: {'work_arrangement_item_id': itemId, 'limit': 1000});
      return _extractList(res.data).cast<Map<String, dynamic>>().where((e) => e['delete_flag'] != true && _getId(e, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']) == itemId).toList();
    } catch (e) {
      return [];
    }
  }

  String _removeDiacritics(String str) {
    const withDia = 'áàảãạâấầẩẫậăắằẳẵặđéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ';
    const withoutDia = 'aaaaaaaaaaaaaaaaadeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
      str = str.replaceAll(withDia[i].toUpperCase(), withoutDia[i].toUpperCase());
    }
    return str;
  }

  String _normalizeWorkType(String value) {
    String v = _removeDiacritics(value).toLowerCase();
    return v.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _getPumpRoleKey(String role) {
    final norm = _normalizeWorkType(role);
    if (norm.contains('lai_xe')) return 'driver';
    if (norm.contains('van_hanh')) return 'operator';
    if (norm.contains('om_voi') || norm.contains('phu_voi')) return 'hose';
    return role.toLowerCase();
  }
  
  String _getPumpRoleName(String key) {
    switch(key) {
      case 'driver': return 'LÁI XE';
      case 'operator': return 'VẬN HÀNH';
      case 'hose': return 'ÔM VÒI';
      default: return key;
    }
  }

  Future<WorkAssignmentDraft> _buildPumpDraft(String workDate, int dayId) async {
    if (dayId == 0) return WorkAssignmentDraft(workDate: workDate, pumpAssignments: []);
    final items = await _listArrangementItems(dayId);
    final pumpAssignments = <PumpAssignmentItem>[];

    final sortedItems = items.toList()..sort((a, b) => (int.tryParse(a['display_order']?.toString() ?? '0') ?? 0).compareTo(int.tryParse(b['display_order']?.toString() ?? '0') ?? 0));

    for (var item in sortedItems) {
      if (item['work_type'] == 'XE BỒN' || (item['item_note'] ?? '').toString().startsWith('CV:')) continue;
      final itemId = _getId(item, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
      final vehicleId = _getId(item, ['vehicle_id']);
      if (itemId == 0 || vehicleId == 0) continue;

      final people = await _listArrangementPersonnel(itemId);
      final roles = {'driver': <int>[], 'operator': <int>[], 'hose': <int>[]};

      for (var p in people) {
        final userId = _getId(p, ['user_id']);
        final roleKey = _getPumpRoleKey(p['personnel_role'] ?? '');
        if (userId > 0 && roles.containsKey(roleKey)) {
          roles[roleKey]!.add(userId);
        }
      }

      pumpAssignments.add(PumpAssignmentItem(
        assignmentId: 'item:$itemId',
        vehicleId: vehicleId,
        roles: roles,
      ));
    }
    return WorkAssignmentDraft(workDate: workDate, pumpAssignments: pumpAssignments);
  }

  Future<WorkMixerAssignmentDraft> _buildMixerDraft(String workDate, int dayId) async {
    if (dayId == 0) return WorkMixerAssignmentDraft(workDate: workDate, mixerAssignments: []);
    final items = await _listArrangementItems(dayId);
    final mixerAssignments = <MixerAssignmentItem>[];

    final sortedItems = items.toList()..sort((a, b) => (int.tryParse(a['display_order']?.toString() ?? '0') ?? 0).compareTo(int.tryParse(b['display_order']?.toString() ?? '0') ?? 0));

    for (var item in sortedItems) {
      if (item['work_type'] != 'XE BỒN') continue;
      final itemId = _getId(item, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
      final vehicleId = _getId(item, ['vehicle_id']);
      if (itemId == 0 || vehicleId == 0) continue;

      final people = await _listArrangementPersonnel(itemId);
      int? userId;
      for (var p in people) {
        final uid = _getId(p, ['user_id']);
        if (uid > 0) {
          userId = uid;
          break;
        }
      }

      mixerAssignments.add(MixerAssignmentItem(
        assignmentId: 'item:$itemId',
        vehicleId: vehicleId,
        userId: userId,
      ));
    }
    return WorkMixerAssignmentDraft(workDate: workDate, mixerAssignments: mixerAssignments);
  }
  
  Future<WorkTaskAssignmentDraft> _buildTaskDraft(String workDate, int dayId) async {
    if (dayId == 0) return WorkTaskAssignmentDraft(workDate: workDate, taskAssignments: []);
    final items = await _listArrangementItems(dayId);
    final taskAssignments = <TaskAssignmentItem>[];
    
    final sortedItems = items.toList()..sort((a, b) => (int.tryParse(a['display_order']?.toString() ?? '0') ?? 0).compareTo(int.tryParse(b['display_order']?.toString() ?? '0') ?? 0));

    for (var item in sortedItems) {
      final workType = (item['work_type'] ?? '').toString();
      if (!workType.startsWith('CV:')) continue;
      
      final itemId = _getId(item, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
      final workId = int.tryParse(workType.substring(3)) ?? 0;
      if (itemId == 0 || workId == 0) continue;

      final people = await _listArrangementPersonnel(itemId);
      final userIds = <int>[];
      for (var p in people) {
        final uid = _getId(p, ['user_id']);
        if (uid > 0) {
          userIds.add(uid);
        }
      }

      taskAssignments.add(TaskAssignmentItem(
        assignmentId: 'item:$itemId',
        workId: workId,
        userIds: userIds,
      ));
    }
    return WorkTaskAssignmentDraft(workDate: workDate, taskAssignments: taskAssignments);
  }

  Future<WorkArrangementBootstrap> getAssignmentBootstrap(String date) async {
    final personnel = await _getPersonnel();
    final allVehicles = await _getVehicles();

    final pumpVehicles = allVehicles.where((v) => !(v.vehicleName?.toUpperCase().startsWith('X') ?? false)).toList();
    final mixerVehicles = allVehicles.where((v) => v.vehicleName?.toUpperCase().startsWith('X') ?? false).toList();

    List<int> halfDayUserIds = [];
    try {
      final res = await dio.get(AppEndpoints.userDayStatus, queryParameters: {'work_date': date, 'limit': 1000});
      final statuses = _extractList(res.data);
      for (var s in statuses) {
        if (s['delete_flag'] != true && s['day_status'] == 'half_day' && s['user_id'] != null) {
          halfDayUserIds.add(int.tryParse(s['user_id'].toString()) ?? 0);
        }
      }
    } catch (_) {}

    int dayId = 0;
    try {
      final res = await dio.get(AppEndpoints.workArrangementDays, queryParameters: {'arrangement_date': date, 'limit': 1000});
      final items = _extractList(res.data);
      final existing = items.firstWhere((e) => e['delete_flag'] != true && (e['arrangement_date'] ?? '').toString().startsWith(date), orElse: () => null);
      if (existing != null) {
        dayId = _getId(existing, ['work_arrangement_day_id', 'arrangement_day_id', 'id']);
      }
    } catch (_) {}

    final pumpDraft = await _buildPumpDraft(date, dayId);
    final mixerDraft = await _buildMixerDraft(date, dayId);

    return WorkArrangementBootstrap(
      workDate: date,
      personnel: personnel,
      halfDayUserIds: halfDayUserIds,
      pumpVehicles: pumpVehicles,
      pumpDraft: pumpDraft,
      mixerVehicles: mixerVehicles,
      mixerDraft: mixerDraft,
    );
  }

  Future<void> _syncPumpArrangementItems(int dayId, WorkAssignmentDraft draft, Map<int, WorkPersonnel> personnelById) async {
    final existingItems = await _listArrangementItems(dayId);
    final existingByVehicleId = <int, Map<String, dynamic>>{};
    
    for (var item in existingItems) {
      if (item['work_type'] == 'XE BỒN' || (item['item_note'] ?? '').toString().startsWith('CV:')) continue;
      final vid = _getId(item, ['vehicle_id']);
      if (vid > 0) existingByVehicleId[vid] = item;
    }
    
    final desiredVehicleIds = draft.pumpAssignments.map((a) => a.vehicleId).toSet();
    
    for (int i = 0; i < draft.pumpAssignments.length; i++) {
      final assignment = draft.pumpAssignments[i];
      final existing = existingByVehicleId[assignment.vehicleId];
      final existingId = existing != null ? _getId(existing, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']) : 0;
      
      int itemId = existingId;
      final payload = {
        'work_arrangement_day_id': dayId,
        'vehicle_id': assignment.vehicleId,
        'work_type': 'XE BƠM',
        'item_note': 'XE BƠM',
        'display_order': i + 1,
      };
      
      if (existingId > 0) {
        await dio.put('${AppEndpoints.workArrangementItems}/$existingId', data: payload);
      } else {
        final res = await dio.post(AppEndpoints.workArrangementItems, data: payload);
        itemId = _getId(_extractItem(res.data), ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
      }
      
      if (itemId > 0) {
        await _syncPumpPersonnel(itemId, assignment, personnelById);
      }
    }
    
    for (var item in existingItems) {
      if (item['work_type'] == 'XE BỒN' || (item['item_note'] ?? '').toString().startsWith('CV:')) continue;
      final itemId = _getId(item, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
      final vehicleId = _getId(item, ['vehicle_id']);
      if (itemId > 0 && !desiredVehicleIds.contains(vehicleId)) {
        await dio.delete('${AppEndpoints.workArrangementItems}/$itemId');
      }
    }
  }
  
  Future<void> _syncPumpPersonnel(int itemId, PumpAssignmentItem assignment, Map<int, WorkPersonnel> personnelById) async {
    final existing = await _listArrangementPersonnel(itemId);
    final desired = <String, int>{}; // 'role:userId' -> userId
    
    for (var roleKey in assignment.roles.keys) {
      for (var userId in assignment.roles[roleKey]!) {
        desired['$roleKey:$userId'] = userId;
      }
    }
    
    final existingByRoleAndUser = <String, Map<String, dynamic>>{};
    for (var record in existing) {
      final rKey = _getPumpRoleKey(record['personnel_role'] ?? '');
      final uid = _getId(record, ['user_id']);
      existingByRoleAndUser['$rKey:$uid'] = record;
    }
    
    for (var entry in desired.entries) {
      final roleKey = entry.key.split(':')[0];
      final userId = entry.value;
      final person = personnelById[userId];
      if (person == null) continue;
      
      final exRecord = existingByRoleAndUser[entry.key];
      final exId = exRecord != null ? _getId(exRecord, ['work_arrangement_personnel_id', 'arrangement_personnel_id', 'personnel_id', 'id']) : 0;
      
      final roleName = _getPumpRoleName(roleKey);
      final payload = {
        'work_arrangement_item_id': itemId,
        'user_id': userId,
        'department_id_snapshot': person.departmentId,
        'skill_id_snapshot': person.skillId,
        'personnel_role': roleName,
      };
      
      if (exId > 0) {
        await dio.put('${AppEndpoints.workArrangementPersonnel}/$exId', data: payload);
      } else {
        await dio.post(AppEndpoints.workArrangementPersonnel, data: payload);
      }
    }
    
    for (var record in existing) {
      final rKey = _getPumpRoleKey(record['personnel_role'] ?? '');
      final uid = _getId(record, ['user_id']);
      final recordId = _getId(record, ['work_arrangement_personnel_id', 'arrangement_personnel_id', 'personnel_id', 'id']);
      if (recordId > 0 && !desired.containsKey('$rKey:$uid')) {
        await dio.delete('${AppEndpoints.workArrangementPersonnel}/$recordId');
      }
    }
  }

  Future<void> _syncMixerArrangementItems(int dayId, WorkMixerAssignmentDraft draft, Map<int, WorkPersonnel> personnelById) async {
    final desired = draft.mixerAssignments.where((a) => a.userId != null).toList();
    final desiredVehicleIds = desired.map((a) => a.vehicleId).toSet();
    
    final existingItems = await _listArrangementItems(dayId);
    final existingByVehicleId = <int, Map<String, dynamic>>{};
    
    for (var item in existingItems) {
      if (item['work_type'] == 'XE BỒN') {
        final vid = _getId(item, ['vehicle_id']);
        if (vid > 0) existingByVehicleId[vid] = item;
      }
    }
    
    for (int i = 0; i < desired.length; i++) {
      final assignment = desired[i];
      final person = personnelById[assignment.userId!];
      if (person == null) continue;
      
      final existing = existingByVehicleId[assignment.vehicleId];
      final existingId = existing != null ? _getId(existing, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']) : 0;
      
      int itemId = existingId;
      final payload = {
        'work_arrangement_day_id': dayId,
        'vehicle_id': assignment.vehicleId,
        'work_type': 'XE BỒN',
        'item_note': 'XE BỒN',
        'display_order': i + 1,
      };
      
      if (existingId > 0) {
        await dio.put('${AppEndpoints.workArrangementItems}/$existingId', data: payload);
      } else {
        final res = await dio.post(AppEndpoints.workArrangementItems, data: payload);
        itemId = _getId(_extractItem(res.data), ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
      }
      
      if (itemId > 0) {
        final existingPeople = await _listArrangementPersonnel(itemId);
        for (var record in existingPeople) {
          final rid = _getId(record, ['work_arrangement_personnel_id', 'arrangement_personnel_id', 'personnel_id', 'id']);
          if (rid > 0 && _getId(record, ['user_id']) != person.userId) {
            await dio.delete('${AppEndpoints.workArrangementPersonnel}/$rid');
          }
        }
        
        final already = existingPeople.any((r) => _getId(r, ['user_id']) == person.userId);
        if (!already) {
          await dio.post(AppEndpoints.workArrangementPersonnel, data: {
            'work_arrangement_item_id': itemId,
            'user_id': person.userId,
            'department_id_snapshot': person.departmentId,
            'skill_id_snapshot': person.skillId,
            'personnel_role': 'LÁI XE',
          });
        }
      }
    }
    
    for (var item in existingItems) {
      if (item['work_type'] == 'XE BỒN') {
        final itemId = _getId(item, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
        final vehicleId = _getId(item, ['vehicle_id']);
        if (itemId > 0 && !desiredVehicleIds.contains(vehicleId)) {
          await dio.delete('${AppEndpoints.workArrangementItems}/$itemId');
        }
      }
    }
  }
  
  Future<void> _syncTaskArrangementItems(int dayId, WorkTaskAssignmentDraft draft, Map<int, WorkPersonnel> personnelById, Map<int, WorkTaskItem> worksById) async {
    final desired = draft.taskAssignments.where((a) => a.userIds.isNotEmpty).toList();
    final desiredWorkIds = desired.map((a) => a.workId).toSet();
    
    final existingItems = await _listArrangementItems(dayId);
    final existingByWorkId = <int, Map<String, dynamic>>{};
    
    for (var item in existingItems) {
      final workType = (item['work_type'] ?? '').toString();
      if (workType.startsWith('CV:')) {
        final wid = int.tryParse(workType.substring(3)) ?? 0;
        if (wid > 0) existingByWorkId[wid] = item;
      }
    }
    
    for (int i = 0; i < desired.length; i++) {
      final assignment = desired[i];
      final workName = worksById[assignment.workId]?.workName ?? '#${assignment.workId}';
      
      final existing = existingByWorkId[assignment.workId];
      final existingId = existing != null ? _getId(existing, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']) : 0;
      
      int itemId = existingId;
      final payload = {
        'work_arrangement_day_id': dayId,
        'vehicle_id': null,
        'work_type': 'CV:${assignment.workId}',
        'item_note': workName,
        'display_order': i + 1,
      };
      
      if (existingId > 0) {
        await dio.put('${AppEndpoints.workArrangementItems}/$existingId', data: payload);
      } else {
        final res = await dio.post(AppEndpoints.workArrangementItems, data: payload);
        itemId = _getId(_extractItem(res.data), ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
      }
      
      if (itemId > 0) {
        final existingPeople = await _listArrangementPersonnel(itemId);
        final existingUserSet = existingPeople.map((r) => _getId(r, ['user_id'])).toSet();
        final desiredUserSet = assignment.userIds.toSet();
        
        for (var userId in assignment.userIds) {
          final person = personnelById[userId];
          if (person != null && !existingUserSet.contains(userId)) {
            await dio.post(AppEndpoints.workArrangementPersonnel, data: {
              'work_arrangement_item_id': itemId,
              'user_id': userId,
              'department_id_snapshot': person.departmentId,
              'skill_id_snapshot': person.skillId,
              'personnel_role': 'CV',
            });
          }
        }
        
        for (var record in existingPeople) {
          final rid = _getId(record, ['work_arrangement_personnel_id', 'arrangement_personnel_id', 'personnel_id', 'id']);
          final uid = _getId(record, ['user_id']);
          if (rid > 0 && !desiredUserSet.contains(uid)) {
            await dio.delete('${AppEndpoints.workArrangementPersonnel}/$rid');
          }
        }
      }
    }
    
    for (var item in existingItems) {
      final workType = (item['work_type'] ?? '').toString();
      if (workType.startsWith('CV:')) {
        final itemId = _getId(item, ['work_arrangement_item_id', 'arrangement_item_id', 'item_id', 'id']);
        final workId = int.tryParse(workType.substring(3)) ?? 0;
        if (itemId > 0 && !desiredWorkIds.contains(workId)) {
          await dio.delete('${AppEndpoints.workArrangementItems}/$itemId');
        }
      }
    }
  }

  Future<WorkAssignmentDraft> savePumpAssignment(WorkAssignmentDraft draft) async {
    final dayId = await _ensureArrangementDay(draft.workDate);
    if (dayId == 0) return draft;
    
    final personnel = await _getPersonnel();
    final personnelById = {for (var p in personnel) p.userId: p};
    
    await _syncPumpArrangementItems(dayId, draft, personnelById);
    return draft;
  }

  Future<WorkMixerAssignmentDraft> saveMixerAssignment(WorkMixerAssignmentDraft draft) async {
    final dayId = await _ensureArrangementDay(draft.workDate);
    if (dayId == 0) return draft;
    
    final personnel = await _getPersonnel();
    final personnelById = {for (var p in personnel) p.userId: p};
    
    await _syncMixerArrangementItems(dayId, draft, personnelById);
    return draft;
  }

  Future<WorkTaskBootstrap> getTaskBootstrap(String date) async {
    final personnel = await _getPersonnel();
    List<WorkTaskItem> works = [];

    try {
      final response = await dio.get(AppEndpoints.works, queryParameters: {'limit': 1000});
      final data = _extractList(response.data);
      works = data.where((w) => w['delete_flag'] != true).map((w) => WorkTaskItem.fromJson(w)).toList();
    } catch (_) {}

    int dayId = 0;
    try {
      final res = await dio.get(AppEndpoints.workArrangementDays, queryParameters: {'arrangement_date': date, 'limit': 1000});
      final items = _extractList(res.data);
      final existing = items.firstWhere((e) => e['delete_flag'] != true && (e['arrangement_date'] ?? '').toString().startsWith(date), orElse: () => null);
      if (existing != null) {
        dayId = _getId(existing, ['work_arrangement_day_id', 'arrangement_day_id', 'id']);
      }
    } catch (_) {}

    final draft = await _buildTaskDraft(date, dayId);

    return WorkTaskBootstrap(
      workDate: date,
      personnel: personnel,
      works: works,
      draft: draft,
    );
  }

  Future<WorkTaskAssignmentDraft> saveTaskAssignment(WorkTaskAssignmentDraft draft) async {
    final dayId = await _ensureArrangementDay(draft.workDate);
    if (dayId == 0) return draft;
    
    final personnel = await _getPersonnel();
    final personnelById = {for (var p in personnel) p.userId: p};
    
    List<WorkTaskItem> works = [];
    try {
      final response = await dio.get(AppEndpoints.works, queryParameters: {'limit': 1000});
      final data = _extractList(response.data);
      works = data.where((w) => w['delete_flag'] != true).map((w) => WorkTaskItem.fromJson(w)).toList();
    } catch (_) {}
    final worksById = {for (var w in works) w.workId: w};
    
    await _syncTaskArrangementItems(dayId, draft, personnelById, worksById);
    return draft;
  }

  Future<List<WorkMixSlotItem>> getMixSlotList() async {
    // React handles this locally by mapping 'pending' orders and vehicles.
    return [];
  }

  Future<void> createWork(String workName, int? workRoot) async {
    await dio.post(AppEndpoints.works, data: {'work_name': workName, 'work_root': workRoot});
  }

  // --- ATTENDANCE METHODS ---

  Future<WorkAttendanceBootstrap> getAttendanceBootstrap(String date) async {
    final personnel = await _getPersonnel();
    
    // Fetch day statuses
    final statuses = <UserDayStatus>[];
    try {
      final res = await dio.get(AppEndpoints.userDayStatus, queryParameters: {'work_date': date, 'limit': 1000});
      final list = _extractList(res.data);
      for (var s in list) {
        if (s['delete_flag'] != true && s['user_id'] != null) {
          final uid = int.tryParse(s['user_id'].toString()) ?? 0;
          if (uid > 0) {
            String status = 'working';
            if (s['day_status'] == 'off_morning') status = 'off_morning';
            else if (s['day_status'] == 'off_afternoon') status = 'off_afternoon';
            else if (s['day_status'] == 'off_full' || s['day_status'] == 'half_day') status = 'off_full'; // Map half_day to off_full or adapt
            statuses.add(UserDayStatus(userId: uid, status: status));
          }
        }
      }
    } catch (_) {}

    // Check if attendance is marked (e.g. is there an attendance_daily_record for this date)
    bool isMarked = false;
    try {
      final res = await dio.get(AppEndpoints.attendanceDailyRecords, queryParameters: {'start_date': date, 'end_date': date, 'limit': 1000});
      final list = _extractList(res.data);
      isMarked = list.any((e) => e['delete_flag'] != true && (e['work_date'] ?? '').toString().startsWith(date));
    } catch (_) {}

    return WorkAttendanceBootstrap(
      workDate: date,
      personnel: personnel,
      isAttendanceMarked: isMarked,
      draft: WorkAttendanceDraft(
        workDate: date,
        userStatuses: statuses.where((e) => e.status != 'working').toList(),
      ),
    );
  }

  Future<WorkAttendanceDraft> saveAttendanceDraft(WorkAttendanceDraft draft) async {
    // 1. Ensure attendance daily record
    try {
      await dio.post(AppEndpoints.attendanceDailyRecords, data: {'work_date': draft.workDate});
    } catch (_) {} // Might already exist

    // 2. Fetch existing day statuses
    final existingStatuses = <int, Map<String, dynamic>>{};
    try {
      final res = await dio.get(AppEndpoints.userDayStatus, queryParameters: {'work_date': draft.workDate, 'limit': 1000});
      final list = _extractList(res.data);
      for (var s in list) {
        if (s['delete_flag'] != true && s['user_id'] != null) {
          final uid = int.tryParse(s['user_id'].toString()) ?? 0;
          if (uid > 0) existingStatuses[uid] = s;
        }
      }
    } catch (_) {}

    // 3. Upsert desired statuses
    final desiredStatuses = draft.userStatuses.where((e) => e.status != 'working').toList();
    final desiredUserIds = desiredStatuses.map((e) => e.userId).toSet();

    for (var entry in desiredStatuses) {
      final existing = existingStatuses[entry.userId];
      final existingId = existing != null ? _getId(existing, ['user_day_status_id', 'id']) : 0;
      
      final payload = {
        'user_id': entry.userId,
        'work_date': draft.workDate,
        'day_status': entry.status, // React maps 'off_morning', etc.
        'status_source': 'manual',
        'status_reason': entry.status,
      };

      try {
        if (existingId > 0) {
          await dio.patch('${AppEndpoints.userDayStatus}/$existingId', data: payload);
        } else {
          await dio.post(AppEndpoints.userDayStatus, data: payload);
        }
      } catch (_) {}
    }

    // 4. Delete removed statuses
    for (var existing in existingStatuses.values) {
      final uid = int.tryParse(existing['user_id']?.toString() ?? '0') ?? 0;
      if (uid > 0 && !desiredUserIds.contains(uid)) {
        final existingId = _getId(existing, ['user_day_status_id', 'id']);
        if (existingId > 0) {
          try {
            await dio.delete('${AppEndpoints.userDayStatus}/$existingId');
          } catch (_) {}
        }
      }
    }

    return draft;
  }

  Future<Map<String, dynamic>> getMonthlyOverview(String fromDate, String toDate) async {
    final personnel = await _getPersonnel();
    final markedDates = <String, bool>{};
    final statusesByDate = <String, Map<int, String>>{};

    // 1. Fetch attendance daily records
    try {
      final res = await dio.get(AppEndpoints.attendanceDailyRecords, queryParameters: {
        'start_date': fromDate,
        'end_date': toDate,
        'limit': 1000
      });
      final list = _extractList(res.data);
      for (var e in list) {
        if (e['delete_flag'] != true) {
          final d = (e['work_date'] ?? '').toString();
          if (d.length >= 10) {
            markedDates[d.substring(0, 10)] = true;
          }
        }
      }
    } catch (_) {}

    // 2. Fetch user day statuses
    try {
      final res = await dio.get(AppEndpoints.userDayStatus, queryParameters: {
        'start_date': fromDate,
        'end_date': toDate,
        'limit': 5000
      });
      final list = _extractList(res.data);
      for (var s in list) {
        if (s['delete_flag'] != true && s['user_id'] != null) {
          final uid = int.tryParse(s['user_id'].toString()) ?? 0;
          final d = (s['work_date'] ?? '').toString();
          if (uid > 0 && d.length >= 10) {
            final dateKey = d.substring(0, 10);
            String status = 'working';
            if (s['day_status'] == 'off_morning') status = 'off_morning';
            else if (s['day_status'] == 'off_afternoon') status = 'off_afternoon';
            else if (s['day_status'] == 'off_full' || s['day_status'] == 'half_day') status = 'off_full';
            
            if (status != 'working') {
              statusesByDate.putIfAbsent(dateKey, () => {})[uid] = status;
            }
          }
        }
      }
    } catch (_) {}

    return {
      'personnel': personnel,
      'markedDates': markedDates,
      'statusesByDate': statusesByDate,
    };
  }
}
