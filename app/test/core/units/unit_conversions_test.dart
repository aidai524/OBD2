import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/core/units/unit_conversions.dart';
import 'package:obd2app/core/units/unit_system.dart';

void main() {
  group('UnitSystem', () {
    test('uses stable profile wire values', () {
      expect(UnitSystem.parse('imperial'), UnitSystem.imperial);
      expect(UnitSystem.parse('metric'), UnitSystem.metric);
      expect(UnitSystem.imperial.wireName, 'imperial');
      expect(UnitSystem.metric.wireName, 'metric');
      expect(() => UnitSystem.parse('unknown'), throwsFormatException);
    });
  });

  group('temperature', () {
    test('converts the fixed Celsius and Fahrenheit anchors', () {
      expect(UnitConversions.celsiusToFahrenheit(0), 32);
      expect(UnitConversions.celsiusToFahrenheit(100), 212);
      expect(UnitConversions.celsiusToFahrenheit(-40), -40);
      expect(UnitConversions.celsiusToFahrenheit(37), closeTo(98.6, 1e-12));
    });

    test('round trips without display rounding', () {
      const celsius = 83.125;
      final fahrenheit = UnitConversions.celsiusToFahrenheit(celsius);
      expect(
        UnitConversions.fahrenheitToCelsius(fahrenheit),
        closeTo(celsius, 1e-12),
      );
    });
  });

  group('speed and distance', () {
    test('converts exact mile anchors and speed values', () {
      expect(
        UnitConversions.kilometersPerHourToMilesPerHour(96.56064),
        closeTo(60, 1e-12),
      );
      expect(
        UnitConversions.kilometersPerHourToMilesPerHour(100),
        closeTo(62.137119223733, 1e-12),
      );
      expect(
        UnitConversions.milesToKilometers(1),
        UnitConversions.kilometersPerMile,
      );
      expect(
        UnitConversions.kilometersToMiles(1),
        closeTo(0.621371192237334, 1e-15),
      );
    });

    test('round trips speed and distance without rounding', () {
      const kilometers = 1234.567;
      const kilometersPerHour = 137.25;
      expect(
        UnitConversions.milesToKilometers(
          UnitConversions.kilometersToMiles(kilometers),
        ),
        closeTo(kilometers, 1e-9),
      );
      expect(
        UnitConversions.milesPerHourToKilometersPerHour(
          UnitConversions.kilometersPerHourToMilesPerHour(kilometersPerHour),
        ),
        closeTo(kilometersPerHour, 1e-9),
      );
    });
  });

  group('pressure', () {
    test('converts the exact psi anchor and round trips', () {
      expect(
        UnitConversions.kilopascalsToPsi(UnitConversions.kilopascalsPerPsi),
        closeTo(1, 1e-12),
      );
      expect(
        UnitConversions.kilopascalsToPsi(100),
        closeTo(14.503773773021, 1e-12),
      );
      expect(
        UnitConversions.psiToKilopascals(
          UnitConversions.kilopascalsToPsi(234.5),
        ),
        closeTo(234.5, 1e-9),
      );
    });
  });

  test('rejects non-finite inputs from every public conversion', () {
    final conversions = <double Function(double)>[
      UnitConversions.celsiusToFahrenheit,
      UnitConversions.fahrenheitToCelsius,
      UnitConversions.kilometersPerHourToMilesPerHour,
      UnitConversions.milesPerHourToKilometersPerHour,
      UnitConversions.kilometersToMiles,
      UnitConversions.milesToKilometers,
      UnitConversions.kilopascalsToPsi,
      UnitConversions.psiToKilopascals,
    ];
    const invalidValues = [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ];

    for (final conversion in conversions) {
      for (final value in invalidValues) {
        expect(() => conversion(value), throwsArgumentError);
      }
    }
  });
}
