import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/token_storage.dart';

class RegisterAsDoctorScreen extends StatefulWidget {
  const RegisterAsDoctorScreen({super.key});
  @override
  State<RegisterAsDoctorScreen> createState() => _RegisterAsDoctorScreenState();
}

class _RegisterAsDoctorScreenState extends State<RegisterAsDoctorScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _feeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
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
  String? _selectedSpecialty;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _qualificationController.dispose();
    _feeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final fee = int.tryParse(_feeController.text.trim());
    if (_nameController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      setState(() => error = 'Complete your name, location, and email.');
      return;
    }
    if (_selectedSpecialty == null) {
      setState(() => error = 'Please select a specialty.');
      return;
    }
    if (fee == null || fee < 0) {
      setState(() => error = 'Enter a valid consultation fee.');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => error = 'Password must be at least 8 characters.');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => error = 'Passwords do not match.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ApiService.registerDoctor(
        name: _nameController.text.trim(),
        specialty: _selectedSpecialty!,
        location: _locationController.text.trim(),
        qualification: _qualificationController.text.trim(),
        consultationFee: fee,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final token = result['access_token'];
      if (token is! String || token.isEmpty) {
        throw const FormatException(
          'Registration response did not include an access token.',
        );
      }
      await TokenStorage.saveToken(token, role: 'doctor');
      await TokenStorage.saveActiveRole('doctor');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor profile created.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const DoctorHomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e.toString().replaceFirst('Exception: ', '').trim(),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create doctor account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Create your professional profile',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your profile will be visible to patients and marked unverified.',
              style: TextStyle(color: Color(0xFF728078)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSpecialty,
              decoration: const InputDecoration(labelText: 'Specialty'),
              items: specialties
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: loading
                  ? null
                  : (value) => setState(() => _selectedSpecialty = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qualificationController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Qualification (optional)',
                hintText: 'For example, medical degree or credentials',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Consultation fee',
                prefixText: '৳ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : _createAccount,
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create doctor profile'),
            ),
          ],
        ),
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
  final password = TextEditingController();
  String? error;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ApiService.doctorLogin(
        email.text.trim(),
        password.text,
      );
      await TokenStorage.saveToken(
        result['access_token'] as String,
        role: 'doctor',
      );
      await TokenStorage.saveActiveRole('doctor');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DoctorHomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e.toString().replaceFirst('Exception: ', '').trim(),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Doctor sign in')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: loading ? null : login,
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/welcome'),
            child: const Text('Back to welcome'),
          ),
        ],
      ),
    ),
  );
}

class DoctorPersonalProfileScreen extends StatefulWidget {
  const DoctorPersonalProfileScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DoctorPersonalProfileScreen> createState() =>
      _DoctorPersonalProfileScreenState();
}

