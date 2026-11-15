import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediguide/screens/your_care_screen.dart';

void main() {
  testWidgets('offers doctor and hospital search choices', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: YourCareScreen()));

    expect(find.text('Your care'), findsOneWidget);
    expect(find.text('Doctors'), findsOneWidget);
    expect(find.text('Hospitals'), findsOneWidget);
    expect(find.text('Disease, health concern, or specialty'), findsOneWidget);
    expect(find.text('Preferred location'), findsOneWidget);

    await tester.tap(find.text('Hospitals'));
    await tester.pump();

    expect(find.text('Hospitals'), findsOneWidget);
  });

  testWidgets('requires a concern and preferred location', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: YourCareScreen()));

    await tester.tap(find.text('Find care'));
    await tester.pump();

    expect(find.text('Enter a health concern or specialty'), findsOneWidget);
    expect(find.text('Enter a city or area'), findsOneWidget);
  });
}
