# Frontend Android (Flutter) — Configuración Android

> **Nota:** El SDK de Flutter no estaba instalado en la máquina de desarrollo al generar este proyecto. Se creó el esqueleto completo de Android (`AndroidManifest.xml`, `build.gradle.kts`, `settings.gradle.kts`, `MainActivity.kt`, recursos e ícono de notificaciones).

## Si necesitas regenerar la plantilla Android
Si al compilar por primera vez falta algún archivo binario del Gradle Wrapper (`gradlew`, `gradle-wrapper.jar`), ejecuta dentro de `frontend/`:

```bash
flutter create . --platforms=android --org com.sts
```

Después verifica que `android/app/src/main/AndroidManifest.xml` conserve:
- Permisos: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `USE_FULL_SCREEN_INTENT`
- `<queries>` con intent `ACTION_DIAL` / `tel` para `url_launcher`
- `android:usesCleartextTraffic="true"` en `<application>`
- Receivers de `flutter_local_notifications`
- `coreLibraryDesugaringEnabled = true` en `android/app/build.gradle.kts` (requerido por `flutter_local_notifications` v19).
