# building.md — Bitácora y contrato técnico de STS

> Documento vivo: **todos los agentes deben leerlo antes de trabajar y agregar su update al final** (sección "Bitácora"). Es la fuente de verdad del contrato Backend ↔ Frontend.
> Especificación original: `prompt_antigravity_sts.md`. Bocetos: carpeta `assets/` (correlación en la sección 1).

## 0. Entorno detectado (2026-11-22)

- Windows + PowerShell. Node v22.14.0 disponible. **`npm` en PowerShell falla por ExecutionPolicy → usar `npm.cmd` / `npx.cmd`** (instalar paquetes requiere `BypassSandbox: true`).
- **Flutter SDK NO instalado** y **Docker NO instalado** (a 2026-11-22). Por tanto: el frontend se escribe sin poder compilar/analizar localmente; se debe ser muy cuidadoso con la sintaxis Dart, imports y versiones de paquetes. El backend se prueba con Node; MongoDB se probará con `mongodb-memory-server` (si hay red) o Atlas.
- La raíz del proyecto es `student_tracking_system/` (equivale a `sts-app/` del prompt). Carpetas: `backend/`, `frontend/`, `assets/`.

## 1. Correlación boceto ↔ pantallas (resumen de lo observado en `assets/`)

| Boceto | Contenido observado | Pantallas del prompt |
|---|---|---|
| 12.10.44 PM | "Hola! Por favor escoge tu rol": Tutor / Coordinador / Chofer. Coordinador → "Iniciar sesión como coordinador" (usuario, password, Ingresar) → Coordinador 1 | `RoleSelectionScreen`, Coordinador 0 |
| 12.10.41 PM | Vista coordinador: **1** Hola! / Mis Rutas (+) con tarjetas "Ruta 1 # ", íconos bus + lápiz; **2** Nueva ruta (lápiz editar nombre, basura eliminar con confirmación siempre, íconos); sección Alumnos (+) con lista (nombre, lápiz, X); **3** agregar/editar alumno (info alumno: nombre, apellido, grado; info tutor: nombre, apellido, número 1, número 2; Guardar); **4** ruta en curso: "Ruta X: [en progreso]" + mapa + lista de alumnos con ✓ verde (recogido) y ● azul (pendiente) | Coordinador 1–4 |
| 12.10.42 PM | Coordinador **5** Confirmar llegada ("El transporte llegó al destino. Confirmar que todos los alumnos se encuentran", Confirmar, Reportar problema); **6** Reportar problema (¿Qué pasó? cuadro largo, ¿involucra a algún alumno? selector, "Después del reporte comunícate con el tutor" + datos tutor, Reportar). Vista chofer **1** (Hola! Todo listo para la ruta, mapa con paradas programadas, ícono de alerta abajo-derecha), **2** (mapa + sección "Confirmar recolección de alumno" + Confirmar, aparece cuando detecta que pasó sobre la ruta) | Coordinador 5–6, Chofer 1–2 |
| 12.10.42 PM (1) | Chofer **3** Reportar problema (texto + Reportar → llamada al coordinador + estatus "En pausa"), **4** Viaje finalizado ("Gracias por tu servicio. El próximo viaje aparecerá aquí cuando esté disponible"), **5** Inicio de sesión (Hola!! Ingresa el código de ruta para iniciar; Código; Ingresar) | Chofer 3, 4, 5 |
| 12.10.41 PM (1) | Tutor **1** (Hola!!! código escuela, "¿No tienes código?", Ingresar), **2** (Cada escuela afiliada..., Regresar), **3** (Bienvenido Nombre_usuario, Antes de continuar asegurémonos que tus datos estén correctos, Empezar) | Tutor 1–3 |
| 12.10.40 PM | Tutor **4** Validar datos (Tus Datos: nombre, apellido, número 1, número 2; Datos del estudiante: nombre, apellido, grado; Continuar), **5** Establecer punto de abordaje (mapa, se fija el pin, Finalizar), **6** pantalla genérica de carga ("Guardando tu información"), **7** Próximas recolecciones (Lunes–Viernes con ⊗ cada uno, nota "El mismo día podrás cancelar el servicio 1 hora antes", botón flotante "!" que lleva a editar datos Tutor 4 y 5) | Tutor 4–7 |
| 12.10.40 PM (1) | Día de recolección: notificación (pantalla bloqueada, alta prioridad, sonido) "La recolección empezará pronto, confirma el servicio"; "Confirma tu servicio" con ✗ "no lo necesito" / ✓ "Confirmar"; diálogo "¿Estás seguro de confirmar/rechazar el servicio?" NO / SÍ; rechazo → lista Próximas recolecciones; aceptación → mapa con barra superior "Preparando transporte" que va cambiando de estatus; botón "!" | Flujo día de recolección |

