// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mediguide/main.dart';

void main() {
  testWidgets('MediGuide app transitions from splash to login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MediGuideApp());

    expect(find.text('MediGuide'), findsOneWidget);
    expect(find.text('Your Health, Your Choice'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
