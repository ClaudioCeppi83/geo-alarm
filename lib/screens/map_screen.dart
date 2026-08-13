import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/alarm.dart';
import '../services/alarm_service.dart';
import '../widgets/create_alarm_modal.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    final alarmService = context.watch<AlarmService>();
    final theme = Theme.of(context);

    // Initial position placeholder (can be updated to user location)
    LatLng initialPosition = alarmService.currentPosition != null
        ? LatLng(
            alarmService.currentPosition!.latitude,
            alarmService.currentPosition!.longitude,
          )
        : const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Geo Alarm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (LatLng location) {
              if (_isCreating) {
                setState(() {
                  _selectedLocation = location;
                });
              }
            },
            markers: _buildMarkers(alarmService.alarms, theme),
            circles: _buildCircles(alarmService.alarms, theme),
          ),

          // Ringing Alarm Banner
          if (alarmService.isRinging)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: theme.colorScheme.errorContainer,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.error,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.alarm_on,
                            color: theme.colorScheme.onErrorContainer,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '¡ALARMA ACTIVADA!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.colorScheme.onErrorContainer,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  alarmService.activeRingingAlarm?.name ??
                                      'Ubicación alcanzada',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => alarmService.stopAlarm(),
                          icon: const Icon(Icons.volume_off),
                          label: const Text('Silenciar / Detener Alarma'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isCreating && _selectedLocation == null && !alarmService.isRinging)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Toca un punto en el mapa para establecer la alarma',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ),

          // Bottom Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomPanel(alarmService, theme),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120), // Above the bottom panel
        child: FloatingActionButton(
          onPressed: () {
            if (alarmService.currentPosition != null) {
              _mapController?.animateCamera(
                CameraUpdate.newLatLng(
                  LatLng(
                    alarmService.currentPosition!.latitude,
                    alarmService.currentPosition!.longitude,
                  ),
                ),
              );
            }
          },
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.my_location,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers(List<Alarm> alarms, ThemeData theme) {
    Set<Marker> markers = {};
    for (var alarm in alarms) {
      markers.add(
        Marker(
          markerId: MarkerId(alarm.id),
          position: alarm.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            alarm.isActive
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(title: alarm.name),
        ),
      );
    }

    if (_isCreating && _selectedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Circle> _buildCircles(List<Alarm> alarms, ThemeData theme) {
    Set<Circle> circles = {};
    for (var alarm in alarms) {
      circles.add(
        Circle(
          circleId: CircleId(alarm.id),
          center: alarm.position,
          radius: alarm.radiusInMeters,
          fillColor: alarm.isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
          strokeColor:
              alarm.isActive ? theme.colorScheme.primary : Colors.grey,
          strokeWidth: 2,
        ),
      );
    }

    if (_isCreating && _selectedLocation != null) {
      circles.add(
        Circle(
          circleId: const CircleId('selected_radius'),
          center: _selectedLocation!,
          radius: 500, // Default radius preview
          fillColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          strokeColor: theme.colorScheme.primary,
          strokeWidth: 2,
        ),
      );
    }

    return circles;
  }

  Widget _buildBottomPanel(AlarmService alarmService, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alarmas',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_isCreating)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isCreating = false;
                      _selectedLocation = null;
                    });
                  },
                  child: const Text('Cancelar'),
                )
            ],
          ),
          const SizedBox(height: 16),
          if (alarmService.alarms.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No hay alarmas creadas.')),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: alarmService.alarms.length,
                itemBuilder: (context, index) {
                  final alarm = alarmService.alarms[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        alarm.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        alarm.triggerType == AlarmTriggerType.arrive
                            ? 'Al llegar (${alarm.radiusInMeters.toInt()}m)'
                            : 'Al salir (${alarm.radiusInMeters.toInt()}m)',
                      ),
                      trailing: Switch(
                        value: alarm.isActive,
                        onChanged: (val) =>
                            alarmService.toggleAlarm(alarm.id, val),
                        activeThumbColor: theme.colorScheme.primary,
                      ),
                      onLongPress: () => alarmService.removeAlarm(alarm.id),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_isCreating && _selectedLocation != null) {
                _showCreateModal();
              } else {
                setState(() {
                  _isCreating = true;
                  _selectedLocation = null; // Wait for tap
                });
              }
            },
            child: Text(_isCreating ? 'Continuar' : '+ Nueva Alarma'),
          ),
        ],
      ),
    );
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          CreateAlarmModal(selectedLocation: _selectedLocation!),
    ).then((_) {
      setState(() {
        _isCreating = false;
        _selectedLocation = null;
      });
    });
  }
}
