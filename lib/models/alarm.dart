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
  final bool? lastKnownInside;

  Alarm({
    required this.id,
    required this.name,
    required this.position,
    required this.radiusInMeters,
    required this.triggerType,
    this.isActive = true,
    this.lastKnownInside,
  });

  Alarm copyWith({
    String? id,
    String? name,
    LatLng? position,
    double? radiusInMeters,
    AlarmTriggerType? triggerType,
    bool? isActive,
    bool? lastKnownInside,
    bool clearLastKnownInside = false,
  }) {
    return Alarm(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      radiusInMeters: radiusInMeters ?? this.radiusInMeters,
      triggerType: triggerType ?? this.triggerType,
      isActive: isActive ?? this.isActive,
      lastKnownInside: clearLastKnownInside
          ? null
          : (lastKnownInside ?? this.lastKnownInside),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'radiusInMeters': radiusInMeters,
      'triggerType': triggerType.name,
      'isActive': isActive,
      'lastKnownInside': lastKnownInside,
    };
  }

  factory Alarm.fromJson(Map<String, dynamic> json) {
    final double lat = (json['latitude'] as num).toDouble();
    final double lng = (json['longitude'] as num).toDouble();
    final String triggerTypeName = json['triggerType'] as String? ?? 'arrive';

    return Alarm(
      id: json['id'] as String,
      name: json['name'] as String,
      position: LatLng(lat, lng),
      radiusInMeters: (json['radiusInMeters'] as num?)?.toDouble() ?? 500.0,
      triggerType: AlarmTriggerType.values.firstWhere(
        (e) => e.name == triggerTypeName || e.toString() == triggerTypeName,
        orElse: () => AlarmTriggerType.arrive,
      ),
      isActive: json['isActive'] as bool? ?? true,
      lastKnownInside: json['lastKnownInside'] as bool?,
    );
  }
}
