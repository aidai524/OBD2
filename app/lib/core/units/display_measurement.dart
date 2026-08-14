enum MeasurementQuantity {
  temperature,
  speed,
  pressure,
  distance,
  percentage,
  engineSpeed,
  massFlow,
  voltage,
  duration,
}

enum DisplayUnit {
  fahrenheit('°F', MeasurementQuantity.temperature),
  celsius('°C', MeasurementQuantity.temperature),
  milesPerHour('mph', MeasurementQuantity.speed),
  kilometersPerHour('km/h', MeasurementQuantity.speed),
  psi('psi', MeasurementQuantity.pressure),
  kilopascals('kPa', MeasurementQuantity.pressure),
  miles('mi', MeasurementQuantity.distance),
  kilometers('km', MeasurementQuantity.distance),
  percent('%', MeasurementQuantity.percentage),
  revolutionsPerMinute('RPM', MeasurementQuantity.engineSpeed),
  gramsPerSecond('g/s', MeasurementQuantity.massFlow),
  volts('V', MeasurementQuantity.voltage),
  seconds('s', MeasurementQuantity.duration),
  minutes('min', MeasurementQuantity.duration);

  const DisplayUnit(this.symbol, this.quantity);

  final String symbol;
  final MeasurementQuantity quantity;
}

final class DisplayMeasurement {
  DisplayMeasurement({
    required double value,
    required this.unit,
    required this.maximumFractionDigits,
  }) : value = _normalized(value) {
    if (maximumFractionDigits < 0) {
      throw RangeError.value(
        maximumFractionDigits,
        'maximumFractionDigits',
        'Must not be negative.',
      );
    }
  }

  final double value;
  final DisplayUnit unit;
  final int maximumFractionDigits;

  static double _normalized(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Must be finite.');
    }
    return value == 0 ? 0 : value;
  }
}
