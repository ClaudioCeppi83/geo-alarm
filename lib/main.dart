import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/map_screen.dart';
import 'services/alarm_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmService()),
      ],
      child: const GeoAlarmApp(),
    ),
  );
}

class GeoAlarmApp extends StatelessWidget {
  const GeoAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Alarm',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Cambia automáticamente según el sistema
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
