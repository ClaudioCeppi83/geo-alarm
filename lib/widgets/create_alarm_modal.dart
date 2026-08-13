import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm.dart';
import '../services/alarm_service.dart';

class CreateAlarmModal extends StatefulWidget {
	final LatLng selectedLocation;
	final String? initialName;

	const CreateAlarmModal({
		super.key,
		required this.selectedLocation,
		this.initialName,
	});

	@override
	State<CreateAlarmModal> createState() => _CreateAlarmModalState();
}

class _CreateAlarmModalState extends State<CreateAlarmModal> {
	late final TextEditingController _nameController;
	double _radius = 500;
	AlarmTriggerType _triggerType = AlarmTriggerType.arrive;

	@override
	void initState() {
		super.initState();
		_nameController = TextEditingController(text: widget.initialName ?? '');
	}

	static const List<({String label, double value})> _quickRadiusOptions = [
		(label: '200m', value: 200.0),
		(label: '500m', value: 500.0),
		(label: '1km', value: 1000.0),
		(label: '2km', value: 2000.0),
	];

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
			child: SingleChildScrollView(
				physics: const ClampingScrollPhysics(),
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
							style: theme.textTheme.headlineSmall
									?.copyWith(fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 16),
						TextField(
							controller: _nameController,
							autofocus: true,
							textCapitalization: TextCapitalization.sentences,
							decoration: InputDecoration(
								labelText: 'Nombre de la alarma',
								hintText: 'Ej. Casa, Oficina, Parada',
								filled: true,
								fillColor: theme.colorScheme.surfaceContainerHighest,
								prefixIcon: const Icon(Icons.label_outline),
								border: OutlineInputBorder(
									borderRadius: BorderRadius.circular(12),
									borderSide: BorderSide.none,
								),
							),
						),
						const SizedBox(height: 16),
						Text(
							'Radio: ${_radius >= 1000 ? (_radius / 1000).toStringAsFixed(1) : _radius.toInt()} ${_radius >= 1000 ? 'km' : 'metros'}',
							style: theme.textTheme.titleSmall?.copyWith(
								fontWeight: FontWeight.bold,
							),
						),
						const SizedBox(height: 8),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							children: _quickRadiusOptions.map((option) {
								final isSelected = (_radius - option.value).abs() < 1;
								return ChoiceChip(
									label: Text(option.label),
									selected: isSelected,
									onSelected: (selected) {
										if (selected) {
											HapticFeedback.selectionClick();
											setState(() {
												_radius = option.value;
											});
										}
									},
									selectedColor: theme.colorScheme.primaryContainer,
									labelStyle: TextStyle(
										color: isSelected
												? theme.colorScheme.onPrimaryContainer
												: theme.colorScheme.onSurface,
										fontWeight: isSelected
												? FontWeight.bold
												: FontWeight.normal,
									),
								);
							}).toList(),
						),
						const SizedBox(height: 8),
						Slider(
							value: _radius,
							min: 100,
							max: 5000,
							divisions: 49,
							activeColor: theme.colorScheme.primary,
							semanticFormatterCallback: (val) => '${val.toInt()} metros',
							onChanged: (value) {
								HapticFeedback.selectionClick();
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
								HapticFeedback.selectionClick();
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
									Navigator.of(context).pop(newAlarm);
								},
								child: const Text('Crear Alarma'),
							),
						),
						const SizedBox(height: 32),
					],
				),
			),
		);
	}

	@override
	void dispose() {
		_nameController.dispose();
		super.dispose();
	}
}