class _DoctorPersonalProfileScreenState
    extends State<DoctorPersonalProfileScreen> {
  final _locationController = TextEditingController();
  final _qualificationController = TextEditingController();
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _qualificationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ApiService.getDoctorProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _locationController.text = profile['location']?.toString() ?? '';
        _qualificationController.text =
            profile['qualification']?.toString() ?? '';
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final location = _locationController.text.trim();
    if (location.isEmpty) {
      setState(() => _error = 'Location is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = await ApiService.updateDoctorProfile(
        location: location,
        qualification: _qualificationController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _locationController.text = profile['location']?.toString() ?? '';
        _qualificationController.text =
            profile['qualification']?.toString() ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(title: const Text('Personal profile')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _profile == null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error ?? 'Could not load your profile.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _loadProfile,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Your professional details',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Changes are saved to your doctor profile and shown to patients.',
                style: TextStyle(color: Color(0xFF728078)),
              ),
              if (_profile!['is_sample'] == true) ...[
                const SizedBox(height: 14),
                Card(
                  color: const Color(0xFFFFF6DF),
                  child: const ListTile(
                    leading: Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFF9A6700),
                    ),
                    title: Text('Demo account'),
                    subtitle: Text(
                      'Fictional sample profile. Use for app testing only; do not enter real patient information.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profileDetail(
                        'Name',
                        _profile!['name']?.toString() ?? '',
                      ),
                      _profileDetail(
                        'Specialty',
                        _profile!['specialty']?.toString() ?? '',
                      ),
                      _profileDetail(
                        'Email',
                        _profile!['email']?.toString() ?? '',
                      ),
                      _profileDetail(
                        'Verification',
                        _profile!['is_verified'] == true
                            ? 'Verified'
                            : 'Unverified',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qualificationController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Qualification',
                  hintText: 'For example, medical degree or credentials',
                  prefixIcon: Icon(Icons.school_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _saveProfile,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save profile changes'),
              ),
            ],
          ),
  );

  Widget _profileDetail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: const TextStyle(color: Color(0xFF728078))),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});
  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today_rounded),
      label: 'Appointments',
    ),
    NavigationDestination(
      icon: Icon(Icons.schedule_outlined),
      selectedIcon: Icon(Icons.schedule_rounded),
      label: 'Schedule',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
    NavigationDestination(
      icon: Icon(Icons.logout_rounded),
      selectedIcon: Icon(Icons.logout_rounded),
      label: 'Sign out',
    ),
  ];

  Future<List<dynamic>>? appointments;
  Timer? _appointmentsRefreshTimer;
  final _visitedTabs = [true, false, false];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    appointments = ApiService.getDoctorAppointments('');
    _appointmentsRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_selectedIndex == 0) refresh();
    });
  }

  @override
  void dispose() {
    _appointmentsRefreshTimer?.cancel();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs[index] = true;
    });
  }

  Future<void> _signOutToWelcome() async {
    await TokenStorage.clearAll();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/welcome', (_) => false);
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateController,
              decoration: const InputDecoration(hintText: 'YYYY-MM-DD'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (dateConfirmed != true || dateController.text.trim().isEmpty) return;
    List<String> slots;
    try {
      slots = await ApiService.getDoctorFreeSlots(dateController.text.trim());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }
    if (slots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No free slots are available on that date'),
        ),
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
              children: slots
                  .map(
                    (slot) => ChoiceChip(
                      label: Text(slot),
                      selected: selectedTime == slot,
                      onSelected: (_) =>
                          setDialogState(() => selectedTime = slot),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedTime == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Reschedule'),
            ),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Widget _buildAppointments() => FutureBuilder<List<dynamic>>(
    future: appointments,
    builder: (_, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.data!.isEmpty) {
        return const Center(child: Text('No appointments today'));
      }
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          children: snapshot.data!
              .map(
                (item) => Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text('${item['patient_name']} - ${item['date']}'),
                    subtitle: Text(
                      '${item['time']} - ${item['status']}'
                      '${item['doctor_advice'] != null ? '\nNotes: ${item['doctor_advice']}' : ''}'
                      '${item['revisit_notes'] != null ? '\nFollow-up: ${item['revisit_notes']}' : ''}',
                    ),
                    trailing: Wrap(
                      children: [
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
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Keep appointment'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Cancel appointment'),
                                  ),
                                ],
                              ),
                            );
                            if (!mounted) return;
                            if (confirmed == true) {
                              try {
                                await ApiService.cancelDoctorAppointment(
                                  item['id'],
                                );
                                await refresh();
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Patient notified of cancellation',
                                    ),
                                  ),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(switch (_selectedIndex) {
        0 => 'Doctor home',
        1 => 'Weekly schedule',
        _ => 'Personal profile',
      }),
      actions: [
        IconButton(
          tooltip: 'Sign out and return to welcome',
          onPressed: _signOutToWelcome,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        _buildAppointments(),
        _visitedTabs[1]
            ? const DoctorScheduleScreen(embedded: true)
            : const SizedBox.shrink(),
        _visitedTabs[2]
            ? const DoctorPersonalProfileScreen(embedded: true)
            : const SizedBox.shrink(),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        if (index == _destinations.length - 1) {
          _signOutToWelcome();
        } else {
          _selectTab(index);
        }
      },
      destinations: _destinations,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );
}

class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({super.key, this.embedded = false});

  final bool embedded;
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
          ..addAll(
            rows.map(
              (row) => {
                'day_of_week': row['day_of_week'],
                'start_time': row['start_time'],
                'end_time': row['end_time'],
                'session_length_minutes': row['session_length_minutes'] ?? 30,
              },
            ),
          );
      });
    });
  }

  Future<void> addRange() async {
    final range = {
      'day_of_week': selectedDay,
      'start_time': startController.text.trim(),
      'end_time': endController.text.trim(),
      'session_length_minutes':
          int.tryParse(sessionController.text.trim()) ?? 30,
    };
    setState(() => ranges.add(range));
  }

  Future<void> save() async {
    try {
      await ApiService.replaceDoctorSchedule(ranges);
      setState(() => schedule = ApiService.getDoctorSchedule());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Schedule updated')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Day off saved')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: widget.embedded
        ? null
        : AppBar(title: const Text('Weekly schedule')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<int>(
          initialValue: selectedDay,
          decoration: const InputDecoration(labelText: 'Day'),
          items: List.generate(
            7,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text('Day ${index + 1}'),
            ),
          ),
          onChanged: (value) => setState(() => selectedDay = value ?? 1),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: startController,
          decoration: const InputDecoration(labelText: 'Start time'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: endController,
          decoration: const InputDecoration(labelText: 'End time'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: sessionController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Session length in minutes (5-60)',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: addRange, child: const Text('Add range')),
        if (ranges.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...ranges.map(
            (range) => ListTile(
              title: Text('Day ${range['day_of_week']}'),
              subtitle: Text('${range['start_time']} - ${range['end_time']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => ranges.remove(range)),
              ),
            ),
          ),
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
          decoration: const InputDecoration(
            labelText: 'Reason (optional, private)',
          ),
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
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep appointments'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cancel all'),
                  ),
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
                children: snapshot.data!
                    .map(
                      (dayOff) => ListTile(
                        leading: const Icon(Icons.event_busy_outlined),
                        title: Text(dayOff['date']),
                        trailing: IconButton(
                          tooltip: 'Remove day off',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ApiService.removeDoctorDayOff(dayOff['date']);
                            setState(
                              () => daysOff = ApiService.getDoctorDaysOff(),
                            );
                          },
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
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
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('No notifications'));
        }
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            children: snapshot.data!
                .map(
                  (item) => ListTile(
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
                  ),
                )
                .toList(),
          ),
        );
      },
    ),
  );
}