Los bocetos son wireframes de baja fidelidad: el prompt define identidad visual (azul `#2563EB`, Material 3). Los textos de los bocetos y del prompt coinciden; ante discrepancia gana el prompt.

## 2. Decisiones de diseño tomadas (no están en el prompt; respetar)

1. **Parada = alumno confirmado hoy con `pickupLocation.isSet == true`.** Al iniciar ruta el backend asigna `stopOrder` / `stopLabel` (`Punto A`, `Punto B`, …) ordenando por **distancia a la escuela descendente** (la más lejana primero), así el bus avanza hacia la escuela.
2. **Elegibilidad por día:** `todayServiceStatus == 'confirmed'` y (si hoy es lunes–viernes) `weeklySchedule[díaHoy] != false`. Sábado/domingo no se valida `weeklySchedule` (para poder demostrar en cualquier día).
3. **Polilínea OSRM:** la calcula la app del **coordinador** tras `start` (waypoints: stops en orden + escuela) y la guarda con `PUT /api/routes/:id/polyline`; el backend la persiste en `Route.polyline` y emite `route_polyline_updated`. Chofer y tutor la leen de la ruta (con fallback a línea recta entre paradas si aún es vacía/ausente). Formato: `[[lat,lng],[lat,lng],...]`.
4. **Autenticación:** simulada, sin JWT. Cada rol manda ids/códigos en la petición. Passwords en texto plano (prototipo, según prompt).
5. **Reset de ciclo:** `start` pone `pickupStatus='pending'` en todos los alumnos de la ruta. `confirm-arrival` marca `dropped_at_school` a los recogidos, pone `todayServiceStatus='pending'` a todos y deja la ruta `completed` (se puede volver a iniciar desde `idle|completed|arrived_school`).
6. **Detección en backend** (en `driver_location_update`): por cada alumno parada con `pickupStatus in (pending, approaching)`: dist < 300 m → `approaching`; < 50 m → `arrived_stop`; emite `proximity_alert` al `student:<id>`. Si ruta `in_progress`, todos los stops `picked_up` y dist a escuela < 60 m → ruta `arrived_school` (también disponible manual vía endpoint, que puede invocar el chofer en modo simulación).
7. **Salas Socket.IO:** `route:<routeId>` (coordinador, chofer y tutores de la ruta: ubicación y estatus; **sin datos personales**), `route:<routeId>:staff` (solo coordinador+chofer), `student:<studentId>` (tutor específico).
8. Cancelación: los tutores solo ven/gestionan sus propios datos. El chofer solo recibe `studentId` opaco (Mongo `_id` en string) + etiquetas.

## 3. Contrato REST (base `http://<host>:3000`, JSON, CORS abierto)

Errores: `{ "error": "mensaje legible en español" }` con status 400/404/409/500. Fechas ISO. IDs expuestos como `id` (string de `_id`), además de `uuid` y `shortCode` donde aplique. Todo response de éxito es JSON.

### Tipos
```jsonc
// Route (vista coordinador)
{ "id","uuid","shortCode","name","startTime":"07:30",
  "schoolLocation":{"lat","lng","address"},
  "status":"idle|in_progress|paused|breakdown|arrived_school|completed",
  "currentLocation":{"lat","lng","updatedAt"} | null,
  "polyline":[[lat,lng],...],            // [] si no hay
  "coordinatorId",
  "studentCount":3, "confirmedCount":2 } // solo en GET /api/routes y GET /api/routes/:id

// Student (completo: coordinador y tutor)
{ "id","uuid","shortCode","routeId","firstName","lastName","grade",
  "tutor":{"firstName","lastName","phone1","phone2"},
  "pickupLocation":{"lat","lng","isSet"},
  "weeklySchedule":{"monday","tuesday","wednesday","thursday","friday"},
  "todayServiceStatus":"pending|confirmed|rejected",
  "pickupStatus":"pending|approaching|arrived_stop|picked_up|dropped_at_school",
  "stopLabel": "Punto A" | null, "stopOrder": 1 | null }

// DriverStop (sanitizado, SIN nombres/grados/tutor)
{ "studentId":"<_id opaco>", "stopLabel":"Punto A", "stopOrder":1, "lat","lng", "status":"<pickupStatus>" }

// DriverRoute
{ "id","shortCode","name","startTime","status","schoolLocation":{"lat","lng","address"},
  "polyline":[[lat,lng],...], "stops":[DriverStop] }  // stops vacío si ruta no iniciada
```

