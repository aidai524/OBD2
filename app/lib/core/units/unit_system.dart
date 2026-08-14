enum UnitSystem {
  imperial('imperial'),
  metric('metric');

  const UnitSystem(this.wireName);

  final String wireName;

  static UnitSystem parse(String value) {
    return switch (value) {
      'imperial' => UnitSystem.imperial,
      'metric' => UnitSystem.metric,
      _ => throw FormatException('Unsupported unit system: $value'),
    };
  }
}
