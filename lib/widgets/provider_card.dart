import 'package:flutter/material.dart';

import '../models/provider.dart';

class ProviderCard extends StatelessWidget {
  final Provider provider;
  final VoidCallback? onTap;

  const ProviderCard({super.key, required this.provider, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Image.network(
                  provider.imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.blue.shade50,
                      child: const Center(
                        child: Icon(Icons.image, color: Colors.blue),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.blue.shade50,
                      child: const Icon(
                        Icons.local_hospital,
                        color: Colors.blue,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF123A6B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.type} • ${provider.specialty}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        provider.location,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                Text(
                  provider.rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${provider.reviewCount} reviews',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
