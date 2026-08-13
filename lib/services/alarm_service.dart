import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm.dart';

class AlarmService extends ChangeNotifier {
  static const String _storageKey = 'geo_alarms_list';

  final List<Alarm> _alarms = [];
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRinging = false;
  Alarm? _activeRingingAlarm;

  List<Alarm> get alarms => List.unmodifiable(_alarms);
  Position? get currentPosition => _currentPosition;
  bool get isRinging => _isRinging;
  Alarm? get activeRingingAlarm => _activeRingingAlarm;

  AlarmService() {
    _initNotifications();
    _loadAlarmsFromStorage();
    _startLocationTracking();
  }

  void _initNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _notificationsPlugin.initialize(initializationSettings);
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  Future<void> _loadAlarmsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? alarmsJson = prefs.getString(_storageKey);
      if (alarmsJson != null && alarmsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(alarmsJson) as List<dynamic>;
        _alarms.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _alarms.add(Alarm.fromJson(item));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading alarms from SharedPreferences: $e');
    }
  }

  Future<void> _saveAlarmsToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> data = _alarms.map((a) => a.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving alarms to SharedPreferences: $e');
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
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
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
    }
  }

  void _checkAlarms(Position position) {
    bool hasChanges = false;

    for (int i = 0; i < _alarms.length; i++) {
      final alarm = _alarms[i];
      if (!alarm.isActive) continue;

      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        alarm.position.latitude,
        alarm.position.longitude,
      );

      final bool isInsideRadius = distance <= alarm.radiusInMeters;

      if (alarm.triggerType == AlarmTriggerType.arrive) {
        if (isInsideRadius) {
          _triggerAlarm(alarm);
        }
      } else if (alarm.triggerType == AlarmTriggerType.leave) {
        if (alarm.lastKnownInside == null) {
          // Initialize state based on current location to avoid false positive
          _alarms[i] = alarm.copyWith(lastKnownInside: isInsideRadius);
          hasChanges = true;
        } else if (alarm.lastKnownInside == true && !isInsideRadius) {
          // User was inside and has now exited the radius -> Trigger
          _alarms[i] = alarm.copyWith(lastKnownInside: false);
          hasChanges = true;
          _triggerAlarm(alarm);
        } else if (alarm.lastKnownInside == false && isInsideRadius) {
          // User entered or returned inside radius
          _alarms[i] = alarm.copyWith(lastKnownInside: true);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      _saveAlarmsToStorage();
    }
  }

  void _triggerAlarm(Alarm alarm) async {
    // Disable alarm to avoid continuous triggering
    toggleAlarm(alarm.id, false);

    _isRinging = true;
    _activeRingingAlarm = alarm;
    notifyListeners();

    // 1. Push Notification
    try {
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
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }

    // 2. Vibration
    try {
      final bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(
          pattern: [500, 1000, 500, 1000, 500, 1000],
          repeat: 0,
        );
      }
    } catch (e) {
      debugPrint('Error starting vibration: $e');
    }

    // 3. Sound
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/alarm.mp3'));
    } catch (e) {
      debugPrint('Error playing alarm audio: $e');
    }
  }

  Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping audio player: $e');
    }

    try {
      Vibration.cancel();
    } catch (e) {
      debugPrint('Error canceling vibration: $e');
    }

    _isRinging = false;
    _activeRingingAlarm = null;
    notifyListeners();
  }

  void addAlarm(Alarm alarm) {
    Alarm alarmToAdd = alarm;
    if (_currentPosition != null && alarm.lastKnownInside == null) {
      final double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        alarm.position.latitude,
        alarm.position.longitude,
      );
      alarmToAdd = alarm.copyWith(lastKnownInside: distance <= alarm.radiusInMeters);
    }

    _alarms.add(alarmToAdd);
    _saveAlarmsToStorage();
    notifyListeners();
  }

  void toggleAlarm(String id, bool isActive) {
    final int index = _alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      bool? newLastKnownInside = _alarms[index].lastKnownInside;
      if (isActive && _alarms[index].triggerType == AlarmTriggerType.leave) {
        if (_currentPosition != null) {
          final double distance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            _alarms[index].position.latitude,
            _alarms[index].position.longitude,
          );
          newLastKnownInside = distance <= _alarms[index].radiusInMeters;
        } else {
          newLastKnownInside = null;
        }
      }

      _alarms[index] = _alarms[index].copyWith(
        isActive: isActive,
        lastKnownInside: newLastKnownInside,
      );
      _saveAlarmsToStorage();
      notifyListeners();
    }
  }

  void removeAlarm(String id) {
    _alarms.removeWhere((a) => a.id == id);
    _saveAlarmsToStorage();
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    try {
      _audioPlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing audio player: $e');
    }
    super.dispose();
  }
}
