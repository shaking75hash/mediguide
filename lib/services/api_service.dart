import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'token_storage.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static Future<http.Response> _sendAuthenticatedJson({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Your session has ended. Please sign in again.');
    }

    final request = http.Request(method, uri)
      ..headers.addAll(headers)
      ..headers['Authorization'] = 'Bearer ${token.trim()}'
      ..headers['Content-Type'] = 'application/json'
      ..body = body;
    debugPrint('$method ${uri.path}: bearer authorization attached.');
    return http.Response.fromStream(await request.send());
  }

  // Function to fetch all doctors
  static Future<List<dynamic>> getDoctors() async {
    try {
      // 1. Send the GET request
      final response = await http.get(Uri.parse('$baseUrl/doctors'));

      // 2. Check if the request was successful (Status Code 200)
      if (response.statusCode == 200) {
        // 3. Convert the JSON string into a Dart List
        final List<dynamic> data = json.decode(response.body);
        return data;
      } else {
        // If the server returns an error
        throw Exception('Failed to load doctors: ${response.statusCode}');
      }
    } catch (e) {
      // If there's a network error or server is down
      throw Exception('Error connecting to server: $e');
    }
  }

  static Future<List<dynamic>> searchDoctors(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/doctors/search')
          .replace(queryParameters: {'query': query.trim()}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to search doctors');
    }
  }

  static Future<List<dynamic>> getMedicalServices() async {
    final response = await http.get(Uri.parse('$baseUrl/medical-services'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load medical services');
    }
  }

  static Future<Map<String, dynamic>> getDoctorTrust(int doctorId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/doctors/$doctorId/trust'),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load trust profile');
  }

  static Future<Map<String, dynamic>> getDoctorInsights(int doctorId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/doctors/$doctorId/insights'),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load insights');
  }

  // REGISTER a new user
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['detail'] ?? 'Registration failed');
    }
  }

  // LOGIN an existing user
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['detail'] ?? 'Login failed');
    }
  }

  // 🔐 Call a PROTECTED endpoint, attaching the JWT from the wallet
  static Future<Map<String, dynamic>> getMe() async {
    final token = await TokenStorage.getToken();

    if (token == null) {
      throw Exception('Not logged in');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      await TokenStorage.clearToken();
      throw Exception('Session expired. Please login again.');
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? bloodGroup,
    double? heightCm,
    double? weightKg,
    String? medicalHistory,
  }) async {
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw Exception('Not logged in');
    }
    final response = await _sendAuthenticatedJson(
      method: 'PUT',
      uri: Uri.parse('$baseUrl/me'),
      headers: {'Authorization': '******', 'Content-Type': 'application/json'},
      body: json.encode({
        'name': name.trim(),
        'blood_group': bloodGroup,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'medical_history': medicalHistory,
      }),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    final error = json.decode(response.body);
    throw Exception(error['detail'] ?? 'Could not update profile');
  }

  // 🚪 Throw away the keycard
  static Future<void> logout() async {
    await TokenStorage.clearToken();
  }

  // Get available slots
  static Future<List<String>> getSlots(int doctorId, String date) async {
    final response = await http.get(
      Uri.parse('$baseUrl/doctors/$doctorId/slots?date=$date'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['slots'] ?? []);
    }
    throw Exception('Could not load slots');
  }

  // Book (protected)
  static Future<Map<String, dynamic>> bookAppointment(
    int doctorId,
    String date,
    String time,
  ) async {
    final token = await TokenStorage.getToken();
    final response = await http.post(
      Uri.parse(
        '$baseUrl/appointments?doctor_id=$doctorId&date=$date&time=$time',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 201) return json.decode(response.body);
    final err = json.decode(response.body);
    throw Exception(err['detail'] ?? 'Booking failed');
  }

  // My appointments (protected)
  static Future<List<dynamic>> getMyAppointments() async {
    final token = await TokenStorage.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/appointments/mine'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Could not load appointments');
  }

  static Future<void> cancelAppointment(int appointmentId) async {
    final token = await TokenStorage.getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/appointments/$appointmentId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      final err = json.decode(response.body);
      throw Exception(err['detail'] ?? 'Cancellation failed');
    }
  }

  static Future<List<dynamic>> getAppointmentCareNotes() async {
    final token = await TokenStorage.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/appointments/care-notes'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return json.decode(response.body);
    final error = json.decode(response.body);
    throw Exception(error['detail'] ?? 'Could not load care notes');
  }

  static Future<void> saveAppointmentCareNotes({
    required int appointmentId,
    required String? doctorAdvice,
    required String? revisitDate,
    required String? revisitNotes,
  }) async {
    final token = await TokenStorage.getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/appointments/$appointmentId/care-notes'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'doctor_advice': doctorAdvice,
        'revisit_date': revisitDate,
        'revisit_notes': revisitNotes,
      }),
    );
    if (response.statusCode == 200) return;
    final error = json.decode(response.body);
    throw Exception(error['detail'] ?? 'Could not save care notes');
  }

  static Future<void> saveHealthRecord({
    String? bp,
    double? sugar,
    double? weight,
    String? notes,
  }) async {
    final token = await TokenStorage.getToken();
    final body = {
      if (bp != null) 'blood_pressure': bp,
      if (sugar != null) 'blood_sugar': sugar,
      if (weight != null) 'weight': weight,
      if (notes != null) 'notes': notes,
    };

    final response = await _sendAuthenticatedJson(
      method: 'POST',
      uri: Uri.parse('$baseUrl/health-records'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );
    if (response.statusCode != 201) throw Exception('Failed to save record');
  }

  static Future<List<dynamic>> getHealthRecords() async {
    final token = await TokenStorage.getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/health-records'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load records');
  }

  static Future<Map<String, dynamic>> getPriceComparison(int serviceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/price-comparison')
          .replace(queryParameters: {'service_id': serviceId.toString()}),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to load price comparison');
  }
}
