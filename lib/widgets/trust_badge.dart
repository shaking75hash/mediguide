import 'package:flutter/material.dart';

class TrustBadge extends StatelessWidget {
  final double score;
  final int verifiedReviews;
  final bool showBreakdown;

  const TrustBadge({
    super.key,
    required this.score,
    required this.verifiedReviews,
    this.showBreakdown = false,
  });

  Color _getColor(double s) {
    if (s >= 4.5) return Colors.green.shade700;
    if (s >= 3.5) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  String _getLabel(double s) {
    if (s >= 4.5) return 'Excellent';
    if (s >= 3.5) return 'Good';
    if (s >= 2.5) return 'Fair';
    return 'Needs Improvement';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                '${score.toStringAsFixed(1)} / 5.0',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
          Text(_getLabel(score), style: TextStyle(fontSize: 12, color: color)),
          if (verifiedReviews > 0)
            Text(
              '$verifiedReviews verified reviews',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
