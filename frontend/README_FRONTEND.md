# Frontend Flutter — Catálogo de Fundación STS

## Ejecutar
```bash
cd frontend
flutter pub get
flutter run
```

## Servicios y Providers registrados en `MultiProvider` (`main.dart`)
- `ServerConfigProvider`: `baseUrl`, `setBaseUrl(raw)`
- `DemoModeProvider`: `enabled`, `postArrivalDelay`, `toggle()`, `setEnabled(bool)`
- `SessionProvider`: `role`, `coordinator`, `student`, `tutorRoute`, `school`, `coordinatorPhone`, `driverRoute`, `loginCoordinator`, `loginTutor`, `loginDriver`, `updateStudent`, `updateDriverRoute`, `logout`
- `ApiService`: todos los endpoints REST de `building.md` §3 (lanza `ApiException(message)`)
- `SocketService`: `joinRoute(routeId, role)`, `joinStudent(studentId)`, `emitDriverLocation(routeId, lat, lng)`, `disconnect()`, y streams `onConnectionChanged`, `onBusLocation`, `onRouteStatusChanged`, `onRouteStarted`, `onPolylineUpdated`, `onStudentPickupUpdated`, `onProximityAlert`, `onDriverSos`, `onTripCompleted`, `onStudentServiceUpdated`
- `OsrmService`: `fetchRoute(List<LatLng> waypoints)` → `RouteGeometry(points, isFallback)`
- `LocationService`: `ensurePermission()`, `currentLatLng()`, `positionStream()`
- `NotificationService.instance`: `requestPermission()`, `showNow(title, body, payload:, fullScreen:)`, `scheduleOneHourBefore(startTime)`
- `LauncherService.call(phone)`
- `GeoUtils`: `haversineMeters`, `densify`, `indexOfClosest`, `boundsOf`, `formatDistance`
- `TimeUtils`: `parseHHmm`, `toHHmm`, `to12h`, `weekdayKey`

## Widgets compartidos (`lib/widgets/`)
- `StsAppBar(title:, subtitle:, showBack:, showRoleSwitch:, showDemoToggle:, actions:, onBack:)`
- `PrimaryButton(label:, onPressed:, icon:, trailingIcon:, loading:, variant:, fullWidth:)`
- `StatusChip.route(status)`, `StatusChip.pickup(status)`, `StatusChip.service(status)`
- `showConfirmDialog(context, title:, message:, confirmLabel:, cancelLabel:, isDanger:)`
- `shareCode(context, title:, shortCode:, uuid:, description:)`
- `StsMap(controller:, initialCenter:, initialZoom:, polyline:, stops:, schoolPoint:, schoolLabel:, busPoint:, pickupPin:, onTap:)`
- `LoadingView`, `ErrorView`, `EmptyView`
- `confirmAndLogout(context)` / `RoleSwitchAction`
