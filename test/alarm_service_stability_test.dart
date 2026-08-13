import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geo_alarm/models/alarm.dart';
import 'package:geo_alarm/services/alarm_service.dart';

void main() {
	TestWidgetsFlutterBinding.ensureInitialized();

	setUp(() {
		SharedPreferences.setMockInitialValues({});
	});

	group('AlarmService Stability & Reliability (SRE) Tests', () {
		test('hasActiveAlarms is false initially when storage is empty', () async {
			final service = AlarmService();
			expect(service.alarms, isEmpty);
			expect(service.hasActiveAlarms, isFalse);
		});

		test('addAlarm activates high tracking mode state and updates active status', () async {
			final service = AlarmService();

			final alarm = Alarm(
				id: 'test-1',
				name: 'Test Alarm',
				position: const LatLng(-34.6037, -58.3816),
				radiusInMeters: 100,
				triggerType: AlarmTriggerType.arrive,
				isActive: true,
			);

			service.addAlarm(alarm);
			expect(service.alarms.length, equals(1));
			expect(service.hasActiveAlarms, isTrue);
		});

		test('toggleAlarm defensiveness switches to battery saving mode when no alarms active', () async {
			final service = AlarmService();

			final alarm = Alarm(
				id: 'test-toggle',
				name: 'Toggle Alarm',
				position: const LatLng(-34.6037, -58.3816),
				radiusInMeters: 150,
				triggerType: AlarmTriggerType.arrive,
				isActive: true,
			);

			service.addAlarm(alarm);
			expect(service.hasActiveAlarms, isTrue);

			service.toggleAlarm('test-toggle', false);
			expect(service.alarms.first.isActive, isFalse);
			expect(service.hasActiveAlarms, isFalse);
		});

		test('removeAlarm cleans up state and drops to battery saving mode', () async {
			final service = AlarmService();

			final alarm = Alarm(
				id: 'test-remove',
				name: 'Remove Alarm',
				position: const LatLng(-34.6037, -58.3816),
				radiusInMeters: 200,
				triggerType: AlarmTriggerType.arrive,
				isActive: true,
			);

			service.addAlarm(alarm);
			expect(service.alarms.length, equals(1));
			expect(service.hasActiveAlarms, isTrue);

			service.removeAlarm('test-remove');
			expect(service.alarms, isEmpty);
			expect(service.hasActiveAlarms, isFalse);
		});
	});
}
