import 'package:flutter/material.dart';

class SmartDecisionPanel extends StatelessWidget {
  final Map<String, dynamic> insights;

  const SmartDecisionPanel({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final cost = insights['estimated_cost'];
    final wait = insights['predicted_wait'];
    final quality = insights['quality_comparison'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'Smart Insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildRow(
            Icons.attach_money,
            Colors.green.shade700,
            'Estimated Visit Cost',
            '\$${cost['total_estimate']} '
                '(Consultation: \$${cost['consultation']} + '
                'Diagnostics: \$${cost['avg_diagnostics']})',
          ),
          const SizedBox(height: 12),
          _buildRow(
            Icons.access_time,
            wait['level'] == 'low'
                ? Colors.green.shade700
                : wait['level'] == 'moderate'
                ? Colors.orange.shade700
                : Colors.red.shade700,
            'Predicted Wait Time',
            '${wait['time']} (${wait['upcoming_appointments']} '
                'appointments this week)',
          ),
          const SizedBox(height: 12),
          _buildRow(
            Icons.bar_chart,
            quality['verdict'] == 'Above Average'
                ? Colors.green.shade700
                : quality['verdict'] == 'Average'
                ? Colors.orange.shade700
                : Colors.red.shade700,
            'Quality vs Peers',
            '${quality['doctor_score']}/5.0 - ${quality['verdict']} '
                '(${quality['verified_reviews']} verified reviews)',
          ),
        ],
      ),
    );
  }

  Widget _buildRow(IconData icon, Color color, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
