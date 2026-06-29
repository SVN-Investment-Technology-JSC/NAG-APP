class VehicleMaintenanceComment {
  final String id;
  final int userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? parentId;

  VehicleMaintenanceComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.parentId,
  });

  factory VehicleMaintenanceComment.fromJson(Map<String, dynamic> json) {
    return VehicleMaintenanceComment(
      id: json['id'] as String,
      userId: json['user_id'] as int,
      userName: json['user_name'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      parentId: json['parent_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'parent_id': parentId,
  };
}
