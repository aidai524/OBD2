import 'package:intl/intl.dart';
import 'package:obd2app/core/i18n/app_locale.dart';
import 'package:obd2app/core/units/display_measurement.dart';
import 'package:obd2app/core/units/unit_conversions.dart';
import 'package:obd2app/core/units/unit_system.dart';

final class MeasurementFormatter {
  MeasurementFormatter(this.unitSystem);

  final UnitSystem unitSystem;
  final Map<int, NumberFormat> _formats = {};

  DisplayMeasurement temperatureFromCelsius(double celsius) {
    return switch (unitSystem) {
      UnitSystem.imperial => DisplayMeasurement(
        value: UnitConversions.celsiusToFahrenheit(celsius),
        unit: DisplayUnit.fahrenheit,
        maximumFractionDigits: 1,
      ),
      UnitSystem.metric => DisplayMeasurement(
        value: celsius,
        unit: DisplayUnit.celsius,
        maximumFractionDigits: 1,
      ),
    };
  }

  DisplayMeasurement speedFromKilometersPerHour(double kilometersPerHour) {
    return switch (unitSystem) {
      UnitSystem.imperial => DisplayMeasurement(
        value: UnitConversions.kilometersPerHourToMilesPerHour(
          kilometersPerHour,
        ),
        unit: DisplayUnit.milesPerHour,
        maximumFractionDigits: 0,
      ),
      UnitSystem.metric => DisplayMeasurement(
        value: kilometersPerHour,
        unit: DisplayUnit.kilometersPerHour,
        maximumFractionDigits: 0,
      ),
    };
  }

  DisplayMeasurement pressureFromKilopascals(double kilopascals) {
    return switch (unitSystem) {
      UnitSystem.imperial => DisplayMeasurement(
        value: UnitConversions.kilopascalsToPsi(kilopascals),
        unit: DisplayUnit.psi,
        maximumFractionDigits: 1,
      ),
      UnitSystem.metric => DisplayMeasurement(
        value: kilopascals,
        unit: DisplayUnit.kilopascals,
        maximumFractionDigits: 0,
      ),
    };
  }

  DisplayMeasurement pidDistanceFromKilometers(double kilometers) {
    return switch (unitSystem) {
      UnitSystem.imperial => DisplayMeasurement(
        value: UnitConversions.kilometersToMiles(kilometers),
        unit: DisplayUnit.miles,
        maximumFractionDigits: 1,
      ),
      UnitSystem.metric => DisplayMeasurement(
        value: kilometers,
        unit: DisplayUnit.kilometers,
        maximumFractionDigits: 0,
      ),
    };
  }

  DisplayMeasurement storedMileageFromMiles(int miles) {
    final mileage = miles.toDouble();
    return switch (unitSystem) {
      UnitSystem.imperial => DisplayMeasurement(
        value: mileage,
        unit: DisplayUnit.miles,
        maximumFractionDigits: 0,
      ),
      UnitSystem.metric => DisplayMeasurement(
        value: UnitConversions.milesToKilometers(mileage),
        unit: DisplayUnit.kilometers,
        maximumFractionDigits: 0,
      ),
    };
  }

  DisplayMeasurement percentage(double value) {
    return DisplayMeasurement(
      value: value,
      unit: DisplayUnit.percent,
      maximumFractionDigits: 1,
    );
  }

  DisplayMeasurement engineSpeedRpm(double value) {
    return DisplayMeasurement(
      value: value,
      unit: DisplayUnit.revolutionsPerMinute,
      maximumFractionDigits: 0,
    );
  }

  DisplayMeasurement massFlowGramsPerSecond(double value) {
    return DisplayMeasurement(
      value: value,
      unit: DisplayUnit.gramsPerSecond,
      maximumFractionDigits: 2,
    );
  }

  DisplayMeasurement voltage(double value) {
    return DisplayMeasurement(
      value: value,
      unit: DisplayUnit.volts,
      maximumFractionDigits: 2,
    );
  }

  DisplayMeasurement durationSeconds(double value) {
    return DisplayMeasurement(
      value: value,
      unit: DisplayUnit.seconds,
      maximumFractionDigits: 0,
    );
  }

  DisplayMeasurement durationMinutes(double value) {
    return DisplayMeasurement(
      value: value,
      unit: DisplayUnit.minutes,
      maximumFractionDigits: 0,
    );
  }

  String formatValue(DisplayMeasurement measurement) {
    final formatted = _formatFor(measurement.maximumFractionDigits)
        .format(measurement.value);
    return formatted == '-0' ? '0' : formatted;
  }

  String format(DisplayMeasurement measurement) {
    return '${formatValue(measurement)} ${measurement.unit.symbol}';
  }

  NumberFormat _formatFor(int maximumFractionDigits) {
    return _formats.putIfAbsent(maximumFractionDigits, () {
      return NumberFormat.decimalPattern(AppLocale.intlName)
        ..minimumFractionDigits = 0
        ..maximumFractionDigits = maximumFractionDigits;
    });
  }
}
