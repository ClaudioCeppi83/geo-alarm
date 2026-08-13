import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geo_alarm/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GeoAlarmApp smoke test renders title and UI components',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GeoAlarmApp());
    await tester.pump();

    // Verify that AppBar title is rendered
    expect(find.text('Geo Alarm'), findsOneWidget);

    // Verify that the bottom panel with 'Alarmas' is rendered
    expect(find.textContaining('Alarmas'), findsOneWidget);
  });
}
