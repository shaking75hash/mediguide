import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/api_service.dart';
import '../services/token_storage.dart';
import 'login_screen.dart';

class RegisterAsDoctorScreen extends StatefulWidget {
  const RegisterAsDoctorScreen({super.key});
  @override
  State<RegisterAsDoctorScreen> createState() => _RegisterAsDoctorScreenState();
}

class _RegisterAsDoctorScreenState extends State<RegisterAsDoctorScreen> {
  final name = TextEditingController();
  final qualification = TextEditingController();
  final email = TextEditingController();
  final code = TextEditingController();
  static const specialties = [
    'General Practice',
    'Cardiology',
    'Neurology',
    'Dermatology',
    'Pediatrics',
    'Orthopedics',
    'Gynecology',
    'Psychiatry',
  ];
  String? selectedSpecialty;
  bool codeSent = false;
  bool loading = false;
  String? error;

  Future<void> sendCode() async {
    setState(() { loading = true; error = null; });
    try {
      await ApiService.sendDoctorVerificationCode(email.text.trim());
      setState(() => codeSent = true);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (selectedSpecialty == null) {
      setState(() => error = 'Please select a specialty.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await ApiService.submitDoctorRequest(
        name: name.text, specialty: selectedSpecialty!,
        qualification: qualification.text, email: email.text, code: code.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your request was received')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
      TextField(controller: qualification, decoration: const InputDecoration(labelText: 'Qualification')),
      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Register as a doctor')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          for (final field in fields) ...[field, const SizedBox(height: 12)],
          DropdownButtonFormField<String>(
            initialValue: selectedSpecialty,
            decoration: const InputDecoration(labelText: 'Specialty'),
            items: specialties
                .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                .toList(),
            onChanged: loading
                ? null
                : (value) => setState(() {
                    selectedSpecialty = value;
                    error = null;
                  }),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: loading ? null : sendCode, child: const Text('Send verification code')),
          if (codeSent) ...[
            const SizedBox(height: 12),
            TextField(controller: code, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Six-digit code')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: loading ? null : submit, child: const Text('Submit request')),
          ],
          if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red))],
        ]),
      ),
    );
  }
}

class DoctorLoginScreen extends StatefulWidget {
  const DoctorLoginScreen({super.key});
  @override
  State<DoctorLoginScreen> createState() => _DoctorLoginScreenState();
}

class _DoctorLoginScreenState extends State<DoctorLoginScreen> {
  final email = TextEditingController();
  final identifier = TextEditingController();
  String? error;

