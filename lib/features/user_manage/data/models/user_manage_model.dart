class UserManageModel {
  final int userId;
  final String userFullName;
  final String username;
  final String userEmail;
  final String userPhoneNumber;
  final String? userAddress;
  final String role;
  final String? userJoinDate;
  final String? userWorkShift;
  final String? userStatus;

  UserManageModel({
    required this.userId,
    required this.userFullName,
    required this.username,
    required this.userEmail,
    required this.userPhoneNumber,
    this.userAddress,
    required this.role,
    this.userJoinDate,
    this.userWorkShift,
    this.userStatus,
  });

  factory UserManageModel.fromJson(Map<String, dynamic> json) {
    return UserManageModel(
      userId: json['user_id'] ?? 0,
      userFullName: json['user_full_name'] ?? '',
      username: json['username'] ?? '',
      userEmail: json['user_email'] ?? '',
      userPhoneNumber: json['user_phone_number'] ?? '',
      userAddress: json['user_address'],
      role: json['role'] ?? 'user',
      userJoinDate: json['user_join_date'],
      userWorkShift: json['user_work_shift'],
      userStatus: json['user_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_full_name': userFullName,
      'username': username,
      'user_email': userEmail,
      'user_phone_number': userPhoneNumber,
      'user_address': userAddress,
      'role': role,
      'user_join_date': userJoinDate,
      'user_work_shift': userWorkShift,
      'user_status': userStatus,
    };
  }
}
