import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();
  static const String _activeRoleKey = 'mediguide_active_role';
  static const String _patientKey = 'mediguide_patient_token';
  static const String _doctorKey = 'mediguide_doctor_token';
  static const String _legacyAdminKey = 'mediguide_admin_token';

  static Future<void> saveToken(String token, {String role = 'patient'}) async =>
      _storage.write(key: _keyForRole(role), value: token);

  static Future<String?> getToken({String role = 'patient'}) =>
      _storage.read(key: _keyForRole(role));

  static Future<void> clearToken({String role = 'patient'}) =>
      _storage.delete(key: _keyForRole(role));

  static Future<void> clearAll() async {
    await _storage.delete(key: _patientKey);
    await _storage.delete(key: _doctorKey);
    await _storage.delete(key: _legacyAdminKey);
    await _storage.delete(key: _activeRoleKey);
  }

  static Future<void> saveActiveRole(String role) =>
      _storage.write(key: _activeRoleKey, value: role);

  static Future<String?> getActiveRole() =>
      _storage.read(key: _activeRoleKey);

  static Future<void> clearActiveRole() =>
      _storage.delete(key: _activeRoleKey);

  static String _keyForRole(String role) => switch (role) {
    'doctor' => _doctorKey,
    _ => _patientKey,
  };
}
