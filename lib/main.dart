import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/register_screens.dart';
import 'screens/welcome_screen.dart';
import 'services/appointment_notification_service.dart';
import 'services/api_service.dart';
import 'screens/role_screens.dart';
import 'services/token_storage.dart';

class AppColors {
  static const Color bgBase = Color(0xFFF9F9F7); // Warm paper
  static const Color surface = Color(0xFFFFFFFF); // Pure white cards
  static const Color textPrimary = Color(0xFF1E293B); // Deep slate
  static const Color textSecondary = Color(0xFF64748B); // Muted grey
  static const Color brandPrimary = Color(0xFF4A7C59); // Muted sage
  static const Color brandLight = Color(0xFFE8F0EB); // Sage tint
  static const Color accentWarm = Color(0xFFD6A89C); // Soft clay
  static const Color border = Color(0xFFE2E8F0);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgBase,

      // ✨ Premium Typography Pairing
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        headlineLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
        bodyLarge: const TextStyle(
          fontSize: 16,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        bodySmall: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
        labelSmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
          color: AppColors.textSecondary,
        ),
      ),

      // ✨ Refined Component Themes
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.brandPrimary,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.brandPrimary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var isLoggedIn = false;
  String activeRole = 'patient';
  activeRole = await TokenStorage.getActiveRole() ?? 'patient';
  if (activeRole != 'patient' && activeRole != 'doctor') {
    await TokenStorage.clearAll();
    activeRole = 'patient';
  }
  if (activeRole == 'doctor') {
    final token = await TokenStorage.getToken(role: 'doctor');
    if (token == null) {
      await TokenStorage.clearActiveRole();
      activeRole = 'patient';
    } else {
      try {
        await ApiService.getDoctorAppointments('');
        isLoggedIn = true;
      } catch (_) {
        await TokenStorage.clearToken(role: 'doctor');
        await TokenStorage.clearActiveRole();
        activeRole = 'patient';
      }
    }
  } else {
    final token = await TokenStorage.getToken(role: 'patient');
    if (token != null) {
      try {
        await ApiService.getMe();
        isLoggedIn = true;
      } catch (_) {
        await TokenStorage.clearToken(role: 'patient');
        await TokenStorage.clearActiveRole();
      }
    }
  }
  if (isLoggedIn && activeRole == 'patient') {
    try {
      final appointments = await ApiService.getMyAppointments();
      await AppointmentNotificationService.syncIfPermitted(appointments);
    } catch (error) {
      debugPrint('Could not resync appointment reminders: $error');
    }
  }

  runApp(MediGuideApp(isLoggedIn: isLoggedIn, role: activeRole));
}

class MediGuideApp extends StatelessWidget {
  final bool isLoggedIn;
  final String role;

  const MediGuideApp({super.key, required this.isLoggedIn, this.role = 'patient'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediGuide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: !isLoggedIn
          ? const WelcomeScreen()
          : role == 'doctor'
              ? const DoctorHomeScreen()
              : const AppShell(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/welcome':
            return MaterialPageRoute(
              builder: (_) => const WelcomeScreen(),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          case '/register':
            return MaterialPageRoute(
              builder: (_) => const RegisterScreen(),
            );
          case '/doctor':
            return MaterialPageRoute(
              builder: (_) => const DoctorLoginScreen(),
            );
          case '/doctor/register':
            return MaterialPageRoute(
              builder: (_) => const RegisterAsDoctorScreen(),
            );
        }
        return null;
      },
    );
  }
}
