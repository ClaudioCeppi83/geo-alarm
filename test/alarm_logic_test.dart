import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geo_alarm/models/alarm.dart';

void main() {
  group('Geofence Distance and Trigger Tests', () {
    test('should calculate distance accurately between coordinates', () {
      // Obelisco Buenos Aires to Plaza de Mayo (approx 1.1 km)
      const double lat1 = -34.6037;
      const double lon1 = -58.3816;
      const double lat2 = -34.6084;
      const double lon2 = -58.3719;

      final double distance = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

      // Distance should be approximately between 1000m and 1200m
      expect(distance, greaterThan(1000.0));
      expect(distance, lessThan(1200.0));
    });

    test('should detect inside radius correctly for arrive alarm', () {
      const alarmCenter = LatLng(-34.6037, -58.3816);
      const userLocation = LatLng(-34.6038, -58.3817); // ~15 meters away

      const alarm = Alarm(
        id: 'arrive-1',
        name: 'Zona Segura',
        position: alarmCenter,
        radiusInMeters: 100.0,
        triggerType: AlarmTriggerType.arrive,
        isActive: true,
      );

      final double distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        alarm.position.latitude,
        alarm.position.longitude,
      );

      final bool isInside = distance <= alarm.radiusInMeters;
      expect(isInside, isTrue);
    });

    test('should detect outside radius for leave alarm', () {
      const alarmCenter = LatLng(-34.6037, -58.3816);
      const userLocation = LatLng(-34.6200, -58.4000); // > 2 km away

      const alarm = Alarm(
        id: 'leave-1',
        name: 'Zona Salida',
        position: alarmCenter,
        radiusInMeters: 500.0,
        triggerType: AlarmTriggerType.leave,
        isActive: true,
        lastKnownInside: true,
      );

      final double distance = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        alarm.position.latitude,
        alarm.position.longitude,
      );

      final bool isInside = distance <= alarm.radiusInMeters;
      expect(isInside, isFalse);
      expect(alarm.lastKnownInside, isTrue);
    });
  });
}
