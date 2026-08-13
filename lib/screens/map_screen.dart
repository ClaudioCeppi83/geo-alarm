import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/alarm.dart';
import '../services/alarm_service.dart';
import '../services/location_search_service.dart';
import '../widgets/create_alarm_modal.dart';
import '../widgets/location_search_bar.dart';

class MapScreen extends StatefulWidget {
	const MapScreen({super.key});

	@override
	State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
	GoogleMapController? _mapController;
	LatLng? _selectedLocation;
	String? _selectedAddressName;
	bool _isCreating = false;

	@override
	void initState() {
		super.initState();
		WidgetsBinding.instance.addPostFrameCallback((_) async {
			final service = context.read<AlarmService>();
			final pos = await service.getCurrentLocation();
			if (pos != null && mounted) {
				_mapController?.animateCamera(
					CameraUpdate.newLatLngZoom(
						LatLng(pos.latitude, pos.longitude),
						15.5,
					),
				);
			}
		});
	}

	@override
	Widget build(BuildContext context) {
		final alarmService = context.watch<AlarmService>();
		final theme = Theme.of(context);

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
				elevation: 0,
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
						onMapCreated: (controller) async {
							_mapController = controller;
							final service = context.read<AlarmService>();
							if (service.currentPosition != null) {
								_mapController?.animateCamera(
									CameraUpdate.newLatLngZoom(
										LatLng(
											service.currentPosition!.latitude,
											service.currentPosition!.longitude,
										),
										15.5,
									),
								);
							} else {
								final pos = await service.getCurrentLocation();
								if (pos != null && mounted) {
									_mapController?.animateCamera(
										CameraUpdate.newLatLngZoom(
											LatLng(pos.latitude, pos.longitude),
											15.5,
										),
									);
								}
							}
						},
						onTap: (LatLng location) {
							HapticFeedback.lightImpact();
							if (_isCreating) {
								setState(() {
									_selectedLocation = location;
									_selectedAddressName = null;
								});
							}
						},
						markers: _buildMarkers(alarmService.alarms, theme),
						circles: _buildCircles(alarmService.alarms, theme),
					),

					// Floating Location Search Bar
					Positioned(
						top: 10,
						left: 16,
						right: 16,
						child: SafeArea(
							child: LocationSearchBar(
								onLocationSelected: (SearchResult result) {
									final target = LatLng(result.latitude, result.longitude);
									_mapController?.animateCamera(
										CameraUpdate.newLatLngZoom(target, 16),
									);
									setState(() {
										_selectedLocation = target;
										_selectedAddressName = result.name;
										_isCreating = true;
									});
									HapticFeedback.mediumImpact();
								},
							),
						),
					),

					// Ringing Alarm Banner with pulsing visual emergency feedback
					if (alarmService.isRinging)
						_RingingAlarmBanner(
							alarm: alarmService.activeRingingAlarm,
							onStop: () => alarmService.stopAlarm(),
						),

