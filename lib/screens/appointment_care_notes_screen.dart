import 'package:flutter/material.dart';

import '../services/api_service.dart';

class AppointmentCareNotesScreen extends StatefulWidget {
  const AppointmentCareNotesScreen({super.key});

  @override
  State<AppointmentCareNotesScreen> createState() =>
      _AppointmentCareNotesScreenState();
}

class _AppointmentCareNotesScreenState
    extends State<AppointmentCareNotesScreen> {
  static const _ink = Color(0xFF183B31);
  static const _green = Color(0xFF347452);
  static const _muted = Color(0xFF73847C);
  static const _line = Color(0xFFE4EBE6);
  static const _background = Color(0xFFF6F8F5);

  List<dynamic> _visits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final visits = await ApiService.getAppointmentCareNotes();
      if (mounted) setState(() => _visits = visits);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCareNote(Map<dynamic, dynamic> visit) async {
    final adviceController = TextEditingController(
      text: visit['doctor_advice']?.toString() ?? '',
    );
    final revisitNotesController = TextEditingController(
      text: visit['revisit_notes']?.toString() ?? '',
    );
    final existingDate = DateTime.tryParse(
      visit['revisit_date']?.toString() ?? '',
    );
    final visitDate = DateTime.parse(
      visit['appointment_date'].toString(),
    );
    var revisitRecommended = existingDate != null;
    DateTime? revisitDate = existingDate;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogBuilderContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFCFDFB),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Visit care notes',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record what your doctor advised during this visit.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: adviceController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 5000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Doctor’s advice',
                    hintText: 'Medicines, care instructions, or other advice',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: _line),
                    ),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: _green,
                  title: const Text(
                    'Doctor advised a revisit',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  value: revisitRecommended,
                  onChanged: (value) => setDialogState(() {
                    revisitRecommended = value;
                    if (!value) revisitDate = null;
                  }),
                ),
                if (revisitRecommended) ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      final today = DateUtils.dateOnly(DateTime.now());
                      final firstDate = DateUtils.dateOnly(visitDate);
                      final initialDate = revisitDate ??
                          (today.isAfter(firstDate) ? today : firstDate);
                      final picked = await showDatePicker(
                        context: dialogBuilderContext,
                        initialDate: initialDate,
                        firstDate: firstDate,
                        lastDate: today.add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null) {
                        setDialogState(() => revisitDate = picked);
                      }
                    },
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      revisitDate == null
                          ? 'Choose revisit date'
                          : 'Revisit: ${_formatDate(revisitDate!)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _line),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: revisitNotesController,
                    maxLines: 2,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Follow-up details (optional)',
                      hintText: 'What to bring or discuss at the revisit',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: _line),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'These are your personal notes and are not verified by the clinic.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (revisitRecommended && revisitDate == null) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Choose the recommended revisit date.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ApiService.saveAppointmentCareNotes(
                          appointmentId: int.parse(
                            visit['appointment_id'].toString(),
                          ),
                          doctorAdvice: adviceController.text.trim().isEmpty
                              ? null
                              : adviceController.text.trim(),
                          revisitDate: revisitRecommended
                              ? _toDateString(revisitDate!)
                              : null,
                          revisitNotes: revisitRecommended &&
                                  revisitNotesController.text.trim().isNotEmpty
                              ? revisitNotesController.text.trim()
                              : null,
                        );
                        if (!mounted) return;
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _loadVisits();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Your care notes have been saved.'),
                              backgroundColor: _green,
                            ),
                          );
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Could not save notes: $error')),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(saving ? 'Saving' : 'Save notes'),
            ),
          ],
        ),
      ),
    );
    adviceController.dispose();
    revisitNotesController.dispose();
  }

  String _toDateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('Doctor advice & follow-up'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : _error != null
                ? _messageState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Care notes could not be loaded',
                    detail: _error!,
                    action: TextButton(
                      onPressed: _loadVisits,
                      child: const Text('Try again'),
                    ),
                  )
                : _visits.isEmpty
                    ? _messageState(
                        icon: Icons.medical_information_outlined,
                        title: 'Your visit notes will live here',
                        detail:
                            'After a booked visit, save the doctor’s advice and any recommended revisit date.',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadVisits,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(17),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF2EC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _line),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: _green,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Private to your account. Notes are recorded by you and are not a substitute for your doctor’s instructions.',
                                      style: TextStyle(
                                        color: _ink,
                                        height: 1.4,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (final rawVisit in _visits)
                              if (rawVisit is Map)
                                _visitCard(rawVisit),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _visitCard(Map<dynamic, dynamic> visit) {
    final advice = visit['doctor_advice']?.toString().trim() ?? '';
    final revisitDate = DateTime.tryParse(
      visit['revisit_date']?.toString() ?? '',
    );
    final revisitNotes = visit['revisit_notes']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2EC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.medical_services_outlined, color: _green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit['doctor_name']?.toString() ?? 'Doctor',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${visit['specialty'] ?? 'Appointment'} · ${_formatDate(DateTime.parse(visit['appointment_date'].toString()))}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (advice.isNotEmpty) ...[
            const Text(
              'DOCTOR’S ADVICE',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(advice, style: const TextStyle(color: _ink, height: 1.4)),
          ] else
            const Text(
              'No advice recorded yet.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          if (revisitDate != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7F1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.event_repeat_rounded,
                    color: _green,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revisit recommended · ${_formatDate(revisitDate)}',
                          style: const TextStyle(
                            color: _green,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (revisitNotes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            revisitNotes,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _editCareNote(visit),
              icon: Icon(
                advice.isEmpty && revisitDate == null
                    ? Icons.add_rounded
                    : Icons.edit_outlined,
              ),
              label: Text(
                advice.isEmpty && revisitDate == null
                    ? 'Add visit notes'
                    : 'Edit visit notes',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String detail,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _green, size: 44),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.4),
            ),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}
