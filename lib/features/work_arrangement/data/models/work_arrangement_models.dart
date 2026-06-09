class WorkPersonnel {
  final int userId;
  final String userFullName;
  final String? userShortName;
  final int? departmentId;
  final String? departmentName;
  final int? skillId;
  final String? skillName;

  WorkPersonnel({
    required this.userId,
    required this.userFullName,
    this.userShortName,
    this.departmentId,
    this.departmentName,
    this.skillId,
    this.skillName,
  });

  factory WorkPersonnel.fromJson(Map<String, dynamic> json) {
    return WorkPersonnel(
      userId: json['user_id'] ?? 0,
      userFullName: json['user_full_name'] ?? '',
      userShortName: json['user_short_name'],
      departmentId: json['department_id'],
      departmentName: json['department_name'],
      skillId: json['skill_id'],
      skillName: json['skill_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_full_name': userFullName,
      'user_short_name': userShortName,
      'department_id': departmentId,
      'department_name': departmentName,
      'skill_id': skillId,
      'skill_name': skillName,
    };
  }
}

class WorkVehicle {
  final int vehicleId;
  final String? vehicleName;
  final String? vehicleLicensePlate;
  final int? vehicleTypeId;
  final String? vehicleTypeName;
  final String? vehicleTypeSymbol;
  final String? vehicleStatus;

  WorkVehicle({
    required this.vehicleId,
    this.vehicleName,
    this.vehicleLicensePlate,
    this.vehicleTypeId,
    this.vehicleTypeName,
    this.vehicleTypeSymbol,
    this.vehicleStatus,
  });

  factory WorkVehicle.fromJson(Map<String, dynamic> json) {
    return WorkVehicle(
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleName: json['vehicle_name'],
      vehicleLicensePlate: json['vehicle_license_plate'],
      vehicleTypeId: json['vehicle_type_id'],
      vehicleTypeName: json['vehicle_type_name'],
      vehicleTypeSymbol: json['vehicle_type_symbol'],
      vehicleStatus: json['vehicle_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehicle_id': vehicleId,
      'vehicle_name': vehicleName,
      'vehicle_license_plate': vehicleLicensePlate,
      'vehicle_type_id': vehicleTypeId,
      'vehicle_type_name': vehicleTypeName,
      'vehicle_type_symbol': vehicleTypeSymbol,
      'vehicle_status': vehicleStatus,
    };
  }
}

class PumpAssignmentItem {
  final String assignmentId;
  final int vehicleId;
  final Map<String, List<int>> roles; // 'driver', 'operator', 'hose'

  PumpAssignmentItem({
    required this.assignmentId,
    required this.vehicleId,
    required this.roles,
  });

  factory PumpAssignmentItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawRoles = json['roles'] ?? {};
    final Map<String, List<int>> parsedRoles = {};
    rawRoles.forEach((key, value) {
      if (value is List) {
        parsedRoles[key] = value.map((e) => e as int).toList();
      }
    });

    return PumpAssignmentItem(
      assignmentId: json['assignment_id'] ?? '',
      vehicleId: json['vehicle_id'] ?? 0,
      roles: parsedRoles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignment_id': assignmentId,
      'vehicle_id': vehicleId,
      'roles': roles,
    };
  }
}

class WorkAssignmentDraft {
  final String workDate;
  final List<PumpAssignmentItem> pumpAssignments;
  final String? updatedAt;

  WorkAssignmentDraft({
    required this.workDate,
    required this.pumpAssignments,
    this.updatedAt,
  });

  factory WorkAssignmentDraft.fromJson(Map<String, dynamic> json) {
    final List<dynamic> pumpList = json['pump_assignments'] ?? [];
    return WorkAssignmentDraft(
      workDate: json['work_date'] ?? '',
      pumpAssignments:
          pumpList.map((e) => PumpAssignmentItem.fromJson(e)).toList(),
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'work_date': workDate,
      'pump_assignments': pumpAssignments.map((e) => e.toJson()).toList(),
      'updated_at': updatedAt,
    };
  }
}

class MixerAssignmentItem {
  final String assignmentId;
  final int vehicleId;
  final int? userId;

  MixerAssignmentItem({
    required this.assignmentId,
    required this.vehicleId,
    this.userId,
  });

  factory MixerAssignmentItem.fromJson(Map<String, dynamic> json) {
    return MixerAssignmentItem(
      assignmentId: json['assignment_id'] ?? '',
      vehicleId: json['vehicle_id'] ?? 0,
      userId: json['user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignment_id': assignmentId,
      'vehicle_id': vehicleId,
      'user_id': userId,
    };
  }
}

class WorkMixerAssignmentDraft {
  final String workDate;
  final List<MixerAssignmentItem> mixerAssignments;
  final String? updatedAt;

  WorkMixerAssignmentDraft({
    required this.workDate,
    required this.mixerAssignments,
    this.updatedAt,
  });

  factory WorkMixerAssignmentDraft.fromJson(Map<String, dynamic> json) {
    final List<dynamic> mixerList = json['mixer_assignments'] ?? [];
    return WorkMixerAssignmentDraft(
      workDate: json['work_date'] ?? '',
      mixerAssignments:
          mixerList.map((e) => MixerAssignmentItem.fromJson(e)).toList(),
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'work_date': workDate,
      'mixer_assignments': mixerAssignments.map((e) => e.toJson()).toList(),
      'updated_at': updatedAt,
    };
  }
}

class WorkArrangementBootstrap {
  final String workDate;
  final List<WorkPersonnel> personnel;
  final List<int> halfDayUserIds;
  final List<WorkVehicle> pumpVehicles;
  final WorkAssignmentDraft pumpDraft;
  final List<WorkVehicle> mixerVehicles;
  final WorkMixerAssignmentDraft mixerDraft;

  WorkArrangementBootstrap({
    required this.workDate,
    required this.personnel,
    required this.halfDayUserIds,
    required this.pumpVehicles,
    required this.pumpDraft,
    required this.mixerVehicles,
    required this.mixerDraft,
  });

  factory WorkArrangementBootstrap.fromJson(Map<String, dynamic> json) {
    final List<dynamic> pList = json['personnel'] ?? [];
    final List<dynamic> hdList = json['half_day_user_ids'] ?? [];
    final Map<String, dynamic> pumpMap = json['pump'] ?? {};
    final Map<String, dynamic> mixerMap = json['mixer'] ?? {};

    final List<dynamic> pVList = pumpMap['vehicles'] ?? [];
    final List<dynamic> mVList = mixerMap['vehicles'] ?? [];

    return WorkArrangementBootstrap(
      workDate: json['work_date'] ?? '',
      personnel: pList.map((e) => WorkPersonnel.fromJson(e)).toList(),
      halfDayUserIds: hdList.map((e) => e as int).toList(),
      pumpVehicles: pVList.map((e) => WorkVehicle.fromJson(e)).toList(),
      pumpDraft: WorkAssignmentDraft.fromJson(pumpMap['draft'] ?? {}),
      mixerVehicles: mVList.map((e) => WorkVehicle.fromJson(e)).toList(),
      mixerDraft: WorkMixerAssignmentDraft.fromJson(mixerMap['draft'] ?? {}),
    );
  }
}

class WorkTaskItem {
  final int workId;
  final String workName;
  final int? workRoot;

  WorkTaskItem({
    required this.workId,
    required this.workName,
    this.workRoot,
  });

  factory WorkTaskItem.fromJson(Map<String, dynamic> json) {
    return WorkTaskItem(
      workId: json['work_id'] ?? 0,
      workName: json['work_name'] ?? '',
      workRoot: json['work_root'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'work_id': workId,
      'work_name': workName,
      'work_root': workRoot,
    };
  }
}

class TaskAssignmentItem {
  final String assignmentId;
  final int workId;
  final List<int> userIds;

  TaskAssignmentItem({
    required this.assignmentId,
    required this.workId,
    required this.userIds,
  });

  factory TaskAssignmentItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> uList = json['user_ids'] ?? [];
    return TaskAssignmentItem(
      assignmentId: json['assignment_id'] ?? '',
      workId: json['work_id'] ?? 0,
      userIds: uList.map((e) => e as int).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignment_id': assignmentId,
      'work_id': workId,
      'user_ids': userIds,
    };
  }
}

class WorkTaskAssignmentDraft {
  final String workDate;
  final List<TaskAssignmentItem> taskAssignments;
  final String? updatedAt;

  WorkTaskAssignmentDraft({
    required this.workDate,
    required this.taskAssignments,
    this.updatedAt,
  });

  factory WorkTaskAssignmentDraft.fromJson(Map<String, dynamic> json) {
    final List<dynamic> tList = json['task_assignments'] ?? [];
    return WorkTaskAssignmentDraft(
      workDate: json['work_date'] ?? '',
      taskAssignments:
          tList.map((e) => TaskAssignmentItem.fromJson(e)).toList(),
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'work_date': workDate,
      'task_assignments': taskAssignments.map((e) => e.toJson()).toList(),
      'updated_at': updatedAt,
    };
  }
}

class WorkTaskBootstrap {
  final String workDate;
  final List<WorkPersonnel> personnel;
  final List<WorkTaskItem> works;
  final WorkTaskAssignmentDraft draft;

  WorkTaskBootstrap({
    required this.workDate,
    required this.personnel,
    required this.works,
    required this.draft,
  });

  factory WorkTaskBootstrap.fromJson(Map<String, dynamic> json) {
    final List<dynamic> pList = json['personnel'] ?? [];
    final List<dynamic> wList = json['works'] ?? [];
    return WorkTaskBootstrap(
      workDate: json['work_date'] ?? '',
      personnel: pList.map((e) => WorkPersonnel.fromJson(e)).toList(),
      works: wList.map((e) => WorkTaskItem.fromJson(e)).toList(),
      draft: WorkTaskAssignmentDraft.fromJson(json['draft'] ?? {}),
    );
  }
}

class WorkMixSlotItem {
  final int orderId;
  final int orderNumber;
  final int userId;
  final int vehicleId;
  final String? vehicleName;
  final String vehicleLicensePlate;
  final String? vehicleTypeSymbol;
  final String shortName;
  final String code;
  final String label;

  WorkMixSlotItem({
    required this.orderId,
    required this.orderNumber,
    required this.userId,
    required this.vehicleId,
    this.vehicleName,
    required this.vehicleLicensePlate,
    this.vehicleTypeSymbol,
    required this.shortName,
    required this.code,
    required this.label,
  });

  factory WorkMixSlotItem.fromJson(Map<String, dynamic> json) {
    return WorkMixSlotItem(
      orderId: json['order_id'] ?? 0,
      orderNumber: json['order_number'] ?? 0,
      userId: json['user_id'] ?? 0,
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleName: json['vehicle_name'],
      vehicleLicensePlate: json['vehicle_license_plate'] ?? '',
      vehicleTypeSymbol: json['vehicle_type_symbol'],
      shortName: json['short_name'] ?? '',
      code: json['code'] ?? '',
      label: json['label'] ?? '',
    );
  }
}

class UserDayStatus {
  final int userId;
  final String status;

  UserDayStatus({required this.userId, required this.status});

  factory UserDayStatus.fromJson(Map<String, dynamic> json) {
    return UserDayStatus(
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      status: json['status'] ?? 'working',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'status': status,
    };
  }
}

class WorkAttendanceDraft {
  final String workDate;
  final List<UserDayStatus> userStatuses;

  WorkAttendanceDraft({required this.workDate, required this.userStatuses});

  factory WorkAttendanceDraft.fromJson(Map<String, dynamic> json) {
    return WorkAttendanceDraft(
      workDate: json['work_date'] ?? '',
      userStatuses: (json['user_statuses'] as List<dynamic>?)
              ?.map((e) => UserDayStatus.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'work_date': workDate,
      'user_statuses': userStatuses.map((e) => e.toJson()).toList(),
    };
  }
}

class WorkAttendanceBootstrap {
  final String workDate;
  final List<WorkPersonnel> personnel;
  final bool isAttendanceMarked;
  final WorkAttendanceDraft draft;

  WorkAttendanceBootstrap({
    required this.workDate,
    required this.personnel,
    required this.isAttendanceMarked,
    required this.draft,
  });
}
