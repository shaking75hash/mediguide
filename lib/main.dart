import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔍 Ask the backend: "Is my saved token still good?"
  bool isLoggedIn = false;
  try {
    await ApiService.getMe(); // succeeds only if token is valid
    isLoggedIn = true;
  } catch (e) {
    isLoggedIn = false; // no token, or expired → must login
  }

  runApp(MediGuideApp(isLoggedIn: isLoggedIn));
}

class MediGuideApp extends StatelessWidget {
  final bool isLoggedIn;
  const MediGuideApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediGuide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
