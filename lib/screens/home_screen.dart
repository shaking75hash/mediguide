import 'package:flutter/material.dart';

import '../data/providers.dart';
import '../models/provider.dart';
import '../services/api_service.dart';
import '../widgets/provider_card.dart';
import '../widgets/service_card.dart';
import 'appointments_screen.dart';
import 'book_appointment_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  String _userName = 'User';

  // Real data from the database
  List<dynamic> _doctors = [];
  bool _loadingDoctors = true;
  List<dynamic> _myAppointments = [];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadDoctors();
    _loadMyAppointments();
  }

  Future<void> _loadUserName() async {
    try {
      final me = await ApiService.getMe();
      if (mounted) {
        setState(() {
          _userName = me['name'] ?? 'User';
        });
      }
    } catch (e) {
      debugPrint('❌ getMe failed: $e');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadDoctors() async {
    try {
      final data = await ApiService.getDoctors();
      if (mounted) setState(() => _doctors = data);
    } catch (e) {
      debugPrint('❌ Failed to load doctors: $e');
    } finally {
      if (mounted) setState(() => _loadingDoctors = false);
    }
  }

  Future<void> _loadMyAppointments() async {
    try {
      final data = await ApiService.getMyAppointments();
      if (mounted) setState(() => _myAppointments = data);
    } catch (e) {
      debugPrint('❌ Failed to load appointments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use REAL doctors from DB if available, otherwise fall back to mock data
    final featuredProviders = _doctors.isNotEmpty
        ? _doctors.take(2).map((doctor) {
            final fee = doctor['consultation_fee'] ?? 0;
            return Provider(
              id: doctor['id'].toString(),
              name: doctor['name'] ?? 'Doctor',
              type: 'Doctor',
              specialty: doctor['specialty'] ?? 'General Care',
              location: doctor['location'] ?? 'Unknown',
              rating: 4.8,
              reviewCount: 120,
              price: fee is num ? fee.toDouble() : 0.0,
              imageUrl: 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=400&q=80',
              email: '',
              phone: '',
              workingHours: 'Available',
            );
          }).toList()
        : providers.take(2).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'MediGuide',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF123A6B),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none,
              color: Color(0xFF123A6B),
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, color: Color(0xFF123A6B)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- Greeting Banner ----------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $_userName 👋',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'How can we help you today?',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Upcoming',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_myAppointments.length} Appointment${_myAppointments.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Health Score',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '92%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ---------- Search Bar ----------
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search doctors, hospitals, clinics...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ---------- Services ----------
              const Text(
                'Healthcare Services',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123A6B),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: ServiceCard(icon: Icons.person, title: 'Doctors'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ServiceCard(
                      icon: Icons.local_hospital,
                      title: 'Hospitals',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ServiceCard(
                      icon: Icons.medical_services,
                      title: 'Clinics',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ServiceCard(
                      icon: Icons.science,
                      title: 'Diagnostics',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ---------- Nearby Providers (REAL doctors from DB) ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Nearby Healthcare Providers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF123A6B),
                    ),
                  ),
                  Text(
                    'See all',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              _loadingDoctors
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      children: featuredProviders
                          .map(
                            (provider) => Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: ProviderCard(
                                provider: provider,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BookAppointmentScreen(
                                        doctorId: int.parse(provider.id),
                                        doctorName: provider.name,
                                        specialty: provider.specialty,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                          .toList(),
                    ),

              const SizedBox(height: 18),

              // ---------- Next Appointment (REAL data from DB) ----------
              Builder(
                builder: (_) {
                  if (_myAppointments.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            color: Colors.blue,
                            size: 28,
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'No upcoming appointments. Book one above!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final next = _myAppointments.first;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Next appointment',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${next['doctor_name']} • ${next['date']} at ${next['time']}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF123A6B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.blue),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // ---------- Bottom Navigation ----------
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });

          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AppointmentsScreen(),
              ),
            );
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
