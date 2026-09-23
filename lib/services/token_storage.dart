import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _key = 'jwt_token';

  // 💾 Save the token after a successful login
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  // 🔍 Retrieve the token to check if the user is logged in
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  // 🚪 Clear the token when the user logs out
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
