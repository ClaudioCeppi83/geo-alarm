import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm.dart';
import '../services/alarm_service.dart';

class CreateAlarmModal extends StatefulWidget {
  final LatLng selectedLocation;

  const CreateAlarmModal({super.key, required this.selectedLocation});

  @override
  State<CreateAlarmModal> createState() => _CreateAlarmModalState();
}

class _CreateAlarmModalState extends State<CreateAlarmModal> {
  final _nameController = TextEditingController();
  double _radius = 500;
  AlarmTriggerType _triggerType = AlarmTriggerType.arrive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nueva Alarma',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nombre de la alarma',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Radio: ${_radius.toInt()} metros'),
          Slider(
            value: _radius,
            min: 100,
            max: 5000,
            divisions: 49,
            activeColor: theme.colorScheme.primary,
            onChanged: (value) {
              setState(() {
                _radius = value;
              });
            },
          ),
          const SizedBox(height: 16),
          SegmentedButton<AlarmTriggerType>(
            segments: const [
              ButtonSegment(
                value: AlarmTriggerType.arrive,
                label: Text('Al Llegar'),
                icon: Icon(Icons.login),
              ),
              ButtonSegment(
                value: AlarmTriggerType.leave,
                label: Text('Al Salir'),
                icon: Icon(Icons.logout),
              ),
            ],
            selected: {_triggerType},
            onSelectionChanged: (Set<AlarmTriggerType> newSelection) {
              setState(() {
                _triggerType = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim().isEmpty 
                    ? 'Alarma sin nombre' 
                    : _nameController.text.trim();
                
                final newAlarm = Alarm(
                  id: const Uuid().v4(),
                  name: name,
                  position: widget.selectedLocation,
                  radiusInMeters: _radius,
                  triggerType: _triggerType,
                );

                context.read<AlarmService>().addAlarm(newAlarm);
                Navigator.of(context).pop();
              },
              child: const Text('Crear Alarma'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
