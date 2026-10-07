import 'package:flutter_test/flutter_test.dart';
import 'package:mediguide/screens/health_records_screen.dart';

void main() {
  group('calculateBmi', () {
    test('calculates BMI from kilograms and centimeters', () {
      expect(calculateBmi(70, 175), closeTo(22.86, 0.01));
    });

    test('returns null until both valid measurements are available', () {
      expect(calculateBmi(null, 175), isNull);
      expect(calculateBmi(70, null), isNull);
      expect(calculateBmi(0, 175), isNull);
      expect(calculateBmi(70, 0), isNull);
    });
  });
}