### Auth / acceso
- `POST /api/coordinator/login` `{username,password}` → `{ coordinator:{id,username,name,phone} }` (401 si inválido).
- `POST /api/tutor/access` `{code}` (shortCode case-insens. o uuid de **Student**) → `{ student:Student, route:Route, coordinatorPhone, school:{name,address,location} }`.
- `POST /api/driver/access` `{code}` (shortCode case-insens. o uuid de **Route**) → `{ route:DriverRoute, coordinatorPhone }`.

### Coordinador
- `GET /api/routes` → `Route[]` (con studentCount/confirmedCount). Opcional `?coordinatorId=`.
- `POST /api/routes` `{name?,startTime?,schoolLocation?,coordinatorId?}` → `Route` (defaults: name `"Nueva ruta"`, startTime `"07:30"`, schoolLocation = SchoolConfig por defecto; genera `RUT-XXX` único).
- `GET /api/routes/:id` → `{ route:Route, students:Student[] }`. (`:id` acepta `_id`.)
- `PUT /api/routes/:id` `{name?,startTime?,schoolLocation?}` → `Route`.
- `DELETE /api/routes/:id` → `{ok:true}` (borra también sus alumnos e incidentes).
- `POST /api/routes/:id/students` `{firstName,lastName,grade,tutor:{firstName,lastName,phone1,phone2}}` → `Student` (genera `ALU-XXXX` único y uuid; `pickupLocation.isSet=false`).
- `PUT /api/students/:id` mismos campos (parcial) → `Student`. `DELETE /api/students/:id` → `{ok:true}`.
- `POST /api/routes/:id/start` (sin body) → `{ route:Route, stops:[ {studentId,stopLabel,stopOrder,lat,lng,status,firstName,lastName} ] }` (solo coordinador recibe nombres). 409 si ya está en curso; 400 si no hay alumnos elegibles ("No hay alumnos confirmados para hoy"). Emite `route_started` y `route_status_changed`.
- `PUT /api/routes/:id/polyline` `{polyline:[[lat,lng],...]}` → `{ok:true}`; emite `route_polyline_updated`.
- `PATCH /api/routes/:id/status` `{status:'in_progress'|'paused'|'breakdown'}` → `Route`. Emite `route_status_changed`.
- `POST /api/routes/:id/arrived-school` → `Route` (marca `arrived_school`, emite `route_status_changed`).
- `POST /api/routes/:id/confirm-arrival` → `Route` (completed; ver decisión 5). Emite `student_pickup_updated` por alumno, `route_status_changed` (`completed`), `trip_completed`.
- `POST /api/routes/:id/incidents` `{description, involvedStudentId?, reportedByRole?}` → `{ incident }`.
- `GET /api/routes/:id/live` → `{ route:Route, stops:[ {studentId,stopLabel,stopOrder,lat,lng,status,firstName,lastName} ], sosActive:boolean }` (estado actual para pintar `CoordinatorLiveRouteScreen`).

### Tutor
- `GET /api/tutor/students/:id` → `{ student:Student, route:Route }` (refrescar estado).
- `PUT /api/tutor/students/:id/profile` `{tutor?:{...}, firstName?, lastName?, grade?, pickupLocation?:{lat,lng}}` → `Student` (si llega pickupLocation → `isSet=true`).
- `PATCH /api/tutor/students/:id/schedule` `{day:'monday'|...|'friday', enabled:boolean}` → `Student`.
- `POST /api/tutor/students/:id/today-confirmation` `{decision:'confirmed'|'rejected'}` → `Student`.
- `GET /api/tutor/students/:id/live` → `{ route:Route, student:Student, stops:[{lat,lng,stopOrder}] }`.

### Chofer (100 % sanitizado)
- `GET /api/driver/routes/:routeId/stops` → `DriverRoute` (con `stops`).
- `POST /api/driver/routes/:routeId/confirm-pickup` `{studentId}` → `{ ok:true, stops:[DriverStop] }`.
- `POST /api/driver/routes/:routeId/sos` `{}` → `{ ok:true, status:'paused', coordinatorPhone }`.
- `POST /api/driver/routes/:routeId/arrived-school` → `{ ok:true }` (equivale al de coordinador; para botón simulación).

