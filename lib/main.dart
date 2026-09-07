import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

void main() {
  runApp(const MediGuideApp());
}

class MediGuideApp extends StatelessWidget {
  const MediGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediGuide',

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      home: const SplashScreen(),
    );
  }
}
