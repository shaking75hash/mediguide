import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../models/provider.dart';
import '../services/appointment_notification_service.dart';
import '../services/api_service.dart';
import 'app_navigation.dart';
import '../widgets/provider_card.dart';
import 'doctor_profile_screen.dart';
import 'login_screen.dart';

// Premium Color Tokens - Top Level for cross-widget access
const Color _kBgBase = Color(0xFFF9F9F7);
const Color _kSurface = Color(0xFFFFFFFF);
const Color _kTextPrimary = Color(0xFF1E293B);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kBrandPrimary = Color(0xFF4A7C59);
const Color _kBrandLight = Color(0xFFE8F0EB);
const Color _kBorder = Color(0xFFE2E8F0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'User';
  List<dynamic> _doctors = [];
  bool _loadingDoctors = true;
  String? _doctorLoadError;
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
      if (mounted) setState(() => _userName = me['name'] ?? 'User');
    } catch (e) {
      debugPrint('❌ getMe failed: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadDoctors() async {
    try {
      final data = await ApiService.getDoctors();
      if (mounted) {
        setState(() {
          _doctors = data;
          _doctorLoadError = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load doctors: $e');
      if (mounted) setState(() => _doctorLoadError = e.toString());
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

  List<Provider> _getFeaturedProviders() {
    if (_doctors.isNotEmpty) {
      return _doctors.take(3).map((doctor) {
        final fee = doctor['consultation_fee'] ?? 0;
        return Provider(
          id: doctor['id'].toString(),
          name: doctor['name'] ?? 'Doctor',
          type: 'Doctor',
          specialty: doctor['specialty'] ?? 'General Care',
          location: doctor['location'] ?? 'Unknown',
          rating: 0,
          reviewCount: 0,
          price: fee is num ? fee.toDouble() : 0.0,
          imageUrl: doctor['image_url']?.toString() ?? '',
          email: '',
          phone: '',
          workingHours: 'Available',
        );
      }).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final featuredProviders = _getFeaturedProviders();

    return Scaffold(
      backgroundColor: _kBgBase,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: _kBgBase,
              title: const Text(
                'MediGuide',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.person_outline_rounded,
                    color: _kTextPrimary,
                  ),
                  tooltip: 'Profile',
                  onPressed: () => AppNavigation.of(context).onSelectTab(3),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: _kTextSecondary,
                  ),
                  tooltip: 'Logout',
                  onPressed: () async {
                    try {
                      await AppointmentNotificationService.cancelAllAppointmentReminders();
                    } catch (error) {
                      debugPrint(
                        'Could not clear appointment reminders: $error',
                      );
                    }
                    await ApiService.logout();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _openSearch,
                      child: _buildSearchCard(),
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _CategoryPill(
                            icon: Icons.person_outline_rounded,
                            label: 'Doctors',
                            onTap: _openSearch,
                          ),
                          const SizedBox(width: 10),
                          _CategoryPill(
                            icon: Icons.calendar_month_outlined,
                            label: 'Appointments',
                            onTap: _openAppointments,
                          ),
                          const SizedBox(width: 10),
                          _CategoryPill(
                            icon: Icons.compare_arrows_rounded,
                            label: 'Compare Prices',
                            highlight: true,
                            onTap: _openPriceComparison,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildNextAppointmentCard(),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Doctors to explore',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _kTextPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextButton(
                          onPressed: _openSearch,
                          child: const Text(
                            'See all',
                            style: TextStyle(
                              color: _kBrandPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loadingDoctors)
                      ...List.generate(3, (_) => const _ProviderCardSkeleton())
                    else if (_doctorLoadError != null)
                      _buildDoctorsMessage(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load doctors',
                        message: 'Check your connection and try again.',
                        actionLabel: 'Retry',
                        onAction: () {
                          setState(() {
                            _loadingDoctors = true;
                            _doctorLoadError = null;
                          });
                          _loadDoctors();
                        },
                      )
                    else if (featuredProviders.isEmpty)
                      _buildDoctorsMessage(
                        icon: Icons.medical_services_outlined,
                        title: 'No doctors yet',
                        message: 'Please check back soon.',
                      )
                    else
                      ...featuredProviders.map(
                        (provider) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ProviderCard(
                            provider: provider,
                            onTap: () {
                              final doctorData = _doctors.firstWhere(
                                (d) => d['id'].toString() == provider.id,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DoctorProfileScreen(doctor: doctorData),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _firstName {
    final name = _userName.trim();
    if (name.isEmpty) return 'there';
    return name.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openSearch() {
    AppNavigation.of(context).onSelectTab(1);
  }

  void _openPriceComparison() {
    AppNavigation.of(context).onOpenPriceComparison();
  }

  void _openAppointments() {
    AppNavigation.of(context).onSelectTab(2);
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF315F45), Color(0xFF4A7C59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kBrandPrimary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                color: Color(0xFFE7C982),
                size: 17,
              ),
              const SizedBox(width: 8),
              Text(
                _greeting.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Hello, $_firstName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find trusted care and make your next health decision with confidence.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: _kTextPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, color: _kBrandPrimary, size: 23),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search doctors and specialties',
              style: TextStyle(color: _kTextSecondary, fontSize: 15),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 15,
            color: _kTextSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsMessage({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kBrandPrimary, size: 30),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _kTextPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _kTextSecondary, fontSize: 13),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildNextAppointmentCard() {
    if (_myAppointments.isEmpty) {
      return InkWell(
        onTap: _openSearch,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kBrandLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: _kBrandPrimary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your care, on your schedule',
                      style: TextStyle(
                        color: _kTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'No upcoming appointments · Book a visit',
                      style: TextStyle(color: _kTextSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _kTextSecondary,
              ),
            ],
          ),
        ),
      );
    }
    final next = _myAppointments.first;
    return GestureDetector(
      onTap: _openAppointments,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBrandLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: _kBrandPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next Appointment',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kTextSecondary,
                      letterSpacing: 0.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${next['doctor_name'] ?? 'Doctor'} • ${next['date']} at ${next['time']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final VoidCallback? onTap;

  const _CategoryPill({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? _kBrandPrimary : _kSurface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: highlight ? _kBrandPrimary : _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: highlight ? Colors.white : _kTextPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: highlight ? Colors.white : _kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCardSkeleton extends StatelessWidget {
  const _ProviderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Bone.circle(size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone.text(width: 180),
                  const SizedBox(height: 8),
                  Bone.text(width: 120),
                  const SizedBox(height: 8),
                  Bone.text(width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