### Utilidad
- `GET /api/health` → `{ok:true}`. `GET /api/config/school` → `{name,address,location:{lat,lng}}`.

## 4. Contrato Socket.IO (servidor en el mismo puerto, `transports: ['websocket','polling']`)

Cliente → servidor:
- `join_route` `{routeId, role:'coordinator'|'driver'|'tutor'}` → une a `route:<id>`; si role≠tutor también a `route:<id>:staff`.
- `join_student` `{studentId}` → une a `student:<id>`.
- `driver_location_update` `{routeId, lat, lng}` → servidor persiste `currentLocation`, evalúa proximidad (decisión 6) y retransmite.

Servidor → cliente (todos con `routeId`):
- `bus_location_updated` → sala `route:<id>`: `{routeId, lat, lng, updatedAt}`.
- `route_status_changed` → `route:<id>` y todos los `student:`: `{routeId, status, reason?:'sos'|'manual'|'auto'}`.
- `route_started` → `route:<id>`: `{routeId}`  (el chofer en espera pasa a "Todo listo"; debe refrescar con `GET /api/driver/routes/:id/stops`).
- `route_polyline_updated` → `route:<id>`: `{routeId, polyline}`.
- `student_pickup_updated` → `route:<id>:staff` y `student:<studentId>`: `{routeId, studentId, pickupStatus, stopLabel?}` (sin nombres).
- `proximity_alert` → `student:<studentId>`: `{routeId, studentId, type:'approaching'|'arrived_stop', distance}`.
- `driver_sos_triggered` → `route:<id>:staff`: `{routeId, at}` (la ruta además pasa a `paused`).
- `trip_completed` → `route:<id>` y `student:*`: `{routeId}` (chofer → "Viaje finalizado"; tutor → "Llegó a la escuela").
- `student_service_updated` → `route:<id>:staff`: `{routeId, studentId, todayServiceStatus}` (para refrescar listas del coordinador).

## 5. Estructura del frontend (Flutter, `provider`)

```
frontend/lib/
  main.dart
  config/        app_config.dart (url servidor persistida, constantes de distancia/tiempos)
  theme/         app_theme.dart (Material 3 claro, paleta del prompt), app_colors.dart
  models/        route_model.dart, student_model.dart, driver_stop.dart, enums...
  services/      api_service.dart, socket_service.dart, osrm_service.dart, notification_service.dart,
                 location_service.dart, session_service.dart, geo_utils.dart (haversine)
  providers/     session_provider.dart, server_config_provider.dart, + providers por rol
  widgets/       app_scaffold/back button, primary_button, status_chip, sts_map.dart (flutter_map reutilizable), confirm_dialog, role switch action...
  screens/onboarding|coordinator|tutor|driver
```
El agente de **Fundación** crea todo lo compartido (config, theme, models, services, providers base, widgets, `main.dart` con rutas nombradas/Navigator, `RoleSelectionScreen`, server-settings, android/). Luego **tres agentes** crean las pantallas de coordinator / tutor / driver sin tocar archivos compartidos (si necesitan algo nuevo en un archivo compartido, lo anotan en la Bitácora o hacen un cambio mínimo aditivo).

---

## 6. Bitácora de avances

- **2026-11-22 13:2x — Coordinador (agente principal):** Leído el prompt y analizados los 7 bocetos de `assets/`. Redactado este contrato. Creados `docker-compose.yml` y `.env.example` en la raíz. Lanzando agentes: **Backend** y **Fundación Flutter** en paralelo; luego agentes de pantallas por rol.

