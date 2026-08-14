import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obd2app/core/units/measurement_formatter.dart';
import 'package:obd2app/core/units/unit_system.dart';

final unitSystemProvider = NotifierProvider<UnitSystemController, UnitSystem>(
  UnitSystemController.new,
);

final measurementFormatterProvider = Provider<MeasurementFormatter>((ref) {
  return MeasurementFormatter(ref.watch(unitSystemProvider));
});

final class UnitSystemController extends Notifier<UnitSystem> {
  @override
  UnitSystem build() => UnitSystem.imperial;

  void select(UnitSystem unitSystem) {
    state = unitSystem;
  }
}
