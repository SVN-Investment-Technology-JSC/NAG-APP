class LoginResponseModel {
  final int userId;
  final String fullName;
  final int roleId;
  final String role;
  final String accessToken;

  LoginResponseModel({
    required this.userId,
    required this.fullName,
    required this.roleId,
    required this.role,
    required this.accessToken,
  });

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) {
    return LoginResponseModel(
      userId: _parseInt(json['user_id']),
      fullName: json['user_full_name']?.toString() ?? '',
      roleId: _parseInt(json['role_id']),
      role: json['role']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}