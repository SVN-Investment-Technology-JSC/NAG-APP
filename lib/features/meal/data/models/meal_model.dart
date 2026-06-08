class MealSlot {
  final String key; // "sang" | "trua" | "toi"
  final String label;
  final int fromH;
  final int fromM;
  final int toH;
  final int toM;

  const MealSlot({
    required this.key,
    required this.label,
    required this.fromH,
    required this.fromM,
    required this.toH,
    required this.toM,
  });
}

const mealSlots = [
  MealSlot(key: 'sang', label: 'Trưa', fromH: 11, fromM: 30, toH: 13, toM: 0),
  MealSlot(key: 'trua', label: 'Chiều', fromH: 19, fromM: 0, toH: 22, toM: 0),
  MealSlot(key: 'toi', label: 'Tối', fromH: 22, fromM: 0, toH: 23, toM: 59),
];

class DayMeals {
  bool sang;
  String? sangSource;
  bool trua;
  String? truaSource;
  bool toi;
  String? toiSource;

  DayMeals({
    this.sang = false,
    this.sangSource,
    this.trua = false,
    this.truaSource,
    this.toi = false,
    this.toiSource,
  });

  int get total => (sang ? 1 : 0) + (trua ? 1 : 0) + (toi ? 1 : 0);

  DayMeals clone() {
    return DayMeals(
      sang: sang,
      sangSource: sangSource,
      trua: trua,
      truaSource: truaSource,
      toi: toi,
      toiSource: toiSource,
    );
  }
}

/// Multi-day meal data: name → { dateStr → DayMeals }
typedef MealDataMap = Map<String, Map<String, DayMeals>>;

class Personnel {
  final int? userId;
  final String tenVT;
  final String hoTen;
  final String boPhan;

  const Personnel({
    this.userId,
    required this.tenVT,
    required this.hoTen,
    required this.boPhan,
  });

  factory Personnel.fromJson(Map<String, dynamic> json) {
    return Personnel(
      userId: json['userId'] is int
          ? json['userId']
          : (json['userId'] != null ? int.tryParse(json['userId'].toString()) : null),
      tenVT: json['tenVT']?.toString() ?? '',
      hoTen: json['hoTen']?.toString() ?? '',
      boPhan: json['boPhan']?.toString() ?? '',
    );
  }
}

class UserAssignment {
  final int userAssignmentId;
  final int userId;
  final String userFullName;
  final String? userShortName;
  final int? departmentId;
  final String? departmentName;
  final int? skillId;
  final String? skillName;
  final bool deleteFlag;

  const UserAssignment({
    required this.userAssignmentId,
    required this.userId,
    required this.userFullName,
    this.userShortName,
    this.departmentId,
    this.departmentName,
    this.skillId,
    this.skillName,
    this.deleteFlag = false,
  });

  factory UserAssignment.fromJson(Map<String, dynamic> json) {
    return UserAssignment(
      userAssignmentId: json['user_assignment_id'] is int
          ? json['user_assignment_id'] as int
          : (json['user_assignment_id'] != null ? int.tryParse(json['user_assignment_id'].toString()) ?? 0 : 0),
      userId: json['user_id'] is int
          ? json['user_id'] as int
          : (json['user_id'] != null ? int.tryParse(json['user_id'].toString()) ?? 0 : 0),
      userFullName: json['user_full_name']?.toString() ?? '',
      userShortName: json['user_short_name']?.toString(),
      departmentId: json['department_id'] is int
          ? json['department_id'] as int
          : (json['department_id'] != null ? int.tryParse(json['department_id'].toString()) : null),
      departmentName: json['department_name']?.toString(),
      skillId: json['skill_id'] is int
          ? json['skill_id'] as int
          : (json['skill_id'] != null ? int.tryParse(json['skill_id'].toString()) : null),
      skillName: json['skill_name']?.toString(),
      deleteFlag: json['delete_flag'] == true || json['delete_flag'] == 1,
    );
  }
}


