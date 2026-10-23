# Bájate 🚌⏰

**No te pases de tu parada.**

Bájate es una alarma por ubicación para el bus: eliges dónde te vas a bajar y
la app suena cuando estás llegando, aunque vayas dormido o con el celular
bloqueado.

## Instalar en Android

Descarga el APK más reciente desde [Releases](../../releases/latest)
(`bajate.apk`) en tu celular y ábrelo. Si Android lo pide, permite
instalar apps de origen desconocido.

## Cómo funciona

1. Busca tu parada (te sugiere direcciones mientras escribes) o toca el mapa.
2. Elige cuándo avisarte: *Justo antes* (200 m), *Con calma* (500 m),
   *Con tiempo* (1 km) o *Voy dormido* (2 km).
3. Pulsa **Activar alarma** y guarda el celular. Verás cuánto falta, el
   progreso del viaje y un tiempo estimado.
4. Al llegar aparece una pantalla de alarma a pantalla completa con sonido y
   vibración.

Guarda tus paradas frecuentes con ⭐ para elegirlas con un toque; las
últimas que usaste aparecen como recientes.

## Tecnología

| Necesidad | Librería |
| --- | --- |
| Mapa | `flutter_map` con capas de CARTO (claro/oscuro) sobre OpenStreetMap |
| Animaciones del mapa | `flutter_map_animations` |
| Buscar direcciones | Photon (OpenStreetMap), sin API key |
| GPS en segundo plano | `geolocator` (servicio en primer plano en Android) |
| Alarma | `flutter_ringtone_player` + `flutter_local_notifications` |
| Paradas guardadas | `shared_preferences` |

> Las capas de CARTO y Photon son gratuitas para uso personal/no comercial.
> Antes de publicar la app en tiendas, cambia el proveedor de mapas en
> `lib/config/map_style.dart` por uno con API key (MapTiler, Stadia Maps o
> Mapbox).

## Estructura

- `lib/config/brand.dart` — nombre, lema y color de la marca
- `lib/config/map_style.dart` — proveedor y estilo del mapa
- `lib/screens/map_screen.dart` — pantalla principal (búsqueda, destino, viaje)
- `lib/screens/alarm_screen.dart` — pantalla de alarma
- `lib/widgets/` — marcadores del mapa y bienvenida
- `lib/logic/arrival_checker.dart` — distancia, llegada y tiempo estimado
- `lib/services/` — GPS, alarma, búsqueda y paradas guardadas

## Desarrollo

```bash
flutter pub get
flutter run       # con un teléfono o emulador conectado
flutter analyze   # análisis estático
flutter test      # pruebas
dart run flutter_launcher_icons   # regenerar el ícono desde assets/icon/
```

> Para probar en emulador, simula la ruta desde *Extended controls →
> Location* (Android) o *Features → Location* (simulador iOS).
