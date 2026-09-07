import 'package:flutter/material.dart';

import '../data/providers.dart';
import '../models/provider.dart';
import 'provider_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String query = '';

  List<Provider> get filteredProviders {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) return providers;

    return providers.where((provider) {
      final searchableText = [
        provider.name,
        provider.type,
        provider.specialty,
        provider.location,
      ].join(' ').toLowerCase();

      return searchableText.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search box
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'Search healthcare providers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Healthcare Providers',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            // Provider list
            Expanded(
              child: filteredProviders.isEmpty
                  ? const Center(child: Text('No providers found'))
                  : ListView.builder(
                      itemCount: filteredProviders.length,
                      itemBuilder: (context, index) {
                        final provider = filteredProviders[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                provider.type == 'Doctor'
                                    ? Icons.person
                                    : Icons.local_hospital,
                              ),
                            ),
                            title: Text(
                              provider.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(provider.specialty),
                                Text(provider.location),
                                Text(
                                  '${provider.rating.toStringAsFixed(1)} • '
                                  '${provider.reviewCount} reviews',
                                ),
                                Text(
                                  'Consultation: ৳${provider.price.toStringAsFixed(0)}',
                                ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProviderDetailScreen(provider: provider),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
