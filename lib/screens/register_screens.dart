import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), centerTitle: true),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),

        child: Column(
          children: [
            const SizedBox(height: 20),

            const Icon(Icons.person_add, size: 80, color: Colors.blue),

            const SizedBox(height: 20),

            const Text(
              'Create Your Account',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'Join MediGuide today',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 30),

            TextField(
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Firebase registration will be added later.
                },
                child: const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),

            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? '),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
