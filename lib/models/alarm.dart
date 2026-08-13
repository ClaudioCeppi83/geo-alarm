import 'package:google_maps_flutter/google_maps_flutter.dart';

enum AlarmTriggerType {
  arrive,
  leave,
}

class Alarm {
  final String id;
  final String name;
  final LatLng position;
  final double radiusInMeters;
  final AlarmTriggerType triggerType;
  final bool isActive;

  Alarm({
    required this.id,
    required this.name,
    required this.position,
    required this.radiusInMeters,
    required this.triggerType,
    this.isActive = true,
  });

  Alarm copyWith({
    String? id,
    String? name,
    LatLng? position,
    double? radiusInMeters,
    AlarmTriggerType? triggerType,
    bool? isActive,
  }) {
    return Alarm(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      radiusInMeters: radiusInMeters ?? this.radiusInMeters,
      triggerType: triggerType ?? this.triggerType,
      isActive: isActive ?? this.isActive,
    );
  }
}
