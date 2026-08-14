import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/core/units/display_measurement.dart';
import 'package:obd2app/core/units/measurement_formatter.dart';
import 'package:obd2app/core/units/unit_system.dart';
import 'package:obd2app/core/units/unit_system_provider.dart';

void main() {
  final imperial = MeasurementFormatter(UnitSystem.imperial);
  final metric = MeasurementFormatter(UnitSystem.metric);

  test('defaults the application preference to imperial and can switch', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(unitSystemProvider), UnitSystem.imperial);
    expect(
      container
          .read(measurementFormatterProvider)
          .format(
            container
                .read(measurementFormatterProvider)
                .speedFromKilometersPerHour(100),
          ),
      '62 mph',
    );

    container.read(unitSystemProvider.notifier).select(UnitSystem.metric);

    expect(container.read(unitSystemProvider), UnitSystem.metric);
    final metricFormatter = container.read(measurementFormatterProvider);
    expect(
      metricFormatter.format(metricFormatter.speedFromKilometersPerHour(100)),
      '100 km/h',
    );

    final freshContainer = ProviderContainer();
    addTearDown(freshContainer.dispose);
    expect(freshContainer.read(unitSystemProvider), UnitSystem.imperial);
  });

  test('formats temperature and speed for both systems', () {
    expect(imperial.format(imperial.temperatureFromCelsius(37)), '98.6 °F');
    expect(metric.format(metric.temperatureFromCelsius(37)), '37 °C');
    expect(imperial.format(imperial.speedFromKilometersPerHour(100)), '62 mph');
    expect(metric.format(metric.speedFromKilometersPerHour(100)), '100 km/h');
  });

  test('keeps PID kilometers distinct from stored mileage miles', () {
    const pidDistanceKilometers = 100.0;
    const storedMileageMiles = 12345;

    expect(
      imperial.format(
        imperial.pidDistanceFromKilometers(pidDistanceKilometers),
      ),
      '62.1 mi',
    );
    expect(
      metric.format(metric.pidDistanceFromKilometers(pidDistanceKilometers)),
      '100 km',
    );
    expect(
      imperial.format(imperial.storedMileageFromMiles(storedMileageMiles)),
      '12,345 mi',
    );
    expect(
      metric.format(metric.storedMileageFromMiles(storedMileageMiles)),
      '19,867 km',
    );

    expect(pidDistanceKilometers, 100);
    expect(storedMileageMiles, 12345);
  });

  test('formats pressure using psi only for imperial display', () {
    expect(imperial.format(imperial.pressureFromKilopascals(100)), '14.5 psi');
    expect(metric.format(metric.pressureFromKilopascals(100)), '100 kPa');
  });

  test('does not convert unit-independent PID quantities', () {
    expect(imperial.format(imperial.percentage(45.098)), '45.1 %');
    expect(metric.format(metric.percentage(45.098)), '45.1 %');
    expect(imperial.format(imperial.engineSpeedRpm(1800)), '1,800 RPM');
    expect(metric.format(metric.engineSpeedRpm(1800)), '1,800 RPM');
    expect(
      imperial.format(imperial.massFlowGramsPerSecond(12.34)),
      '12.34 g/s',
    );
    expect(metric.format(metric.voltage(12.656)), '12.66 V');
    expect(metric.format(metric.durationSeconds(90)), '90 s');
    expect(metric.format(metric.durationMinutes(3)), '3 min');
  });

  test('normalizes negative zero and separates value from unit', () {
    final measurement = imperial.temperatureFromCelsius(-17.77777777777778);

    expect(measurement.value, 0);
    expect(measurement.unit, DisplayUnit.fahrenheit);
    expect(imperial.formatValue(measurement), '0');
    expect(imperial.format(measurement), '0 °F');
    expect(
      metric.format(
        DisplayMeasurement(
          value: -0.04,
          unit: DisplayUnit.kilometersPerHour,
          maximumFractionDigits: 0,
        ),
      ),
      '0 km/h',
    );
  });

  test('rejects invalid display measurements', () {
    expect(
      () => DisplayMeasurement(
        value: double.nan,
        unit: DisplayUnit.celsius,
        maximumFractionDigits: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => DisplayMeasurement(
        value: 1,
        unit: DisplayUnit.celsius,
        maximumFractionDigits: -1,
      ),
      throwsRangeError,
    );
  });
}