					if (_isCreating && _selectedLocation == null && !alarmService.isRinging)
						SafeArea(
							child: Align(
								alignment: Alignment.topCenter,
								child: Padding(
									padding: const EdgeInsets.only(top: 75.0, left: 16, right: 16),
									child: Card(
										elevation: 4,
										child: Padding(
											padding: const EdgeInsets.symmetric(
													horizontal: 20, vertical: 12),
											child: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Icon(Icons.touch_app,
															color: theme.colorScheme.primary),
													const SizedBox(width: 10),
													Flexible(
														child: Text(
															'Toca un punto en el mapa o busca una dirección arriba',
															style: theme.textTheme.bodyMedium?.copyWith(
																fontWeight: FontWeight.w600,
															),
														),
													),
												],
											),
										),
									),
								),
							),
						),

					// Location FAB
					Positioned(
						right: 16,
						bottom: 270,
						child: FloatingActionButton.small(
							heroTag: 'my_location_btn',
							tooltip: 'Centrar en mi ubicación',
							onPressed: () async {
								HapticFeedback.lightImpact();
								final messenger = ScaffoldMessenger.of(context);
								final pos = await alarmService.getCurrentLocation(forceRefresh: true);
								if (!mounted) return;
								if (pos != null) {
									_mapController?.animateCamera(
										CameraUpdate.newLatLngZoom(
											LatLng(pos.latitude, pos.longitude),
											16.0,
										),
									);
								} else {
									messenger.showSnackBar(
										const SnackBar(
											content: Text('Obteniendo señal GPS... Asegúrate de tener la ubicación activada.'),
											duration: Duration(seconds: 2),
											behavior: SnackBarBehavior.floating,
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

					// Bottom Panel
					Positioned(
						bottom: 0,
						left: 0,
						right: 0,
						child: _buildBottomPanel(alarmService, theme),
					),
				],
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
					radius: 500,
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
				borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withValues(alpha: 0.08),
						blurRadius: 16,
						offset: const Offset(0, -4),
					)
				],
			),
			padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.stretch,
				children: [
					Row(
						mainAxisAlignment: MainAxisAlignment.spaceBetween,
						children: [
							Text(
								'Tus Geocercas',
								style: theme.textTheme.titleMedium
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
					const SizedBox(height: 12),
					if (alarmService.alarms.isEmpty)
						Padding(
							padding: const EdgeInsets.symmetric(vertical: 20),
							child: Center(
								child: Column(
									children: [
										Icon(
											Icons.notifications_paused_outlined,
											size: 36,
											color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
										),
										const SizedBox(height: 8),
										Text(
											'No tienes alarmas configuradas',
											style: theme.textTheme.bodyMedium?.copyWith(
												color:
														theme.colorScheme.onSurface.withValues(alpha: 0.6),
											),
										),
									],
								),
							),
						)
					else
						SizedBox(
							height: 130,
							child: ListView.separated(
								itemCount: alarmService.alarms.length,
								separatorBuilder: (context, index) => const SizedBox(height: 8),
								itemBuilder: (context, index) {
									final alarm = alarmService.alarms[index];
									return Card(
										child: ListTile(
											contentPadding:
													const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
											title: Text(
												alarm.name,
												style: const TextStyle(fontWeight: FontWeight.bold),
											),
											subtitle: Text(
												alarm.triggerType == AlarmTriggerType.arrive
														? 'Al llegar (${alarm.radiusInMeters.toInt()} m)'
														: 'Al salir (${alarm.radiusInMeters.toInt()} m)',
											),
											trailing: Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Switch(
														value: alarm.isActive,
														onChanged: (val) =>
																alarmService.toggleAlarm(alarm.id, val),
														activeThumbColor: theme.colorScheme.primary,
													),
													IconButton(
														icon: const Icon(Icons.delete_outline, size: 20),
														tooltip: 'Eliminar alarma',
														onPressed: () =>
																_confirmDeleteAlarm(context, alarmService, alarm),
													),
												],
											),
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
									_selectedLocation = null;
								});
							}
						},
						child: Text(_isCreating ? 'Continuar con selección' : '+ Nueva Alarma'),
					),
				],
			),
		);
	}

	void _confirmDeleteAlarm(
			BuildContext context, AlarmService service, Alarm alarm) {
		showDialog(
			context: context,
			builder: (dialogCtx) => AlertDialog(
				title: const Text('Eliminar Alarma'),
				content: Text('¿Deseas eliminar la alarma "${alarm.name}"?'),
				actions: [
					TextButton(
						onPressed: () => Navigator.of(dialogCtx).pop(),
						child: const Text('Cancelar'),
					),
					ElevatedButton(
						style: ElevatedButton.styleFrom(
							backgroundColor: Theme.of(context).colorScheme.error,
							foregroundColor: Theme.of(context).colorScheme.onError,
						),
						onPressed: () {
							HapticFeedback.mediumImpact();
							service.removeAlarm(alarm.id);
							Navigator.of(dialogCtx).pop();
							ScaffoldMessenger.of(context).showSnackBar(
								SnackBar(
									content: Row(
										children: [
											Icon(
												Icons.delete_outline_rounded,
												color: Theme.of(context).colorScheme.onError,
											),
											const SizedBox(width: 12),
											Expanded(
												child: Text(
													'Alarma "${alarm.name}" eliminada',
													style: TextStyle(
														color: Theme.of(context).colorScheme.onError,
														fontWeight: FontWeight.w600,
													),
												),
											),
										],
									),
									backgroundColor: Theme.of(context).colorScheme.error,
									behavior: SnackBarBehavior.floating,
									shape: RoundedRectangleBorder(
										borderRadius: BorderRadius.circular(12),
									),
									duration: const Duration(seconds: 2),
								),
							);
						},
						child: const Text('Eliminar'),
					),
				],
			),
		);
	}

	void _showCreateModal() {
		showModalBottomSheet<Alarm?>(
			context: context,
			isScrollControlled: true,
			builder: (context) => CreateAlarmModal(
				selectedLocation: _selectedLocation!,
				initialName: _selectedAddressName,
			),
		).then((createdAlarm) {
			if (!mounted) return;
			setState(() {
				_isCreating = false;
				_selectedLocation = null;
				_selectedAddressName = null;
			});
			if (createdAlarm != null) {
				HapticFeedback.mediumImpact();
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Row(
							children: [
								Icon(
									Icons.check_circle_rounded,
									color: Theme.of(context).colorScheme.onPrimary,
								),
								const SizedBox(width: 12),
								Expanded(
									child: Text(
										'Alarma "${createdAlarm.name}" creada con éxito',
										style: TextStyle(
											color: Theme.of(context).colorScheme.onPrimary,
											fontWeight: FontWeight.w600,
										),
									),
								),
							],
						),
						backgroundColor: Theme.of(context).colorScheme.primary,
						behavior: SnackBarBehavior.floating,
						shape: RoundedRectangleBorder(
							borderRadius: BorderRadius.circular(12),
						),
						duration: const Duration(seconds: 2),
					),
				);
			}
		});
	}

	@override
	void dispose() {
		_mapController?.dispose();
		super.dispose();
	}
}

