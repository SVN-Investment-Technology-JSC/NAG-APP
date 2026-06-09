class UserAssignmentModel {
  final int id;
  final int userId;
  final int departmentId;
  final int? skillId;
  final String? userFullName;
  final String? departmentName;
  final String? skillName;

  UserAssignmentModel({
    required this.id,
    required this.userId,
    required this.departmentId,
    this.skillId,
    this.userFullName,
    this.departmentName,
    this.skillName,
  });

  factory UserAssignmentModel.fromJson(Map<String, dynamic> json) {
    return UserAssignmentModel(
      id: json['user_assignment_id'] ?? json['assignment_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      departmentId: json['department_id'] ?? 0,
      skillId: json['skill_id'],
      userFullName: json['user_full_name'] ?? json['user']?['user_full_name'],
      departmentName: json['department_name'] ?? json['department']?['department_name'],
      skillName: json['skill_name'] ?? json['skill']?['skill_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'user_assignment_id': id,
      'user_id': userId,
      'department_id': departmentId,
      if (skillId != null) 'skill_id': skillId,
    };
  }

  UserAssignmentModel copyWith({
    int? id,
    int? userId,
    int? departmentId,
    int? skillId,
    String? userFullName,
    String? departmentName,
    String? skillName,
  }) {
    return UserAssignmentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      departmentId: departmentId ?? this.departmentId,
      skillId: skillId ?? this.skillId,
      userFullName: userFullName ?? this.userFullName,
      departmentName: departmentName ?? this.departmentName,
      skillName: skillName ?? this.skillName,
    );
  }
}
