import 'package:flutter/material.dart';

import '../services/api_service.dart';

class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  List<dynamic> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final data = await ApiService.getHealthRecords();
      if (mounted) setState(() => _records = data);
    } catch (e) {
      debugPrint('Error loading records: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddRecordDialog() {
    final bpCtrl = TextEditingController();
    final sugarCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Health Record'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: bpCtrl,
                decoration: const InputDecoration(
                  labelText: 'Blood Pressure (e.g. 120/80)',
                ),
              ),
              TextField(
                controller: sugarCtrl,
                decoration: const InputDecoration(
                  labelText: 'Blood Sugar (mmol/L)',
                ),
              ),
              TextField(
                controller: weightCtrl,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.saveHealthRecord(
                bp: bpCtrl.text,
                sugar: sugarCtrl.text.isNotEmpty
                    ? double.tryParse(sugarCtrl.text)
                    : null,
                weight: weightCtrl.text.isNotEmpty
                    ? double.tryParse(weightCtrl.text)
                    : null,
                notes: notesCtrl.text,
              );
              Navigator.pop(ctx);
              _loadRecords();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Health Records')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRecordDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const Center(child: Text('No records yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              itemBuilder: (context, index) {
                final r = _records[index];
                return Card(
                  child: ListTile(
                    title: Text('\u{1F4C5} ${r['date']}'),
                    subtitle: Text(
                      '${r['bp'] ?? 'N/A'} BP | '
                      '${r['sugar'] ?? 'N/A'} Sugar | '
                      '${r['weight'] ?? 'N/A'} kg',
                    ),
                    trailing: r['notes'] != null
                        ? const Icon(Icons.note, color: Colors.grey)
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
