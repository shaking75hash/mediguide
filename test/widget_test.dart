// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mediguide/main.dart';

void main() {
  testWidgets('MediGuide shows the patient and doctor welcome choices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MediGuideApp(isLoggedIn: false));

    expect(find.text('How would you like to continue?'), findsOneWidget);
    expect(find.text('I’m looking for care'), findsOneWidget);
    expect(find.text('I provide care'), findsOneWidget);
    expect(find.text('Create patient account'), findsOneWidget);
    expect(find.text('Sign in as patient'), findsOneWidget);
    expect(find.text('Create doctor account'), findsOneWidget);
    expect(find.text('Sign in as doctor'), findsOneWidget);
    expect(find.text('Administrator sign in'), findsNothing);
  });

  testWidgets('doctor create-account choice opens the profile form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MediGuideApp(isLoggedIn: false));

    final createAccount = find.text('Create doctor account');
    await tester.ensureVisible(createAccount);
    await tester.tap(createAccount);
    await tester.pumpAndSettle();

    expect(find.text('Create doctor account'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Specialty'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Qualification (optional)'), findsOneWidget);
    expect(find.text('Consultation fee'), findsOneWidget);
  });

  testWidgets(
    'doctor tabs keep appointments, profile, and sign out available',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MediGuideApp(isLoggedIn: true, role: 'doctor'),
      );
      await tester.pump();

      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(find.text('Personal profile'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      await tester.tap(find.text('Appointments'));
      await tester.pump();
      expect(find.text('Doctor home'), findsOneWidget);
    },
  );
}
