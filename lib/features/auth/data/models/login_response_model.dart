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
      userId: json['user_id'] ?? 0,
      fullName: json['user_full_name'] ?? '',
      roleId: json['role_id'] ?? 0,
      role: json['role'] ?? '',
      accessToken: json['accessToken'] ?? '',
    );
  }
}