  Future<void> login() async {
    try {
      final result = await ApiService.doctorLogin(email.text.trim(), identifier.text.trim());
      await TokenStorage.saveToken(result['access_token'] as String, role: 'doctor');
      await TokenStorage.saveActiveRole('doctor');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorHomeScreen()),
        );
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Doctor sign in')),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
      const SizedBox(height: 12),
      TextField(controller: identifier, decoration: const InputDecoration(labelText: 'Doctor identifier')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: login, child: const Text('Sign in')),
    ])),
  );
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  String? error;
  bool loading = false;
  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ApiService.adminLogin(email.text.trim(), password.text, code.text.trim());
      await TokenStorage.saveToken(result['access_token'] as String, role: 'admin');
      await TokenStorage.saveActiveRole('admin');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', '').trim());
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Administrator sign in')),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
      TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'TOTP code')),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: loading ? null : login,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Sign in'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
        child: const Text('Back to login'),
      ),
    ])),
  );
}

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});
  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  Future<List<dynamic>>? appointments;
  @override
  void initState() {
    super.initState();
    appointments = ApiService.getDoctorAppointments('');
  }
  Future<void> refresh() async {
    setState(() => appointments = ApiService.getDoctorAppointments(''));
  }

  Future<void> reschedule(int appointmentId) async {
    final dateController = TextEditingController();
    final dateConfirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reschedule appointment'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: dateController, decoration: const InputDecoration(hintText: 'YYYY-MM-DD')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (dateConfirmed != true || dateController.text.trim().isEmpty) return;
    List<String> slots;
    try {
      slots = await ApiService.getDoctorFreeSlots(dateController.text.trim());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (slots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No free slots are available on that date')),
      );
      return;
    }
    String? selectedTime;
    if (!mounted) return;
    final timeConfirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Choose a free slot'),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              children: slots.map((slot) => ChoiceChip(
                label: Text(slot),
                selected: selectedTime == slot,
                onSelected: (_) => setDialogState(() => selectedTime = slot),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: selectedTime == null ? null : () => Navigator.pop(dialogContext, true),
              child: const Text('Reschedule')),
          ],
        ),
      ),
    );
    if (timeConfirmed != true || selectedTime == null) return;
    try {
      await ApiService.rescheduleDoctorAppointment(
        appointmentId,
        dateController.text.trim(),
        selectedTime!,
      );
      await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Doctor home'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: () async {
            final navigator = Navigator.of(context);
            await TokenStorage.clearAll();
            if (!mounted) return;
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
          icon: const Icon(Icons.logout),
        ),
        IconButton(
          tooltip: 'Weekly schedule',
          onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DoctorScheduleScreen())),
          icon: const Icon(Icons.schedule_outlined),
        ),
      ],
    ),
    body: FutureBuilder<List<dynamic>>(
      future: appointments,
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text('No appointments today'));
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(children: snapshot.data!.map((item) => Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              title: Text('${item['patient_name']} - ${item['date']}'),
              subtitle: Text(
                '${item['time']} - ${item['status']}'
                '${item['doctor_advice'] != null ? '\nNotes: ${item['doctor_advice']}' : ''}'
                '${item['revisit_notes'] != null ? '\nFollow-up: ${item['revisit_notes']}' : ''}',
              ),
              trailing: Wrap(children: [
                IconButton(
                  tooltip: 'Reschedule',
                  onPressed: () => reschedule(item['id']),
                  icon: const Icon(Icons.event_repeat_outlined),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Cancel appointment?'),
                        content: Text(
                          'Cancel ${item['patient_name']}\'s appointment on '
                          '${item['date']} at ${item['time']}?',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep appointment')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel appointment')),
                        ],
                      ),
                    );
                    if (!mounted) return;
                    if (confirmed == true) {
                      try {
                        await ApiService.cancelDoctorAppointment(item['id']);
                        await refresh();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Patient notified of cancellation')),
                        );
                      } catch (error) {
                        if (!mounted) return;
                        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
                      }
                    }
                  },
                  icon: const Icon(Icons.cancel_outlined),
                ),
              ]),
            ),
          )).toList()),
        );
      },
    ),
  );
}

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key});
  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  Future<List<dynamic>>? schedule;
  int selectedDay = 1;
  final startController = TextEditingController(text: '09:00');
  final endController = TextEditingController(text: '17:00');
  final sessionController = TextEditingController(text: '30');
  final dayOffDateController = TextEditingController();
  final dayOffReasonController = TextEditingController();
  Future<List<dynamic>>? daysOff;
  final ranges = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    schedule = ApiService.getDoctorSchedule();
    daysOff = ApiService.getDoctorDaysOff();
    schedule!.then((rows) {
      if (!mounted) return;
      setState(() {
        ranges
          ..clear()
          ..addAll(rows.map((row) => {
            'day_of_week': row['day_of_week'],
            'start_time': row['start_time'],
            'end_time': row['end_time'],
            'session_length_minutes': row['session_length_minutes'] ?? 30,
          }));
      });
    });
  }

  Future<void> addRange() async {
    final range = {
      'day_of_week': selectedDay,
      'start_time': startController.text.trim(),
      'end_time': endController.text.trim(),
      'session_length_minutes': int.tryParse(sessionController.text.trim()) ?? 30,
    };
    setState(() => ranges.add(range));
  }

  Future<void> save() async {
    try {
      await ApiService.replaceDoctorSchedule(ranges);
      setState(() => schedule = ApiService.getDoctorSchedule());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule updated')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> createDayOff({required bool cancelAll}) async {
    final date = dayOffDateController.text.trim();
    if (date.isEmpty) return;
    try {
      await ApiService.createDoctorDayOff(
        date,
        dayOffReasonController.text.trim().isEmpty
            ? null
            : dayOffReasonController.text.trim(),
        const [],
        cancelAll,
      );
      setState(() => daysOff = ApiService.getDoctorDaysOff());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day off saved')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weekly schedule')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      DropdownButtonFormField<int>(
        initialValue: selectedDay,
        decoration: const InputDecoration(labelText: 'Day'),
        items: List.generate(7, (index) => DropdownMenuItem(
          value: index + 1,
          child: Text('Day ${index + 1}'),
        )),
        onChanged: (value) => setState(() => selectedDay = value ?? 1),
      ),
      const SizedBox(height: 12),
      TextField(controller: startController, decoration: const InputDecoration(labelText: 'Start time')),
      const SizedBox(height: 12),
      TextField(controller: endController, decoration: const InputDecoration(labelText: 'End time')),
      const SizedBox(height: 12),
      TextField(
        controller: sessionController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Session length in minutes (5-60)'),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: addRange, child: const Text('Add range')),
      if (ranges.isNotEmpty) ...[
        const SizedBox(height: 12),
        ...ranges.map((range) => ListTile(
          title: Text('Day ${range['day_of_week']}'),
          subtitle: Text('${range['start_time']} - ${range['end_time']}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => ranges.remove(range)),
          ),
        )),
        const SizedBox(height: 12),
        FilledButton(onPressed: save, child: const Text('Save schedule')),
      ],
      const Divider(height: 32),
      const Text('Day off', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      TextField(
        controller: dayOffDateController,
        decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: dayOffReasonController,
        decoration: const InputDecoration(labelText: 'Reason (optional, private)'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Cancel all appointments?'),
              content: const Text(
                'All existing patients on this date will be notified and their appointments cancelled.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep appointments')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel all')),
              ],
            ),
          );
          if (confirmed == true) await createDayOff(cancelAll: true);
        },
        child: const Text('Cancel all and save day off'),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: () => createDayOff(cancelAll: false),
        child: const Text('Save day off after resolving appointments'),
      ),
      const SizedBox(height: 16),
      if (daysOff != null)
        FutureBuilder<List<dynamic>>(
          future: daysOff,
          builder: (_, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            return Column(
              children: snapshot.data!.map((dayOff) => ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: Text(dayOff['date']),
                trailing: IconButton(
                  tooltip: 'Remove day off',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ApiService.removeDoctorDayOff(dayOff['date']);
                    setState(() => daysOff = ApiService.getDoctorDaysOff());
                  },
                ),
              )).toList(),
            );
          },
        ),
    ]),
  );
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<List<dynamic>> requests;
  late Future<List<dynamic>> doctors;

  @override
  void initState() {
    super.initState();
    requests = ApiService.getAdminDoctorRequests();
    doctors = ApiService.getDoctors();
  }

  Future<void> refresh() async {
    setState(() {
      requests = ApiService.getAdminDoctorRequests();
      doctors = ApiService.getDoctors();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Administration'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: () async {
            await TokenStorage.clearAll();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Pending doctor requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          FutureBuilder<List<dynamic>>(
            future: requests,
            builder: (_, snapshot) {
              if (snapshot.hasError) {
                return Text(snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No pending doctor requests'),
                );
              }
              return Column(
                children: snapshot.data!.map((request) => Card(
                  child: ListTile(
                    title: Text(request['full_name']),
                    subtitle: Text(
                      '${request['specialty']} - ${request['qualification']}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Approve',
                          onPressed: () async {
                            await ApiService.approveDoctorRequest(request['id']);
                            await refresh();
                          },
                          icon: const Icon(Icons.check_circle_outline,
                              color: Colors.green),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () async {
                            await ApiService.rejectDoctorRequest(request['id']);
                            await refresh();
                          },
                          icon: const Icon(Icons.cancel_outlined,
                              color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Doctors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          FutureBuilder<List<dynamic>>(
            future: doctors,
            builder: (_, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Column(
                children: snapshot.data!.map((doctor) => Card(
                  child: ListTile(
                    title: Text(doctor['name']),
                    subtitle: Text(
                      '${doctor['specialty']} - ${doctor['location']}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Soft delete doctor',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete doctor?'),
                            content: Text(
                              'Doctor ${doctor['name']} will be removed from patient searches.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await ApiService.deleteAdminDoctor(doctor['id']);
                            await refresh();
                          } catch (error) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        }
                      },
                    ),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<dynamic>> notifications;

  @override
  void initState() {
    super.initState();
    notifications = ApiService.getNotifications();
  }

  Future<void> refresh() async {
    setState(() => notifications = ApiService.getNotifications());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: FutureBuilder<List<dynamic>>(
      future: notifications,
      builder: (_, snapshot) {
        if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text('No notifications'));
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            children: snapshot.data!.map((item) => ListTile(
              leading: Icon(
                item['read_at'] == null
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
              ),
              title: Text(item['message']),
              onTap: () async {
                await ApiService.markNotificationRead(item['id']);
                await refresh();
              },
            )).toList(),
          ),
        );
      },
    ),
  );
}

class InviteAcceptanceScreen extends StatefulWidget {
  final String inviteToken;
  const InviteAcceptanceScreen({super.key, required this.inviteToken});
  @override
  State<InviteAcceptanceScreen> createState() => _InviteAcceptanceScreenState();
}

class _InviteAcceptanceScreenState extends State<InviteAcceptanceScreen> {
  final password = TextEditingController();
  String? qrUri;
  Future<void> accept() async {
    try {
      final result = await ApiService.acceptAdminInvite(
        widget.inviteToken,
        password.text,
      );
      setState(() => qrUri = result['otpauth_uri'] as String?);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite could not be accepted')),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Accept administrator invite')),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: accept, child: const Text('Accept invite')),
      if (qrUri != null) QrImageView(data: qrUri!, size: 220),
    ])),
  );
}
