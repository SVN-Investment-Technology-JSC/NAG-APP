class WorkModel {
  final int id;
  final String name;
  final String? description;
  final int? rootId;

  WorkModel({
    required this.id,
    required this.name,
    this.description,
    this.rootId,
  });

  factory WorkModel.fromJson(Map<String, dynamic> json) {
    return WorkModel(
      id: json['work_id'] ?? 0,
      name: json['work_name'] ?? '',
      description: json['work_description'],
      rootId: json['work_root'] != null ? int.tryParse(json['work_root'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'work_id': id,
      'work_name': name,
      'work_description': description,
      'work_root': rootId,
    };
  }

  WorkModel copyWith({
    int? id,
    String? name,
    String? description,
    int? rootId,
  }) {
    return WorkModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      rootId: rootId ?? this.rootId,
    );
  }
}
