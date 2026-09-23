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

  @override
  void initState() {
    super.initState();
    _loadTrust();
    _loadInsights();
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
    final fee = widget.doctor['consultation_fee'] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.doctor['name'] ?? 'Doctor Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                        widget.doctor['name'] ?? 'Dr. Name',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.doctor['specialty'] ?? 'Specialty',
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
              widget.doctor['location'] ?? 'Not specified',
            ),
            _buildDetailRow(
              Icons.attach_money,
              'Consultation Fee',
              '\$${fee.toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              Icons.verified_user,
              'Verification',
              widget.doctor['is_verified'] == true
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
            const SizedBox(height: 20),

            // Bio / Description
            const Text(
              'About',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Experienced ${widget.doctor['specialty']} dedicated to providing high-quality healthcare services. Committed to patient well-being and modern medical practices.',
              style: const TextStyle(height: 1.5),
            ),

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
                        doctorId: widget.doctor['id'],
                        doctorName: widget.doctor['name'],
                        specialty: widget.doctor['specialty'],
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