- **2026-11-22 13:2x — Backend (agente Backend):** Backend completo en `backend/` según el contrato (todos los endpoints REST y eventos Socket.IO de las secciones 3 y 4). **Smoke test: 22/22 pasos OK** (Mongo en memoria + servidor real + 4 sockets).
  - **Cómo correr:** `cd backend; copy .env.example .env; npm.cmd install; npm.cmd start` (requiere MongoDB en `MONGO_URI`; `AUTO_SEED=true` carga datos si la BD está vacía). `npm.cmd run seed` (idempotente: solo crea lo que falta). `npm.cmd run test:smoke` (no requiere Mongo instalado; usa `mongodb-memory-server`). Escucha en `0.0.0.0:PORT` (def. 3000). Si Mongo no está disponible, el servidor termina con mensaje claro.
  - **Seed:** coordinador `admin`/`1234` (tel `+526141234567`), escuela (28.6353,-106.0889), `RUT-101` "Ruta Norte" con `ALU-1001` y `ALU-1002` **confirmed** y `ALU-1003` pending (los 3 con pin fijado), y `RUT-102` "Ruta Sur" sin alumnos.
  - **Estructura:** `src/{index,server}.js`, `config/db.js`, `models/index.js` (los 5 modelos en un archivo), `routes/index.js`, `controllers/{coordinator,access}Controller.js`, `services/{routeService,proximityService}.js`, `sockets/{index,emitters}.js`, `seed/seedData.js`, `utils/`, `test/smoke.js`.
  - **Cambios mínimos / aclaraciones al contrato (el resto se cumple tal cual):**
    1. **Extra:** `GET /api/routes/:id/incidents` → `{incidents:[{id,routeId,reportedByRole,description,involvedStudentId,createdAt}]}`. `POST .../incidents` responde 201 con `{incident:{...mismo shape}}`. El SOS del chofer también crea un incidente (`reportedByRole:'driver'`).
    2. `student_pickup_updated` se emite **también** en las transiciones automáticas `approaching` y `arrived_stop` (además de `picked_up` / `dropped_at_school`), a `route:<id>:staff` y `student:<id>`; `proximity_alert` solo al tutor de ese alumno. Si el bus pasa de `pending` directo a <50 m se emite solo `arrived_stop`.
    3. Los eventos `route_status_changed` y `trip_completed` se emiten a `route:<id>` + `student:<id>` de todos los alumnos de la ruta; un socket en ambas salas lo recibe **una sola vez**. `route_status_changed` lleva `reason` (`manual` al iniciar/PATCH/arrived manual/confirm-arrival, `sos`, `auto` en llegada detectada).
    4. Códigos HTTP: `POST start` 409 si ruta `in_progress|paused|breakdown`; 400 "No hay alumnos confirmados para hoy" y 400 "Los alumnos confirmados aún no han fijado su punto de abordaje". `PATCH status`, `sos`, `arrived-school` → 409 si la ruta no está en curso (`arrived-school` es idempotente si ya está `arrived_school`). `confirm-arrival` → 409 si `idle|completed`. `confirm-pickup` → 400 studentId inválido, 404 si no es parada de esa ruta, idempotente si ya `picked_up`.
    5. `GET /api/driver/routes/:id/stops` y `POST /api/driver/access` devuelven `stops: []` si la ruta está `idle` o `completed` (se muestran también en `arrived_school`). Igual para `stops` de `GET /api/routes/:id/live` y `/tutor/students/:id/live`.
    6. `PUT /api/students/:id` y `PUT /api/tutor/.../profile` comparten lógica (parcial; `tutor` se fusiona campo a campo; `pickupLocation` → `isSet:true`). Validación de lat/lng con 400.
    7. `confirm-arrival` deja `stopLabel/stopOrder` de los alumnos hasta el siguiente `start` (que los reinicia); la ruta `completed` devuelve stops vacíos al chofer.
    8. Elegibilidad por día usa la hora local del servidor. Auth de sockets simulada: el `role` lo declara el cliente (cualquier valor desconocido = tutor, sin sala staff). Los ids deben ser ObjectId de 24 hex; ids inválidos → 404 (rutas/alumnos) o 400.
  - **Pendientes / no verificado:** el paso de smoke "horario semanal deshabilitado excluye al alumno" solo se ejecuta si el test corre lun–vie (se corrió en domingo). No hay pruebas contra MongoDB real/Atlas (solo memory-server), ni scripts de lint. `npm audit` reporta 1 vulnerabilidad moderada en dependencias (sin tocar).


