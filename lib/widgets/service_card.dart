import 'package:flutter/material.dart';

class ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const ServiceCard({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(icon, size: 35, color: Colors.blue),

          const SizedBox(height: 8),

          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
