import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geo_alarm/main.dart';
import 'package:geo_alarm/screens/map_screen.dart';
import 'package:geo_alarm/services/alarm_service.dart';

void main() {
	TestWidgetsFlutterBinding.ensureInitialized();

	setUp(() {
		SharedPreferences.setMockInitialValues({});
	});

	testWidgets('GeoAlarmApp renders MultiProvider and loads MapScreen without crashing', (WidgetTester tester) async {
		await tester.pumpWidget(
			MultiProvider(
				providers: [
					ChangeNotifierProvider(create: (_) => AlarmService()),
				],
				child: const GeoAlarmApp(),
			),
		);

		await tester.pump();

		expect(find.byType(MapScreen), findsOneWidget);
		expect(find.text('Geo Alarm'), findsWidgets);
		expect(find.text('Tus Geocercas'), findsOneWidget);
	});
}
