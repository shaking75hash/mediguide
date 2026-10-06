import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediguide/models/provider.dart';
import 'package:mediguide/widgets/provider_card.dart';
import 'package:mediguide/widgets/trust_badge.dart';

Provider _provider({double rating = 0, int reviewCount = 0}) {
  return Provider(
    id: 'doctor-1',
    name: 'Dr. Example',
    type: 'Doctor',
    specialty: 'Cardiology',
    location: 'Dhaka',
    rating: rating,
    reviewCount: reviewCount,
    price: 800,
    imageUrl: '',
    email: '',
    phone: '',
    workingHours: 'Available',
  );
}

void main() {
  testWidgets('does not show a star rating when there are no reviews', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProviderCard(provider: _provider())),
      ),
    );

    expect(find.text('Not rated yet'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.textContaining('reviews'), findsNothing);
  });

  testWidgets('shows the rating and review count when reviews exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderCard(provider: _provider(rating: 4.8, reviewCount: 12)),
        ),
      ),
    );

    expect(find.text('4.8 · 12 reviews'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('trust badge does not score doctors with no reviews', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TrustBadge(score: 0, verifiedReviews: 0)),
      ),
    );

    expect(find.text('No verified reviews yet'), findsOneWidget);
    expect(find.text('0.0 / 5.0'), findsNothing);
    expect(find.text('Needs Improvement'), findsNothing);
  });
}
