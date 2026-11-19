import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/smart_decision_panel.dart';
import '../widgets/trust_badge.dart';
import 'book_appointment_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const DoctorProfileScreen({super.key, required this.doctor});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  Map<String, dynamic>? _trustData;
  bool _loadingTrust = true;
  Map<String, dynamic>? _insights;
  bool _loadingInsights = true;
  Map<String, dynamic>? _latestDoctor;

  @override
  void initState() {
    super.initState();
    _loadDoctor();
    _loadTrust();
    _loadInsights();
  }

  Future<void> _loadDoctor() async {
    try {
      final doctor = await ApiService.getDoctorById(widget.doctor['id'] as int);
      if (mounted) setState(() => _latestDoctor = doctor);
    } catch (error) {
      debugPrint('Doctor profile refresh error: $error');
    }
  }

  Future<void> _loadTrust() async {
    try {
      final data = await ApiService.getDoctorTrust(widget.doctor['id'] as int);
      if (mounted) setState(() => _trustData = data);
    } catch (e) {
      debugPrint('Trust load error: $e');
    } finally {
      if (mounted) setState(() => _loadingTrust = false);
    }
  }

  Future<void> _loadInsights() async {
    try {
      final data = await ApiService.getDoctorInsights(
        widget.doctor['id'] as int,
      );
      if (mounted) setState(() => _insights = data);
    } catch (e) {
      debugPrint('Insights error: $e');
    } finally {
      if (mounted) setState(() => _loadingInsights = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = _latestDoctor ?? widget.doctor;
    final fee = doctor['consultation_fee'] ?? 0;
    final qualification = (doctor['qualification'] ?? '').toString().trim();

    return Scaffold(
      appBar: AppBar(title: Text(doctor['name'] ?? 'Doctor Profile')),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor['name'] ?? 'Dr. Name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          doctor['specialty'] ?? 'Specialty',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (doctor['is_sample'] == true) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Text(
                    'Demo profile only. This is fictional sample data, not a real provider.',
                    style: TextStyle(
                      color: Color(0xFF704B00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _loadingTrust
                  ? const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _trustData != null
                  ? TrustBadge(
                      score: (_trustData!['overall_score'] as num).toDouble(),
                      verifiedReviews: (_trustData!['verified_reviews'] as num)
                          .toInt(),
                    )
                  : const SizedBox.shrink(),
              const SizedBox(height: 16),
              const Divider(height: 32),

              // Details Section
              _buildDetailRow(
                Icons.location_on,
                'Location',
                doctor['location'] ?? 'Not specified',
              ),
              _buildDetailRow(
                Icons.school_outlined,
                'Qualification',
                qualification.isEmpty ? 'Not provided' : qualification,
              ),
              _buildDetailRow(
                Icons.attach_money,
                'Consultation Fee',
                '\$${fee.toStringAsFixed(2)}',
              ),
              _buildDetailRow(
                Icons.verified_user,
                'Verification',
                doctor['is_verified'] == true
                    ? 'Verified Professional'
                    : 'Pending Verification',
              ),

              const SizedBox(height: 32),

              _loadingInsights
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _insights != null
                  ? SmartDecisionPanel(insights: _insights!)
                  : const SizedBox.shrink(),
              const SizedBox(height: 40),

              // Book Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookAppointmentScreen(
                          doctorId: doctor['id'],
                          doctorName: doctor['name'],
                          specialty: doctor['specialty'],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text(
                    'Book Appointment',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
