class DepartmentModel {
  final int id;
  final String name;
  final String? description;
  final int? rootId;
  final int? managerId;

  DepartmentModel({
    required this.id,
    required this.name,
    this.description,
    this.rootId,
    this.managerId,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['department_id'] ?? 0,
      name: json['department_name'] ?? '',
      description: json['department_description'],
      rootId: json['department_root'] != null ? int.tryParse(json['department_root'].toString()) : null,
      managerId: json['manager_id'] != null ? int.tryParse(json['manager_id'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'department_id': id,
      'department_name': name,
      'department_description': description,
      'department_root': rootId,
      'manager_id': managerId,
    };
  }

  DepartmentModel copyWith({
    int? id,
    String? name,
    String? description,
    int? rootId,
    int? managerId,
  }) {
    return DepartmentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rootId: rootId ?? this.rootId,
      managerId: managerId ?? this.managerId,
    );
  }
}
