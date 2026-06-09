class SkillModel {
  final int id;
  final String name;
  final String? description;

  SkillModel({
    required this.id,
    required this.name,
    this.description,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    return SkillModel(
      id: json['skill_id'] ?? 0,
      name: json['skill_name'] ?? '',
      description: json['skill_description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'skill_id': id,
      'skill_name': name,
      'skill_description': description,
    };
  }

  SkillModel copyWith({
    int? id,
    String? name,
    String? description,
  }) {
    return SkillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
}
