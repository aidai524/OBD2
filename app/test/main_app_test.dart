import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/main.dart';

void main() {
  testWidgets('starts the scaffold application', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('Hello World!'), findsOneWidget);
  });
}
