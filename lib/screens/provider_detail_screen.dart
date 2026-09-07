import 'package:flutter/material.dart';

import '../models/provider.dart';

class ProviderDetailScreen extends StatelessWidget {
  final Provider provider;

  const ProviderDetailScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: const Text('Provider details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Image.network(
                    provider.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.blue.shade50,
                      child: const Icon(
                        Icons.local_hospital,
                        color: Colors.blue,
                        size: 54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                provider.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123A6B),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                '${provider.type} • ${provider.specialty}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    icon: Icons.star,
                    color: Colors.amber,
                    value: provider.rating.toStringAsFixed(1),
                    label: '${provider.reviewCount} reviews',
                  ),
                  _SummaryItem(
                    icon: Icons.location_on,
                    color: Colors.blue,
                    value: provider.location,
                    label: 'Location',
                  ),
                  _SummaryItem(
                    icon: Icons.payments,
                    color: Colors.green,
                    value: '৳${provider.price.toStringAsFixed(0)}',
                    label: 'Consultation',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Contact information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF123A6B),
              ),
            ),
            const SizedBox(height: 10),
            _InfoTile(icon: Icons.email_outlined, text: provider.email),
            _InfoTile(icon: Icons.phone_outlined, text: provider.phone),
            _InfoTile(
              icon: Icons.schedule_outlined,
              text: provider.workingHours,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appointment request noted for this demo.'),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Book appointment'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blue),
      title: Text(text),
    );
  }
}
