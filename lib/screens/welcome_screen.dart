import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _ink = Color(0xFF183B31);
  static const _green = Color(0xFF347452);
  static const _muted = Color(0xFF728078);
  static const _background = Color(0xFFF6F8F5);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.health_and_safety_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'MediGuide',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF245C43), Color(0xFF4A8060)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.waving_hand_rounded,
                            color: Color(0xFFD8C58B),
                            size: 30,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Care starts with\na better connection.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Find trusted care, manage appointments, '
                            'and make confident health decisions.',
                            style: TextStyle(
                              color: Color(0xFFE4EEE7),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'How would you like to continue?',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      icon: Icons.favorite_rounded,
                      title: 'I’m looking for care',
                      description: 'Explore doctors and manage your health.',
                      createLabel: 'Create patient account',
                      signInLabel: 'Sign in as patient',
                      onCreate: () => Navigator.pushNamed(context, '/register'),
                      onSignIn: () => Navigator.pushNamed(context, '/login'),
                    ),
                    const SizedBox(height: 14),
                    _RoleCard(
                      icon: Icons.medical_services_rounded,
                      title: 'I provide care',
                      description: 'Create a doctor profile or manage your practice.',
                      createLabel: 'Create doctor account',
                      signInLabel: 'Sign in as doctor',
                      onCreate: () =>
                          Navigator.pushNamed(context, '/doctor/register'),
                      onSignIn: () => Navigator.pushNamed(context, '/doctor'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Doctor profiles are self-reported and are not independently verified.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.createLabel,
    required this.signInLabel,
    required this.onCreate,
    required this.onSignIn,
  });

  final IconData icon;
  final String title;
  final String description;
  final String createLabel;
  final String signInLabel;
  final VoidCallback onCreate;
  final VoidCallback onSignIn;

  static const _ink = Color(0xFF183B31);
  static const _green = Color(0xFF347452);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE4EBE6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: _green, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Color(0xFF728078),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCreate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: Color(0xFFB8CCBE)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(createLabel, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onSignIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(signInLabel, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
