import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/alarm.dart';

class AlarmService extends ChangeNotifier {
  final List<Alarm> _alarms = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Alarm> get alarms => _alarms;
  Position? get currentPosition => _currentPosition;

  AlarmService() {
    _initNotifications();
    _startLocationTracking();
  }

  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      if (position != null) {
        _currentPosition = position;
        _checkAlarms(position);
        notifyListeners();
      }
    });
  }

  void _checkAlarms(Position position) {
    for (var alarm in _alarms) {
      if (!alarm.isActive) continue;

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        alarm.position.latitude,
        alarm.position.longitude,
      );

      bool isInsideRadius = distance <= alarm.radiusInMeters;

      if (alarm.triggerType == AlarmTriggerType.arrive && isInsideRadius) {
        _triggerAlarm(alarm);
      } else if (alarm.triggerType == AlarmTriggerType.leave && !isInsideRadius) {
        // Here we'd need more logic to know if they were inside previously,
        // but for the prototype we will simplify it: if it's a leave alarm and they are outside, trigger.
        // In a real app we track previous state.
        _triggerAlarm(alarm);
      }
    }
  }

  void _triggerAlarm(Alarm alarm) async {
    // Disable alarm to avoid continuous triggering
    toggleAlarm(alarm.id, false);

    // 1. Push Notification
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'geo_alarm_channel',
      'Geo Alarms',
      channelDescription: 'Notifications for location based alarms',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      0,
      '¡Alarma de Ubicación!',
      'Alarma disparada: ${alarm.name}',
      platformDetails,
    );

    // 2. Vibration
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000]);
    }

    // 3. Sound
    // Requiere un archivo en assets/audio/alarm.mp3 que debera ser agregado.
    // Para el prototipo intentamos reproducir un sonido de sistema o asset.
    await _audioPlayer.play(AssetSource('audio/alarm.mp3'));
  }

  void addAlarm(Alarm alarm) {
    _alarms.add(alarm);
    notifyListeners();
  }

  void toggleAlarm(String id, bool isActive) {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alarms[index] = _alarms[index].copyWith(isActive: isActive);
      notifyListeners();
    }
  }

  void removeAlarm(String id) {
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
