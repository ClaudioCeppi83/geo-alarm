# Geo Alarm 📍⏰

Aplicación móvil inteligente construida en Flutter que dispara alarmas sonoras, hápticas y notificaciones push cuando entras o sales de geocercas GPS configuradas sobre Google Maps.

## 🚀 Características
- **Geofencing Preciso y Adaptativo**: Detección de entrada/salida de radios geodésicos personalizables (200m, 500m, 1km, 2km). Ahorro de batería inteligente pausando el sensor cuando no hay geocercas activas.
- **Histéresis Anti-Falsos Positivos**: Registro de estado previo (`lastKnownInside`) para evitar alarmas disparadas accidentalmente por imprecisión inicial del GPS.
- **Buscador de Direcciones Multicapa**: Autocompletado con debounce (400ms) y triple fallback resiliente:
  1. Geocodificación Nativa de Plataforma (`geocoding`).
  2. Google Maps Geocoding REST API (si se provee clave).
  3. OpenStreetMap Nominatim API.
- **Alarma Sonora y Háptica con Servicio en Primer Plano**: Notificaciones de alta prioridad (`full-screen intent`), vibración continua y audio persistente con botón de silenciado.
- **Persistencia Local Offline-First**: Serialización JSON automática con `SharedPreferences`.
- **Diseño Material 3 & Accesibilidad**: Tokens visuales M3, feedback háptico y diálogos accesibles.

## 🔐 Configuración de Seguridad (Google Maps API Key)

Para mantener la seguridad del repositorio y evitar fugas de credenciales, las API Keys de Google Cloud nunca se incluyen en el código fuente versionado.

### 1. Desarrollo Local Android
Copia `android/local.properties.example` a `android/local.properties` (archivo ignorado por Git):
```properties
MAPS_API_KEY=TU_GOOGLE_MAPS_API_KEY
```

### 2. Compilación / Ejecución con Dart Define
```bash
flutter run --dart-define=MAPS_API_KEY=TU_GOOGLE_MAPS_API_KEY
```

### 3. Variables de Entorno (CI/CD)
En entornos de integración continua (GitHub Actions, Codemagic), define la variable de entorno `MAPS_API_KEY`.

> **Nota de Seguridad**: Si tu clave fue previamente expuesta públicamente, revócala o rótala en [Google Cloud Console](https://console.cloud.google.com/google/maps-apis/credentials) y añade restricciones de API (*Maps SDK for Android*, *Geocoding API*) y restricciones de aplicación por huella digital SHA-1 y nombre de paquete (`com.erceppi.geoalarm`).

## 🧪 Pruebas Automatizadas
Ejecutar la suite completa de pruebas unitarias y de estabilidad:
```bash
flutter test
```
