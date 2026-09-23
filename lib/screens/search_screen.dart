import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'doctor_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.searchDoctors(query);
      if (mounted) setState(() => _results = data);
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search doctors, specialties...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _performSearch,
        ),
        backgroundColor: Colors.blue.shade700,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty && _searchController.text.isNotEmpty
          ? const Center(child: Text('No doctors found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final doctor = _results[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(
                        Icons.medical_services,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    title: Text(doctor['name']),
                    subtitle: Text(
                      '${doctor['specialty']} • ${doctor['location']}',
                    ),
                    trailing: Text('\$${doctor['consultation_fee']}'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorProfileScreen(doctor: doctor),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
