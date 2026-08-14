abstract final class UnitConversions {
  static const kilometersPerMile = 1.609344;
  static const kilopascalsPerPsi = 6.894757293168361;

  static double celsiusToFahrenheit(double celsius) {
    return _finite(celsius) * 9 / 5 + 32;
  }

  static double fahrenheitToCelsius(double fahrenheit) {
    return (_finite(fahrenheit) - 32) * (5 / 9);
  }

  static double kilometersPerHourToMilesPerHour(double kilometersPerHour) {
    return _finite(kilometersPerHour) / kilometersPerMile;
  }

  static double milesPerHourToKilometersPerHour(double milesPerHour) {
    return _finite(milesPerHour) * kilometersPerMile;
  }

  static double kilometersToMiles(double kilometers) {
    return _finite(kilometers) / kilometersPerMile;
  }

  static double milesToKilometers(double miles) {
    return _finite(miles) * kilometersPerMile;
  }

  static double kilopascalsToPsi(double kilopascals) {
    return _finite(kilopascals) / kilopascalsPerPsi;
  }

  static double psiToKilopascals(double psi) {
    return _finite(psi) * kilopascalsPerPsi;
  }

  static double _finite(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Must be finite.');
    }
    return value;
  }
}