class _RingingAlarmBanner extends StatefulWidget {
	final Alarm? alarm;
	final VoidCallback onStop;

	const _RingingAlarmBanner({
		required this.alarm,
		required this.onStop,
	});

	@override
	State<_RingingAlarmBanner> createState() => _RingingAlarmBannerState();
}

class _RingingAlarmBannerState extends State<_RingingAlarmBanner>
		with SingleTickerProviderStateMixin {
	late final AnimationController _controller;
	late final Animation<double> _scaleAnimation;
	late final Animation<double> _pulseAnimation;

	@override
	void initState() {
		super.initState();
		_controller = AnimationController(
			vsync: this,
			duration: const Duration(milliseconds: 900),
		)..repeat(reverse: true);

		_pulseAnimation = CurvedAnimation(
			parent: _controller,
			curve: Curves.easeInOut,
		);

		_scaleAnimation = Tween<double>(begin: 1.0, end: 1.22).animate(
			CurvedAnimation(
				parent: _controller,
				curve: Curves.easeInOut,
			),
		);
	}

	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final alarmName = widget.alarm?.name ?? 'Ubicación alcanzada';

		return Positioned(
			top: 16,
			left: 16,
			right: 16,
			child: SafeArea(
				child: Semantics(
					liveRegion: true,
					label: 'Alarma activada: $alarmName',
					child: AnimatedBuilder(
						animation: _controller,
						builder: (context, child) {
							final pulseVal = _pulseAnimation.value;
							return Container(
								decoration: BoxDecoration(
									borderRadius: BorderRadius.circular(16),
									boxShadow: [
										BoxShadow(
											color: theme.colorScheme.error.withValues(
												alpha: 0.2 + 0.3 * pulseVal,
											),
											blurRadius: 10 + 8 * pulseVal,
											spreadRadius: 2 * pulseVal,
										),
									],
								),
								child: Material(
									elevation: 6,
									borderRadius: BorderRadius.circular(16),
									color: theme.colorScheme.errorContainer,
									child: Container(
										padding: const EdgeInsets.all(16),
										decoration: BoxDecoration(
											borderRadius: BorderRadius.circular(16),
											border: Border.all(
												color: theme.colorScheme.error.withValues(
													alpha: 0.6 + 0.4 * pulseVal,
												),
												width: 1.5 + 1.2 * pulseVal,
											),
										),
										child: Column(
											mainAxisSize: MainAxisSize.min,
											children: [
												Row(
													children: [
														ScaleTransition(
															scale: _scaleAnimation,
															child: Container(
																padding: const EdgeInsets.all(8),
																decoration: BoxDecoration(
																	color: theme.colorScheme.error.withValues(
																		alpha: 0.2,
																	),
																	shape: BoxShape.circle,
																),
																child: Icon(
																	Icons.notifications_active,
																	color: theme.colorScheme.error,
																	size: 26,
																),
															),
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
																			fontSize: 13,
																			color: theme.colorScheme.onErrorContainer,
																			letterSpacing: 0.8,
																		),
																	),
																	const SizedBox(height: 2),
																	Text(
																		alarmName,
																		style: TextStyle(
																			fontSize: 16,
																			fontWeight: FontWeight.bold,
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
														onPressed: widget.onStop,
														icon: const Icon(Icons.volume_off),
														label: const Text('Silenciar / Detener Alarma'),
														style: ElevatedButton.styleFrom(
															backgroundColor: theme.colorScheme.error,
															foregroundColor: theme.colorScheme.onError,
															padding: const EdgeInsets.symmetric(vertical: 12),
															elevation: 0,
															shape: RoundedRectangleBorder(
																borderRadius: BorderRadius.circular(12),
															),
														),
													),
												),
											],
										),
									),
								),
							);
						},
					),
				),
			),
		);
	}
}