- **2026-11-22 13:34 — Frontend completo y cierre (Coordinador + 3 agentes de pantallas):**
  - **Fundación Flutter completada:** corregido import de `LatLngBounds` en `lib/services/geo_utils.dart`; creados todos los widgets compartidos en `lib/widgets/` (`StsAppBar`, `PrimaryButton`, `StatusChip`, `StsMap`, `ConfirmDialog`, `RoleSwitchAction`, `share_helper`, `state_views`), `lib/config/routes.dart`, `lib/main.dart` (MultiProvider + restauración de sesión + manejo de tap en notificaciones), pantallas de onboarding (`RoleSelectionScreen` y `ServerSettingsScreen`), `frontend/README_FRONTEND.md` y `frontend/README_ANDROID.md`.
  - **Pantallas del Coordinador (`lib/screens/coordinator/`, 8 archivos):** `CoordinatorLoginScreen` (0), `CoordinatorHomeScreen` (1), `RouteDetailEditScreen` (2), `SchoolLocationPickerScreen`, `StudentFormScreen` (3), `CoordinatorLiveRouteScreen` (4, con OSRM + sockets + SOS + palomitas verdes/círculos azules), `ConfirmArrivalScreen` (5) y `ReportProblemScreen` (6, con dropdown de alumno y llamada `tel:` al tutor).
  - **Pantallas del Tutor (`lib/screens/tutor/`, 9 archivos):** `TutorCodeScreen` (1), `TutorNoCodeInfoScreen` (2), `TutorWelcomeScreen` (3), `TutorValidateDataScreen` (4), `TutorPickupPinScreen` (5), `TutorSavingScreen` (6), `TutorHomeScreen` (7, Lunes–Viernes + botón Demo 1h antes + FAB `!`), `TutorConfirmServiceScreen` (diálogo SÍ/NO obligatorio) y `TutorLiveTrackingScreen` (barra dinámica + notificaciones locales + cuenta regresiva post-llegada 5 min / 10 s Demo + FAB `!`).
  - **Pantallas del Chofer (`lib/screens/driver/`, 4 archivos, 100% sanitizado sin nombres/grados/tutores):** `DriverCodeScreen` (5), `DriverRouteScreen` (1 + overlay 2 de confirmación automática `< 50m` + controles colapsables de GPS Real / Simulación + botón rojo SOS), `DriverSosScreen` (3, pausa viaje y abre `tel:`) y `DriverTripFinishedScreen` (4).
  - **Documentación raíz:** `README.md` actualizado con guía de instalación, seed, credenciales demo y flujo end-to-end.
  - **Verificación:**
    - Backend: `npm.cmd run test:smoke` → **22/22 pasos OK** (REST + Socket.IO + sanitización chofer + proximidad + SOS + seed).
    - Frontend: script estático sobre los **57 archivos `.dart`** → **0 errores** (todos los imports relativos y de paquetes resuelven, todas las clases de `routes.dart` existen y cero referencias a datos personales en `screens/driver/`).
  - **Pendiente en máquina con SDK instalado:** ejecutar `flutter pub get`, `flutter analyze` y `flutter run` en un emulador o dispositivo Android (Flutter SDK y Docker no están instalados en este equipo).

- **2026-11-22 14:36 — Despliegue local, build Android y mejora UX de navegación:**
  - **Backend + MongoDB Atlas:**
    - Agregado script `npm.cmd run start:memory` (`backend/src/startMemory.js`) como alternativa sin Docker/Mongo local (usa `mongodb-memory-server` con auto-seed).
    - Configurado `backend/.env` apuntando a MongoDB Atlas (base `sts`, archivo ignorado por `.gitignore`) y ejecutado `node backend/src/seed/seedData.js` con éxito (`coordinator: 1, school: 1, routes: 2, students: 3`).
  - **Frontend Android compilado y probado en emulador:**
    - Detectado Flutter SDK en `C:\Users\JoelA\flutter` y emulador `emulator-5554` (Android 16 / API 36).
    - Actualizadas versiones mínimas requeridas por Flutter: Gradle `8.14` (`gradle-wrapper.properties`), AGP `8.11.1` y Kotlin `2.2.20` (`settings.gradle.kts`).
    - Creado el ícono adaptativo `@mipmap/ic_launcher` (`res/values/colors.xml`, `res/drawable/ic_launcher_foreground.xml`, `res/mipmap-anydpi-v26/ic_launcher.xml` y respaldo `res/mipmap-mdpi/ic_launcher.png`).
    - Verificado `flutter analyze` (**0 errores**) y `flutter build apk --debug` (**APK generado correctamente** en `frontend/build/app/outputs/flutter-apk/app-debug.apk`).
  - **UX — Botón de regresar (`←`) en esquina superior izquierda:**
    - Actualizado `StsAppBar` para mostrar siempre el ícono `←` cuando `showBack: true` (`Navigator.pop()` si hay historial, o confirmación para volver a selección de rol con `confirmAndLogout` si es raíz del rol).
    - Habilitado `showBack: true` en `CoordinatorHomeScreen`, `TutorHomeScreen`, `TutorLiveTrackingScreen` (vuelve a `TutorHomeScreen`), `DriverRouteScreen` y `DriverTripFinishedScreen` (vuelve a `DriverRouteScreen`).
    - Revalidado con `flutter analyze` (**0 errores**).
