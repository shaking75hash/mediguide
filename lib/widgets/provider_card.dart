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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5EAE6)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                width: 64,
                height: 72,
                child: provider.imageUrl.isEmpty
                    ? _DoctorImagePlaceholder()
                    : Image.network(
                        provider.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _DoctorImagePlaceholder();
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _DoctorImagePlaceholder();
                        },
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    provider.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Color(0xFF84918A),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          provider.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF84918A),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (provider.price > 0) ...[
                    const SizedBox(height: 5),
                    Text(
                      '৳${provider.price.toStringAsFixed(0)} consultation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF315F45),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        provider.reviewCount > 0
                            ? Icons.star_rounded
                            : Icons.rate_review_outlined,
                        color: provider.reviewCount > 0
                            ? const Color(0xFFE4A93B)
                            : const Color(0xFF84918A),
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        provider.reviewCount > 0
                            ? '${provider.rating.toStringAsFixed(1)} · ${provider.reviewCount} reviews'
                            : 'Not rated yet',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF84918A)),
          ],
        ),
      ),
    );
  }
}

class _DoctorImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F0EB),
      child: const Icon(
        Icons.medical_services_outlined,
        color: Color(0xFF4A7C59),
        size: 28,
      ),
    );
  }
}
