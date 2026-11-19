import 'dart:async';

import 'package:flutter/material.dart';

import '../services/appointment_notification_service.dart';
import '../services/api_service.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final data = await ApiService.getMyAppointments();
      try {
        await AppointmentNotificationService.syncIfPermitted(data);
      } catch (error) {
        debugPrint('Could not sync appointment reminders: $error');
      }
      if (mounted) setState(() => _appointments = data);
    } catch (e) {
      debugPrint('Could not refresh appointments: $e');
      if (mounted && !silent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _appointments.isEmpty
            ? const Center(child: Text('No appointments yet'))
            : RefreshIndicator(
                onRefresh: () => _load(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) {
                    final appt = _appointments[index];
                    final doctorName = appt['doctor_name']?.toString() ?? '';
                    final status = appt['status']?.toString() ?? 'scheduled';
                    final missed = status.toLowerCase() == 'missed';
                    final active = const {
                      'scheduled',
                      'rescheduled',
                    }.contains(status.toLowerCase());
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.person, color: Colors.blue),
                        ),
                        title: Text(
                          doctorName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          missed
                              ? 'You missed your appointment with $doctorName. '
                                    '${appt['specialty']} • ${appt['date']} at ${appt['time']}'
                              : '${appt['specialty']} • ${appt['date']} at ${appt['time']}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(missed ? 'Missed' : status),
                              backgroundColor: missed
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              labelStyle: TextStyle(
                                color: missed
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                fontSize: 12,
                              ),
                            ),
                            if (active)
                              IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Cancel Appointment?'),
                                      content: const Text(
                                        'Are you sure you want to cancel this appointment?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('No'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Yes, Cancel'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      await ApiService.cancelAppointment(
                                        appt['id'],
                                      );
                                      final appointmentId = int.tryParse(
                                        appt['id'].toString(),
                                      );
                                      if (appointmentId != null) {
                                        try {
                                          await AppointmentNotificationService.cancelReminder(
                                            appointmentId,
                                          );
                                        } catch (error) {
                                          debugPrint(
                                            'Could not cancel appointment reminder: $error',
                                          );
                                        }
                                      }
                                      await _load();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Appointment cancelled',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to cancel: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
