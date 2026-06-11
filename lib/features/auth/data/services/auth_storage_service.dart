import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  static const _keyAccessToken = 'access_token';
  static const _keyUserId = 'user_id';
  static const _keyUserFullName = 'user_full_name';
  static const _keyUserRole = 'user_role';
  static const _keyIsLoggedIn = 'is_logged_in';

  static const _keyRememberMe = 'remember_me';
  static const _keyRememberedUsername = 'remembered_username';
  static const _keyRememberedPassword = 'remembered_password';

  Future<void> saveSession({
    required String accessToken,
    required int userId,
    required String fullName,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUserFullName, fullName);
    await prefs.setString(_keyUserRole, role);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, token);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserFullName);
    await prefs.remove(_keyUserRole);
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyAccessToken);
    final loggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

    return loggedIn && token != null && token.isNotEmpty;
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  Future<String?> getUserFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserFullName);
  }

  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  Future<void> saveRememberedLogin({
    required bool rememberMe,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_keyRememberMe, rememberMe);

    if (rememberMe) {
      await prefs.setString(_keyRememberedUsername, username);
      await prefs.setString(_keyRememberedPassword, password);
    } else {
      await prefs.remove(_keyRememberedUsername);
      await prefs.remove(_keyRememberedPassword);
    }
  }

  Future<Map<String, dynamic>> getRememberedLogin() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'rememberMe': prefs.getBool(_keyRememberMe) ?? false,
      'username': prefs.getString(_keyRememberedUsername) ?? '',
      'password': prefs.getString(_keyRememberedPassword) ?? '',
    };
  }
}
