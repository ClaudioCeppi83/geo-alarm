import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geo_alarm/models/alarm.dart';

void main() {
  group('Alarm Model serialization tests', () {
    test('toJson and fromJson for arrive trigger', () {
      final alarm = Alarm(
        id: 'alarm-123',
        name: 'Casa',
        position: const LatLng(-34.6037, -58.3816),
        radiusInMeters: 300.0,
        triggerType: AlarmTriggerType.arrive,
        isActive: true,
        lastKnownInside: false,
      );

      final json = alarm.toJson();
      expect(json['id'], 'alarm-123');
      expect(json['name'], 'Casa');
      expect(json['latitude'], -34.6037);
      expect(json['longitude'], -58.3816);
      expect(json['radiusInMeters'], 300.0);
      expect(json['triggerType'], 'arrive');
      expect(json['isActive'], true);
      expect(json['lastKnownInside'], false);

      final decoded = Alarm.fromJson(json);
      expect(decoded.id, alarm.id);
      expect(decoded.name, alarm.name);
      expect(decoded.position.latitude, alarm.position.latitude);
      expect(decoded.position.longitude, alarm.position.longitude);
      expect(decoded.radiusInMeters, alarm.radiusInMeters);
      expect(decoded.triggerType, alarm.triggerType);
      expect(decoded.isActive, alarm.isActive);
      expect(decoded.lastKnownInside, alarm.lastKnownInside);
    });

    test('toJson and fromJson for leave trigger with null lastKnownInside', () {
      final alarm = Alarm(
        id: 'alarm-456',
        name: 'Oficina',
        position: const LatLng(40.4168, -3.7038),
        radiusInMeters: 750.0,
        triggerType: AlarmTriggerType.leave,
        isActive: false,
        lastKnownInside: null,
      );

      final json = alarm.toJson();
      expect(json['triggerType'], 'leave');
      expect(json['isActive'], false);
      expect(json['lastKnownInside'], isNull);

      final decoded = Alarm.fromJson(json);
      expect(decoded.id, 'alarm-456');
      expect(decoded.name, 'Oficina');
      expect(decoded.triggerType, AlarmTriggerType.leave);
      expect(decoded.isActive, false);
      expect(decoded.lastKnownInside, isNull);
    });

    test('copyWith works properly', () {
      final alarm = Alarm(
        id: '1',
        name: 'Test',
        position: const LatLng(10, 20),
        radiusInMeters: 200,
        triggerType: AlarmTriggerType.arrive,
      );

      final updated = alarm.copyWith(
        isActive: false,
        lastKnownInside: true,
      );

      expect(updated.id, '1');
      expect(updated.isActive, false);
      expect(updated.lastKnownInside, true);
    });
  });
}
