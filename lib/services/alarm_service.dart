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
	StreamSubscription<ServiceStatus>? _serviceStatusStream;

	final FlutterLocalNotificationsPlugin _notificationsPlugin =
			FlutterLocalNotificationsPlugin();
	final AudioPlayer _audioPlayer = AudioPlayer();

	bool _isInitialized = false;
	bool _isDisposed = false;
	bool _isEvaluating = false;
	bool _isRinging = false;
	Alarm? _activeRingingAlarm;

	List<Alarm> get alarms => List.unmodifiable(_alarms);
	Position? get currentPosition => _currentPosition;
	bool get isRinging => _isRinging;
	Alarm? get activeRingingAlarm => _activeRingingAlarm;
	bool get isInitialized => _isInitialized;
	bool get hasActiveAlarms => _alarms.any((a) => a.isActive);
	bool get isTrackingPaused => _positionStream?.isPaused ?? true;

	AlarmService() {
		_initialize();
	}

	/* Sequential startup ensuring storage is loaded before evaluation */
	Future<void> _initialize() async {
		_initNotifications();
		_initAudioContext();
		await _loadAlarmsFromStorage();
		_isInitialized = true;
		_listenToServiceStatus();
		await _startLocationTracking();
		await _updateTrackingMode();
		_safeNotifyListeners();
	}

	void _initAudioContext() async {
		try {
			await _audioPlayer.setAudioContext(
				const AudioContext(
					android: AudioContextAndroid(
						isSpeakerphoneOn: true,
						stayAwake: true,
						contentType: AndroidContentType.music,
						usageType: AndroidUsageType.alarm,
						audioFocus: AndroidAudioFocus.gainTransient,
					),
					iOS: AudioContextIOS(
						category: AVAudioSessionCategory.playback,
						options: [
							AVAudioSessionOptions.duckOthers,
							AVAudioSessionOptions.defaultToSpeaker,
						],
					),
				),
			);
		} catch (e) {
			debugPrint('Error initializing AudioContext: $e');
		}
	}

	void _initNotifications() async {
		try {
			const AndroidInitializationSettings initAndroid =
					AndroidInitializationSettings('@mipmap/ic_launcher');
			const DarwinInitializationSettings initIOS =
					DarwinInitializationSettings();
			const InitializationSettings initSettings = InitializationSettings(
				android: initAndroid,
				iOS: initIOS,
			);
			await _notificationsPlugin.initialize(initSettings);
		} catch (e) {
			debugPrint('Error initializing notifications: $e');
		}
	}

	void _listenToServiceStatus() {
		try {
			_serviceStatusStream =
					Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
				if (status == ServiceStatus.enabled) {
					_startLocationTracking();
				}
			});
		} catch (e) {
			debugPrint('Error listening to service status stream: $e');
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
			}
		} catch (e) {
			debugPrint('Error loading alarms from SharedPreferences: $e');
		}
	}

	Future<void> _saveAlarmsToStorage() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			final List<Map<String, dynamic>> data =
					_alarms.map((a) => a.toJson()).toList();
			await prefs.setString(_storageKey, jsonEncode(data));
		} catch (e) {
			debugPrint('Error saving alarms to SharedPreferences: $e');
		}
	}

	Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
		try {
			final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
			if (!serviceEnabled) {
				return null;
			}

			LocationPermission permission = await Geolocator.checkPermission();
			if (permission == LocationPermission.denied) {
				permission = await Geolocator.requestPermission();
				if (permission == LocationPermission.denied) return null;
			}
			if (permission == LocationPermission.deniedForever) return null;

			final pos = await Geolocator.getCurrentPosition(
				desiredAccuracy: LocationAccuracy.high,
				timeLimit: const Duration(seconds: 8),
			);
			_currentPosition = pos;
			_safeNotifyListeners();
			return pos;
		} catch (e) {
			debugPrint('Error in getCurrentLocation: $e');
			try {
				final last = await Geolocator.getLastKnownPosition();
				if (last != null) {
					_currentPosition = last;
					_safeNotifyListeners();
					return last;
				}
			} catch (_) {}
			return _currentPosition;
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

			// Fetch real GPS position immediately on startup
			try {
				final freshPos = await Geolocator.getCurrentPosition(
					desiredAccuracy: LocationAccuracy.high,
					timeLimit: const Duration(seconds: 8),
				);
				if (!_isDisposed) {
					_currentPosition = freshPos;
					_safeNotifyListeners();
				}
			} catch (_) {
				try {
					final lastPos = await Geolocator.getLastKnownPosition();
					if (lastPos != null && !_isDisposed) {
						_currentPosition = lastPos;
						_safeNotifyListeners();
					}
				} catch (_) {}
			}

			await _positionStream?.cancel();

			const LocationSettings locationSettings = LocationSettings(
				accuracy: LocationAccuracy.high,
				distanceFilter: 10,
			);

			_positionStream = Geolocator.getPositionStream(
				locationSettings: locationSettings,
			).listen(
				_onPositionUpdate,
				onError: (error) => debugPrint('Location stream error: $error'),
				cancelOnError: false,
			);

			if (!hasActiveAlarms && _positionStream != null) {
				_positionStream!.pause();
			}
		} catch (e) {
			debugPrint('Error starting location tracking: $e');
		}
	}

	/* Adaptive tracking: pause stream when idle to preserve battery */
	Future<void> _updateTrackingMode() async {
		if (!_isInitialized || _isDisposed) return;

		if (!hasActiveAlarms) {
			if (_positionStream != null && !_positionStream!.isPaused) {
				_positionStream!.pause();
				debugPrint('Battery saving mode: Location tracking paused');
			}
		} else {
			if (_positionStream == null) {
				await _startLocationTracking();
			} else if (_positionStream!.isPaused) {
				_positionStream!.resume();
				debugPrint('High accuracy tracking mode: Resumed');
			}
		}
	}

	void _onPositionUpdate(Position? position) {
		if (position == null || _isDisposed || !_isInitialized) return;
		_currentPosition = position;
		_checkAlarms(position);
		_safeNotifyListeners();
	}

	/* Atomic geofence evaluation avoiding concurrent mutations */
	void _checkAlarms(Position position) {
		if (_isEvaluating || !_isInitialized || _isDisposed) return;
		_isEvaluating = true;

		try {
			final List<Alarm> triggeredAlarms = [];
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
				final bool isInside = distance <= alarm.radiusInMeters;

				if (alarm.triggerType == AlarmTriggerType.arrive && isInside) {
					triggeredAlarms.add(alarm);
					_alarms[i] = alarm.copyWith(isActive: false);
					hasChanges = true;
				} else if (alarm.triggerType == AlarmTriggerType.leave) {
					final result = _evaluateLeaveTrigger(alarm, isInside);
					if (result.shouldTrigger) {
						triggeredAlarms.add(alarm);
						_alarms[i] = alarm.copyWith(isActive: false, lastKnownInside: false);
						hasChanges = true;
					} else if (result.hasStateChange) {
						_alarms[i] = alarm.copyWith(lastKnownInside: result.newInsideState);
						hasChanges = true;
					}
				}
			}

			if (hasChanges) {
				_saveAlarmsToStorage();
			}

			if (triggeredAlarms.isNotEmpty) {
				_handleTriggeredAlarms(triggeredAlarms);
			}
		} finally {
			_isEvaluating = false;
		}
	}

	({bool shouldTrigger, bool hasStateChange, bool? newInsideState})
			_evaluateLeaveTrigger(Alarm alarm, bool isInside) {
		if (alarm.lastKnownInside == null) {
			return (shouldTrigger: false, hasStateChange: true, newInsideState: isInside);
		}
		if (alarm.lastKnownInside == true && !isInside) {
			return (shouldTrigger: true, hasStateChange: true, newInsideState: false);
		}
		if (alarm.lastKnownInside == false && isInside) {
			return (shouldTrigger: false, hasStateChange: true, newInsideState: true);
		}
		return (
			shouldTrigger: false,
			hasStateChange: false,
			newInsideState: alarm.lastKnownInside,
		);
	}

	void _handleTriggeredAlarms(List<Alarm> triggeredAlarms) {
		if (triggeredAlarms.isEmpty) return;

		_isRinging = true;
		_activeRingingAlarm = triggeredAlarms.first;
		_safeNotifyListeners();

		for (final alarm in triggeredAlarms) {
			_showAlarmNotification(alarm);
		}

		_startAlarmFeedback();
		_updateTrackingMode();
	}

	Future<void> _showAlarmNotification(Alarm alarm) async {
		try {
			const AndroidNotificationDetails androidDetails =
					AndroidNotificationDetails(
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
				alarm.id.hashCode,
				'¡Alarma de Ubicación!',
				'Alarma disparada: ${alarm.name}',
				platformDetails,
			);
		} catch (e) {
			debugPrint('Error showing notification: $e');
		}
	}

	Future<void> _startAlarmFeedback() async {
		try {
			final bool hasVibrator = await Vibration.hasVibrator();
			if (hasVibrator) {
				Vibration.vibrate(
					pattern: [500, 1000, 500, 1000, 500, 1000],
					repeat: 0,
				);
			}
		} catch (e) {
			debugPrint('Error starting vibration: $e');
		}

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
		_updateTrackingMode();
		_safeNotifyListeners();
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
			alarmToAdd =
					alarm.copyWith(lastKnownInside: distance <= alarm.radiusInMeters);
		}

		_alarms.add(alarmToAdd);
		_saveAlarmsToStorage();
		_updateTrackingMode();
		_safeNotifyListeners();
	}

	void toggleAlarm(String id, bool isActive) {
		final int index = _alarms.indexWhere((a) => a.id == id);
		if (index == -1) return;

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
		_updateTrackingMode();
		_safeNotifyListeners();
	}

	void removeAlarm(String id) {
		_alarms.removeWhere((a) => a.id == id);
		if (_activeRingingAlarm?.id == id && !_isRinging) {
			_activeRingingAlarm = null;
		}
		_saveAlarmsToStorage();
		_updateTrackingMode();
		_safeNotifyListeners();
	}

	void _safeNotifyListeners() {
		if (!_isDisposed) {
			notifyListeners();
		}
	}

	@override
	void dispose() {
		_isDisposed = true;
		_positionStream?.cancel();
		_serviceStatusStream?.cancel();
		try {
			Vibration.cancel();
		} catch (_) {}
		try {
			_audioPlayer.stop();
			_audioPlayer.dispose();
		} catch (e) {
			debugPrint('Error disposing audio player: $e');
		}
		super.dispose();
	}
}
