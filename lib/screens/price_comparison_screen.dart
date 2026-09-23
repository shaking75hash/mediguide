import 'package:flutter/material.dart';

import '../services/api_service.dart';

class PriceComparisonScreen extends StatefulWidget {
  const PriceComparisonScreen({super.key});

  @override
  State<PriceComparisonScreen> createState() => _PriceComparisonScreenState();
}

class _PriceComparisonScreenState extends State<PriceComparisonScreen> {
  List<dynamic> _services = [];
  Map<String, dynamic>? _selectedService;
  List<dynamic> _comparisons = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _services = [
        {'id': 1, 'name': 'Complete Blood Count (CBC)'},
        {'id': 2, 'name': 'ECG (Electrocardiogram)'},
        {'id': 3, 'name': 'X-Ray (Chest)'},
        {'id': 4, 'name': 'Ultrasound (Abdomen)'},
        {'id': 5, 'name': 'General Consultation'},
      ];
    });
  }

  Future<void> _fetchPrices(int serviceId) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getPriceComparison(serviceId);
      if (mounted) {
        setState(() {
          _selectedService = _services.firstWhere((s) => s['id'] == serviceId);
          _comparisons = response['providers'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching prices: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load prices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('💰 Price Comparison')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Select a Service',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _services
                  .map<DropdownMenuItem<int>>(
                    (s) => DropdownMenuItem<int>(
                      value: s['id'] as int,
                      child: Text(s['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) _fetchPrices(val);
              },
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_selectedService != null && _comparisons.isEmpty)
              const Center(
                child: Text(
                  'No providers found for this service.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else if (_comparisons.isNotEmpty) ...[
              Text(
                'Prices for ${_selectedService!['name']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _comparisons.length,
                  itemBuilder: (context, index) {
                    final item = _comparisons[index];
                    final isCheapest = index == 0;
                    return Card(
                      color: isCheapest ? Colors.green.shade50 : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCheapest
                              ? Colors.green
                              : Colors.blue.shade100,
                          child: Icon(
                            Icons.medical_services,
                            color: isCheapest
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                        title: Text(item['doctor_name']),
                        subtitle: Text(
                          '${item['specialty']} • ${item['location']}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${item['price']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isCheapest
                                    ? Colors.green.shade700
                                    : Colors.black,
                              ),
                            ),
                            if (isCheapest)
                              const Text(
                                'Best Price',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
