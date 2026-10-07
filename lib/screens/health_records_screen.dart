import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _healthInk = Color(0xFF183B31);
const _healthGreen = Color(0xFF347452);
const _healthMuted = Color(0xFF73847C);
const _healthLine = Color(0xFFE4EBE6);

double? calculateBmi(double? weightKg, double? heightCm) {
  if (weightKg == null ||
      heightCm == null ||
      weightKg <= 0 ||
      heightCm <= 0) {
    return null;
  }
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

class HealthRecordsScreen extends StatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  List<dynamic> _records = [];
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getHealthRecords(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(results[0] as Map);
        _records = results[1] as List<dynamic>;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading health data: $error');
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _editHealthDetails() async {
    final bloodGroupController = TextEditingController(
      text: _profile['blood_group']?.toString() ?? '',
    );
    final heightController = TextEditingController(
      text: _profile['height_cm']?.toString() ?? '',
    );
    final weightController = TextEditingController(
      text: _profile['weight_kg']?.toString() ?? '',
    );
    final historyController = TextEditingController(
      text: _profile['medical_history']?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFCFDFB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Text(
            'Health profile',
            style: TextStyle(
              color: _healthInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _validBloodGroup(
                        bloodGroupController.text,
                      ),
                      decoration: _inputDecoration(
                        'Blood group',
                        Icons.bloodtype_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A+', child: Text('A+')),
                        DropdownMenuItem(value: 'A-', child: Text('A−')),
                        DropdownMenuItem(value: 'B+', child: Text('B+')),
                        DropdownMenuItem(value: 'B-', child: Text('B−')),
                        DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                        DropdownMenuItem(value: 'AB-', child: Text('AB−')),
                        DropdownMenuItem(value: 'O+', child: Text('O+')),
                        DropdownMenuItem(value: 'O-', child: Text('O−')),
                      ],
                      onChanged: (value) =>
                          bloodGroupController.text = value ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: heightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              'Height (cm)',
                              Icons.height_rounded,
                            ),
                            validator: (value) => _measurementError(
                              value,
                              min: 30,
                              max: 300,
                              label: 'Height',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration(
                              'Weight (kg)',
                              Icons.monitor_weight_outlined,
                            ),
                            validator: (value) => _measurementError(
                              value,
                              min: 1,
                              max: 500,
                              label: 'Weight',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: historyController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: _inputDecoration(
                        'Brief medical history',
                        Icons.notes_rounded,
                      ).copyWith(
                        hintText: 'Conditions, allergies, or important notes',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Only share information you are comfortable storing in your account.',
                      style: TextStyle(
                        color: _healthMuted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final updated = await ApiService.updateProfile(
                          name: _profile['name']?.toString() ?? 'User',
                          bloodGroup: bloodGroupController.text.trim().isEmpty
                              ? null
                              : bloodGroupController.text.trim(),
                          heightCm: _parseOptional(heightController.text),
                          weightKg: _parseOptional(weightController.text),
                          medicalHistory:
                              historyController.text.trim().isEmpty
                              ? null
                              : historyController.text.trim(),
                        );
                        if (!mounted || !dialogContext.mounted) return;
                        setState(() => _profile = updated);
                        Navigator.pop(dialogContext);
                        _showMessage('Health profile saved.');
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Could not save: $error')),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _healthGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save details'),
            ),
          ],
        ),
      ),
    );
    bloodGroupController.dispose();
    heightController.dispose();
    weightController.dispose();
    historyController.dispose();
  }

  String? _validBloodGroup(String value) {
    const valid = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'};
    return valid.contains(value) ? value : null;
  }

  String? _measurementError(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim());
    if (number == null || number < min || number > max) {
      return '$label must be between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)}';
    }
    return null;
  }

  double? _parseOptional(String value) =>
      value.trim().isEmpty ? null : double.tryParse(value.trim());

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _healthGreen, size: 20),
      filled: true,
      fillColor: const Color(0xFFF5F8F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _healthLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _healthLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _healthGreen, width: 1.5),
      ),
    );
  }

  void _showAddRecordDialog() {
    final bpCtrl = TextEditingController();
    final sugarCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFCFDFB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: const Text(
            'Add a measurement',
            style: TextStyle(
              color: _healthInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: bpCtrl,
                      decoration: _inputDecoration(
                        'Blood pressure (e.g. 120/80)',
                        Icons.favorite_border_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: sugarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Blood sugar (mmol/L)',
                        Icons.water_drop_outlined,
                      ),
                      validator: (value) => _measurementError(
                        value,
                        min: 0,
                        max: 100,
                        label: 'Blood sugar',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration(
                        'Weight (kg)',
                        Icons.monitor_weight_outlined,
                      ),
                      validator: (value) => _measurementError(
                        value,
                        min: 1,
                        max: 500,
                        label: 'Weight',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: _inputDecoration(
                        'Notes',
                        Icons.notes_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await ApiService.saveHealthRecord(
                          bp: _emptyToNull(bpCtrl.text),
                          sugar: _parseOptional(sugarCtrl.text),
                          weight: _parseOptional(weightCtrl.text),
                          notes: _emptyToNull(notesCtrl.text),
                        );
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadHealthData();
                        _showMessage('Measurement added.');
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Could not save: $error')),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _healthGreen,
                foregroundColor: Colors.white,
              ),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save measurement'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      bpCtrl.dispose();
      sugarCtrl.dispose();
      weightCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double? _numeric(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _bmiLabel(double bmi) {
    if (bmi < 18.5) return 'Below adult reference range';
    if (bmi < 25) return 'Within adult reference range';
    if (bmi < 30) return 'Above adult reference range';
    return 'High adult reference range';
  }

  @override
  Widget build(BuildContext context) {
    final height = _numeric(_profile['height_cm']);
    final profileWeight = _numeric(_profile['weight_kg']);
    final latestRecordWeight = _records.isEmpty
        ? null
        : _numeric(_records.first['weight']);
    final weight = profileWeight ?? latestRecordWeight;
    final bmi = calculateBmi(weight, height);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F5),
        title: const Text('My health'),
        actions: [
          IconButton(
            tooltip: 'Edit health details',
            onPressed: _isLoading ? null : _editHealthDetails,
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _healthGreen),
              )
            : _loadFailed
            ? _buildLoadError()
            : RefreshIndicator(
                onRefresh: _loadHealthData,
                color: _healthGreen,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _buildGreeting(),
                    const SizedBox(height: 18),
                    _buildBmiCard(bmi, height, weight),
                    const SizedBox(height: 14),
                    _buildHealthProfileCard(),
                    const SizedBox(height: 26),
                    _buildRecordsHeader(),
                    const SizedBox(height: 12),
                    if (_records.isEmpty)
                      _buildEmptyRecords()
                    else
                      ..._records.map(_buildRecordCard),
                    const SizedBox(height: 24),
                    const Text(
                      'BMI is a general screening measure, not a diagnosis. Adult reference ranges may not apply to children, pregnancy, or every individual.',
                      style: TextStyle(
                        color: _healthMuted,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F8F5),
            border: Border(top: BorderSide(color: _healthLine)),
          ),
          child: FilledButton.icon(
            onPressed: _isLoading || _loadFailed ? null : _showAddRecordDialog,
            style: FilledButton.styleFrom(
              backgroundColor: _healthGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add measurement',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final name = _profile['name']?.toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name == null || name.isEmpty ? 'Your health, in one place' : 'Hello, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _healthInk,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Keep your key details and measurements up to date.',
          style: TextStyle(color: _healthMuted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBmiCard(double? bmi, double? height, double? weight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF234E3B), Color(0xFF4A8060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: _healthGreen.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.monitor_weight_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Body Mass Index',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const Text(
                'BMI',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bmi == null ? '--' : bmi.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 43,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    bmi == null
                        ? 'Add height and weight to calculate'
                        : _bmiLabel(bmi),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _measurementSummary('Height', height, 'cm'),
                _divider(),
                _measurementSummary('Weight', weight, 'kg'),
                const Spacer(),
                TextButton(
                  onPressed: _editHealthDetails,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 34),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _measurementSummary(String label, double? value, String unit) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value == null ? '—' : '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 30,
    margin: const EdgeInsets.symmetric(horizontal: 11),
    color: Colors.white.withValues(alpha: 0.25),
  );

  Widget _buildHealthProfileCard() {
    final bloodGroup = _profile['blood_group']?.toString();
    final history = _profile['medical_history']?.toString();
    final hasHistory = history != null && history.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _healthLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Health profile',
                  style: TextStyle(
                    color: _healthInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _editHealthDetails,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(foregroundColor: _healthGreen),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _detailTile(
                icon: Icons.bloodtype_outlined,
                title: 'Blood group',
                value: bloodGroup == null || bloodGroup.isEmpty
                    ? 'Not added'
                    : bloodGroup,
              ),
              const SizedBox(width: 10),
              _detailTile(
                icon: Icons.medical_information_outlined,
                title: 'Medical history',
                value: hasHistory ? 'Added' : 'Not added',
              ),
            ],
          ),
          if (hasHistory) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                history,
                style: const TextStyle(
                  color: _healthMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8F5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _healthGreen, size: 19),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _healthMuted, fontSize: 10),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _healthInk,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Measurements',
          style: TextStyle(
            color: _healthInk,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${_records.length} record${_records.length == 1 ? '' : 's'}',
          style: const TextStyle(color: _healthMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecordCard(dynamic record) {
    final parts = <String>[];
    if (record['bp'] != null) parts.add('BP ${record['bp']}');
    if (record['sugar'] != null) parts.add('Sugar ${record['sugar']} mmol/L');
    if (record['weight'] != null) parts.add('${record['weight']} kg');
    final notes = record['notes']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _healthLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2EC),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: _healthGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['date']?.toString() ?? 'Health measurement',
                  style: const TextStyle(
                    color: _healthInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  parts.isEmpty ? 'No measurements entered' : parts.join('  ·  '),
                  style: const TextStyle(
                    color: _healthMuted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (notes != null && notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    notes,
                    style: const TextStyle(
                      color: _healthMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRecords() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _healthLine),
      ),
      child: const Column(
        children: [
          Icon(Icons.note_add_outlined, size: 32, color: _healthGreen),
          SizedBox(height: 8),
          Text(
            'No measurements yet',
            style: TextStyle(
              color: _healthInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add blood pressure, sugar, or a weight reading to start your timeline.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _healthMuted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _healthGreen, size: 38),
            const SizedBox(height: 12),
            const Text(
              'Could not load your health details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _healthInk,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadHealthData,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
