# Prompt de Desarrollo: STS (Student Tracking System)

Actúa como un arquitecto de software e ingeniero full-stack senior especializado en **Node.js, MongoDB, Socket.IO y Flutter (Android)**. Tu tarea es diseñar, implementar y verificar un prototipo de alta fidelidad completamente funcional de la aplicación móvil Android **STS (Student Tracking System)** para el control y monitoreo en tiempo real de rutas de transporte escolar.

---

## 1. Propósito del Sistema y Roles

**STS** coordina el transporte escolar en tiempo real entre tres perfiles de usuario dentro de una sola aplicación móvil Android:

1. **Coordinador escolar:** Administra rutas, horarios, ubicación de la escuela (destino final), alta/edición de alumnos y tutores, inicio de ruta, monitoreo en vivo con estado de recolección por alumno, control de incidencias/estatus de emergencia y confirmación final de llegada.
2. **Tutor (padre de familia):** Accede con un código único generado por el coordinador, valida/edita datos del alumno y tutor, fija su punto de abordaje en el mapa, gestiona cancelaciones de días futuros, recibe notificación 1 hora antes para confirmar o rechazar el servicio del día y sigue el transporte en tiempo real.
3. **Chofer:** Accede con el código de su ruta, visualiza la ruta y paradas anónimas (`Punto A`, `Punto B`, `Punto C`, ..., `Escuela`) sin acceso a datos personales de alumnos, confirma recolecciones al pasar por cada parada y cuenta con un botón SOS de emergencia.

---

## 2. Estructura del Proyecto y Stack Tecnológico

Genera el proyecto respetando estrictamente esta estructura de carpetas en la raíz:

```text
sts-app/
├── docker-compose.yml          # Levanta MongoDB local listo para usar
├── .env.example                # Variables de entorno (MONGO_URI, PORT, etc.)
├── README.md                   # Guía rápida de instalación, seed y pruebas demo
├── backend/                    # API REST + Socket.IO + MongoDB
│   ├── package.json
│   ├── .env.example
│   └── src/
│       ├── index.js
│       ├── config/db.js
│       ├── models/
│       ├── routes/
│       ├── controllers/
│       ├── sockets/
│       └── seed/seedData.js
└── frontend/                   # Aplicación Flutter para Android
    ├── pubspec.yaml
    ├── android/                # Permisos GPS, notificaciones, llamadas, internet
    └── lib/
        ├── main.dart
        ├── config/
        ├── theme/
        ├── models/
        ├── services/
        ├── providers/
        ├── widgets/
        └── screens/
            ├── onboarding/
            ├── coordinator/
            ├── tutor/
            └── driver/
```

### Stack Obligatorio
- **Backend (`/backend`):**
  - Node.js (v18+) + Express
  - MongoDB + Mongoose (compatible con MongoDB local vía `docker-compose.yml` o MongoDB Atlas cambiando únicamente `MONGO_URI` en `.env`)
  - Socket.IO para sincronización en tiempo real entre Coordinador, Chofer y Tutores
  - Generación de `uuid` (v4) y códigos cortos legibles (`RUT-XXX` para rutas, `ALU-XXXX` para alumnos)
  - CORS habilitado y manejo limpio de errores JSON
- **Frontend (`/frontend`):**
  - Flutter (Material Design 3, enfocado en Android)
  - Gestión de estado modular (`provider` o `flutter_riverpod`)
  - **Mapas y Ruteo:** `flutter_map` + OpenStreetMap con caché de tiles (online con caché local para fluidez) + consumo de **OSRM** (`https://router.project-osrm.org/route/v1/driving/...`) para dibujar rutas sobre calles estilo Uber, guardando la polilínea calculada y con fallback a polilínea directa si no hay respuesta de OSRM.
  - **Tiempo real:** `socket_io_client`
  - **GPS y Proximidad:** `geolocator` + cálculo de distancia Haversine
  - **Notificaciones locales Android:** `flutter_local_notifications` (canal de alta prioridad, sonido, vibración y visibilidad en pantalla bloqueada)
  - **Utilidades nativas:** `url_launcher` (llamadas `tel:`), `share_plus` y `Clipboard` (compartir códigos), `shared_preferences` (guardar sesión/rol y URL del servidor)

---

## 3. Identidad Visual y Experiencia de Usuario (UX/UI)

- **Nombre de la App:** `STS` (subtítulo `Student Tracking System`).
- **Estilo:** Minimalista **Android Material Design 3**, **tema claro** con paleta de **azul amigable escolar**, limpio, moderno, cálido y legible:
  - Primario (Azul escolar amigable): `#2563EB`
  - Primario suave / Contenedor: `#DBEAFE`
  - Fondo general: `#F8FAFC`
  - Superficie / Tarjetas: `#FFFFFF` (bordes redondeados `16px`, sombra sutil o borde `#E2E8F0`)
  - Texto principal: `#0F172A` / Secundario: `#475569`
  - Semánticos:
    - Confirmado / Recogido (Verde): `#16A34A`
    - Pendiente (Azul): `#2563EB`
    - En pausa / Acercándose (Ámbar): `#D97706`
    - SOS / Avería / Reportar problema (Rojo): `#DC2626`
- **Acceso rápido para pruebas:** Incluir en los tres roles (en el `AppBar` o menú discreto) un botón de **"Cambiar de rol / Cerrar sesión"** que permita volver a la pantalla inicial de selección de rol sin reinstalar la app, y un ícono de configuración en la pantalla de inicio para ajustar la IP/URL del backend (útil para emulador Android `10.0.2.2` o dispositivo físico en red local).

---

## 4. Reglas Críticas de Negocio, Privacidad y Modo Simulación

1. **Privacidad estricta en el rol Chofer:**
   - El chofer **NUNCA** puede ver nombres de alumnos, apellidos, grados escolares ni datos de los tutores.
   - El endpoint del backend y los eventos Socket.IO enviados al chofer **deben omitir/sanitizar** esos campos y exponer únicamente `stopLabel` (`Punto A`, `Punto B`, `Punto C`...), `stopOrder`, `lat`, `lng`, `studentId` (opaco para confirmar recolección) y `status`.
2. **Lista dinámica del día:**
   - Cuando el coordinador inicia una ruta, la lista activa de paradas y alumnos en curso se construye **exclusivamente con los alumnos cuyos tutores confirmaron el servicio** para ese día (o no lo cancelaron si ya estaban confirmados).
3. **Códigos cortos + UUID:**
   - Cada ruta tiene un `uuid` y un `shortCode` único legible (ej. `RUT-101`).
   - Cada alumno tiene un `uuid` y un `shortCode` único legible (ej. `ALU-4821`).
   - Los campos de ingreso de código en **Tutor** y **Chofer** deben aceptar indistintamente el `shortCode` (insensible a mayúsculas/minúsculas) o el `uuid` completo.
4. **GPS Real + Controles de Simulación (Modo Demo):**
   - El sistema debe soportar **GPS real** del dispositivo para el chofer y detección real por proximidad (acercándose `< 300m`, en parada `< 50m`, llegada a escuela `< 60m`).
   - Adicionalmente, incorporar un **panel discreto de Modo Simulación** (activable mediante un switch/botón `Demo`) para poder probar todo el flujo end-to-end fácilmente:
     - **En Chofer:** Selector `GPS Real / Simular Recorrido`, con botones `Reproducir/Pausar avance automático` sobre los puntos de la polilínea y `Avanzar a siguiente parada / Llegar a escuela`.
     - **En Tutor:** Botón discreto `Simular notificación (1h antes)` que dispara la notificación local Android de alta prioridad y abre el flujo de confirmación del día; y modo rápido para el temporizador post-llegada (**5 minutos reales** por defecto, o **10 segundos** si el Modo Demo está activo).

---

## 5. Diseño del Backend (`/backend`)

### 5.1 Modelos MongoDB (Mongoose)

1. **`Coordinator`**:
   - `username` (String, unique), `password` (String — prototipo de alta fidelidad, login simulado contra BD), `name` (String), `phone` (String — número al que llama el chofer en caso de SOS).
2. **`SchoolConfig`** (o configuración default reutilizable):
   - `name` (String), `address` (String), `location`: `{ lat: Number, lng: Number }`.
3. **`Route`**:
   - `uuid` (String, unique), `shortCode` (String, unique, ej. `RUT-101`), `name` (String), `startTime` (String, ej. `"07:30"`).
   - `schoolLocation`: `{ lat: Number, lng: Number, address: String }` (inicializado con la ubicación default de la escuela en MongoDB y editable por el coordinador en el mapa).
   - `status`: Enum `['idle', 'in_progress', 'paused', 'breakdown', 'arrived_school', 'completed']`.
   - `currentLocation`: `{ lat: Number, lng: Number, updatedAt: Date }`.
   - `activeTripId` (ObjectId, nullable), `coordinatorId` (ObjectId).
4. **`Student`**:
   - `uuid` (String, unique), `shortCode` (String, unique, ej. `ALU-4821`), `routeId` (ObjectId ref `Route`).
   - `firstName`, `lastName`, `grade` (Strings).
   - `tutor`: `{ firstName, lastName, phone1, phone2 }`.
   - `pickupLocation`: `{ lat: Number, lng: Number, isSet: Boolean }`.
   - `weeklySchedule`: `{ monday: Boolean, tuesday: Boolean, wednesday: Boolean, thursday: Boolean, friday: Boolean }` (todos `true` por defecto; permite cancelar días futuros).
   - `todayServiceStatus`: Enum `['pending', 'confirmed', 'rejected']` (para el día de recolección).
   - `pickupStatus`: Enum `['pending', 'approaching', 'arrived_stop', 'picked_up', 'dropped_at_school']`.
5. **`IncidentReport`**:
   - `routeId` (ObjectId), `reportedByRole` (`'coordinator' | 'driver'`), `description` (String), `involvedStudentId` (ObjectId, nullable), `createdAt` (Date).

### 5.2 Seed Inicial Automático (Idempotente)
Al arrancar el servidor (si la base de datos está vacía) o mediante `npm run seed`, precargar:
- **Coordinador default:** `usuario: "admin"`, `password: "1234"`, `name: "Coordinadora Ana López"`, `phone: "+526141234567"`.
- **Escuela default:** Ubicación fija por defecto en MongoDB (ej. Chihuahua, México: `lat: 28.6353, lng: -106.0889`, `"Escuela Primaria STS"`).
- **Ruta 1 (`RUT-101`):** `"Ruta Norte"`, `startTime: "07:30"`, con 3 alumnos precargados (`ALU-1001`, `ALU-1002`, `ALU-1003`) con pines cercanos a la escuela y estado `confirmed` en al menos 2 de ellos para permitir pruebas inmediatas, además de `Ruta 2` (`RUT-102`).

### 5.3 Endpoints REST Principales
- **Auth / Acceso:**
  - `POST /api/coordinator/login` (valida `username`/`password` contra MongoDB).
  - `POST /api/tutor/access` (recibe `code` -> busca por `shortCode` o `uuid` en `Student`, retorna alumno, tutor, ruta y horarios).
  - `POST /api/driver/access` (recibe `code` -> busca por `shortCode` o `uuid` en `Route`, retorna datos sanitizados de la ruta y número telefónico del coordinador).
- **Coordinador / Rutas / Alumnos:**
  - `GET /api/routes`, `POST /api/routes`, `GET /api/routes/:id`, `PUT /api/routes/:id` (nombre, `startTime`, `schoolLocation`), `DELETE /api/routes/:id`.
  - `POST /api/routes/:id/students`, `PUT /api/students/:id`, `DELETE /api/students/:id`.
  - `POST /api/routes/:id/start` (cambia ruta a `in_progress`, inicializa paradas con los alumnos confirmados y emite Socket.IO).
  - `PATCH /api/routes/:id/status` (cambia entre `in_progress`, `paused`, `breakdown`).
  - `POST /api/routes/:id/arrived-school` (marca `arrived_school` cuando el bus llega a destino).
  - `POST /api/routes/:id/confirm-arrival` (marca `completed`, marca alumnos `dropped_at_school`, resetea ciclo para siguiente día y notifica a tutores y chofer).
  - `POST /api/routes/:id/incidents` (guarda reporte de problema con descripción y alumno opcional).
- **Tutor:**
  - `PUT /api/tutor/students/:id/profile` (actualiza datos de tutor/alumno y `pickupLocation`).
  - `PATCH /api/tutor/students/:id/schedule` (cancela o reactiva días específicos de Lunes a Viernes).
  - `POST /api/tutor/students/:id/today-confirmation` (`{ decision: 'confirmed' | 'rejected' }`).
- **Chofer (Respuestas 100% sanitizadas sin nombres de alumnos):**
  - `GET /api/driver/routes/:routeId/stops` (devuelve solo paradas confirmadas con `stopLabel: "Punto A"`, coordenadas, `pickupStatus` y `schoolLocation`).
  - `POST /api/driver/routes/:routeId/confirm-pickup` (`{ studentId }` -> marca `picked_up`, notifica en tiempo real al coordinador y al tutor).
  - `POST /api/driver/routes/:routeId/sos` (cambia automáticamente la ruta a `paused`, registra evento y emite alerta SOS en tiempo real).

### 5.4 Eventos Socket.IO (Salas por `route:<routeId>` y `student:<studentId>`)
- `join_route` / `join_student`
- `driver_location_update` (emitido por chofer -> retransmite `bus_location_updated` a coordinador y tutores de la ruta, evaluando cercanía al pin de cada tutor y a la escuela)
- `route_status_changed` (`in_progress`, `paused`, `breakdown`, `arrived_school`, `completed`)
- `student_pickup_updated` (actualiza palomita verde en Coordinador y estatus en Tutor)
- `proximity_alert` (`approaching` o `arrived_stop` dirigido al tutor específico)
- `driver_sos_triggered` (alerta al coordinador y cambia estatus a `En pausa`)

---

## 6. Especificación Detallada de Pantallas y Flujos (`/frontend`)

Implementa fielmente cada vista correlacionada con los bocetos de diseño:

### 6.1 Inicio de App (Selección de Rol)
- **Pantalla `RoleSelectionScreen`:**
  - Encabezado amigable: **"¡Hola!"** y subtítulo **"Por favor escoge tu rol"**.
  - Tres botones grandes y claros (Material 3):
    1. **Tutor** → navega a `TutorCodeScreen` (`Tutor 1`).
    2. **Coordinador** → navega a `CoordinatorLoginScreen` (`Coordinador 0`).
    3. **Chofer** → navega a `DriverCodeScreen` (`Chofer 5`).
  - Ícono discreto de configuración de servidor (URL API) en la esquina superior derecha.

---

### 6.2 Flujo del Coordinador (`Coordinador 0` – `Coordinador 6`)

- **`Coordinador 0` — Inicio de sesión (`CoordinatorLoginScreen`):**
  - Botón `Atrás`.
  - Título: *"Iniciar sesión como coordinador"*.
  - Campos `Usuario` y `Password` + botón **Ingresar**.
  - Nota discreta de prototipo (ej. `Demo: admin / 1234`) para facilitar pruebas.
  - Al autenticar → navega a `Coordinador 1`.

- **`Coordinador 1` — Inicio / Mis Rutas (`CoordinatorHomeScreen`):**
  - Encabezado: **"¡Hola!"**, sección **"Mis Rutas"** con botón `+` para crear una nueva ruta (abre `Coordinador 2`).
  - Lista de tarjetas de rutas (`Ruta 1`, `Ruta 2`, etc.) mostrando nombre, código corto (`RUT-101`), hora de inicio y estatus actual.
  - Acciones en cada tarjeta:
    - **Ícono de autobús/transporte:** abre `Coordinador 4` para ver el progreso de la ruta en vivo (destacado cuando la ruta está en progreso).
    - **Ícono de lápiz:** abre `Coordinador 2` para editar datos, escuela y alumnos de la ruta.
    - **Ícono de compartir:** comparte el código corto/UUID de la ruta (para el chofer).

- **`Coordinador 2` — Nueva ruta o edición (`RouteDetailEditScreen`):**
  - Botón `Atrás`.
  - Encabezado con nombre de la ruta y tres íconos:
    - **Lápiz:** editar nombre de la ruta (diálogo o edición inline).
    - **Bote de basura:** eliminar la ruta (**siempre** mostrando un diálogo de confirmación).
    - **Compartir:** compartir código de ruta (`RUT-XXX`) al chofer.
  - Tarjeta de configuración de ruta:
    - **Hora de inicio:** selector de hora (`TimePicker`, ej. `07:30 AM`).
    - **Botón/campo "Definir escuela":** con ícono de pin/escuela; al tocarlo abre un mapa interactivo (`SchoolLocationPickerScreen`) donde el coordinador coloca o mueve el pin del destino final (precargado con la ubicación default de MongoDB) y guarda.
  - Sección **"Alumnos"** con botón `+` (abre `Coordinador 3`).
  - Lista de alumnos de la ruta: muestra nombre, grado, código corto (`ALU-XXXX`), estado de confirmación de hoy, **ícono de compartir** (comparte código único del alumno al tutor), **ícono `X`** (eliminar alumno con confirmación) y toque en tarjeta para editar (`Coordinador 3`).
  - **Botón principal inferior: "Iniciar ruta"**:
    - Al presionarlo, abre un **modal de confirmación** (*"¿Iniciar ruta ahora?"*, mostrando la cantidad de alumnos confirmados para hoy).
    - Al confirmar: inicia la ruta en el backend y navega a `Coordinador 4`.

- **`Coordinador 3` — Agregar o editar alumno (`StudentFormScreen`):**
  - Botón `Atrás`.
  - Sección **"Información alumno"**: `Nombre`, `Apellido`, `Grado escolar`.
  - Sección **"Información tutor"**: `Nombre`, `Apellido`, `Número 1`, `Número 2`.
  - Botón **"Guardar"**: persiste en MongoDB. Si es un alumno nuevo, muestra un diálogo/bottom sheet con el código generado (`ALU-XXXX` + UUID) y un botón inmediato de **Compartir código al tutor**, luego regresa a `Coordinador 2`.

- **`Coordinador 4` — Ruta en progreso (`CoordinatorLiveRouteScreen`):**
  - Botón `Atrás`.
  - Encabezado con nombre de la ruta y **chip de estatus en vivo** (`En progreso`, `En pausa`, `Avería`).
  - **Barra de control de estatus para el coordinador:** permite cambiar manualmente el estatus entre **`En progreso`**, **`En pausa`** y **`Avería`** (especialmente tras recibir una alerta SOS del chofer). Si el chofer presionó SOS, mostrar un banner de alerta destacado.
  - **Mapa en vivo (`flutter_map`):** polilínea trazada con OSRM, pines de paradas confirmadas, pin de la escuela y marcador del autobús moviéndose en tiempo real.
  - **Lista inferior de alumnos** (solo confirmados para el servicio de hoy):
    - **Palomita verde (`✓`)**: alumno ya recogido.
    - **Círculo azul (`●`)**: alumno pendiente por recoger.
  - Cuando el transporte llega a la escuela (`arrived_school`), muestra botón prominente o navega automáticamente a `Coordinador 5`.

- **`Coordinador 5` — Confirmar llegada (`ConfirmArrivalScreen`):**
  - Botón `Atrás`.
  - Nombre de la ruta (`Ruta XXX`).
  - Mensaje central: **"El transporte llegó al destino. Confirma que todos los alumnos se encuentran."**
  - Botón principal **"Confirmar"**: cierra la ruta normalmente, notifica a tutores y chofer, y regresa a `Coordinador 1`.
  - Texto/botón rojo debajo: **"Reportar problema"** → navega a `Coordinador 6`.

- **`Coordinador 6` — Reportar problema (`ReportProblemScreen`):**
  - Botón `Atrás`.
  - Título: **"Reportar Problema"**.
  - Campo multilínea amplio con etiqueta **"¿Qué pasó?"** (*"Describe el problema"*).
  - Dropdown: **"¿Involucra a algún alumno?"** poblado con *"Ninguno"* + la lista de alumnos confirmados de esa ruta del día.
  - Si se selecciona un alumno: mostrar tarjeta **"Después del reporte, comunícate con el tutor"** con nombre completo del tutor, `Número 1`, `Número 2` y botón **Llamar** (`tel:`).
  - Botón rojo con letras blancas **"Reportar"**: guarda el reporte en MongoDB y finaliza el flujo regresando a `Coordinador 1`.

---

### 6.3 Flujo del Tutor (`Tutor 1` – `Tutor 7` + Día de Recolección)

- **`Tutor 1` — Ingreso de código (`TutorCodeScreen`):**
  - Título **"¡Hola!!!"**, subtítulo *"Por favor, ingresa el código de tu escuela para empezar"*.
  - Campo de texto para código (`ALU-XXXX` o `UUID`).
  - Enlace debajo del campo: **"¿No tienes código?"** → navega a `Tutor 2`.
  - Botón **"Ingresar"** → valida código y navega a `Tutor 3`.

- **`Tutor 2` — ¿No tienes código? (`TutorNoCodeInfoScreen`):**
  - Texto informativo: *"Cada escuela afiliada al sistema STS (Student Tracking System) tiene personal a cargo de llevar el control de las cuentas y su información. Comunícate con ellos para obtener tu código."*
  - Botón con flecha izquierda **"Regresar"** → vuelve a `Tutor 1`.

- **`Tutor 3` — Bienvenida tras código (`TutorWelcomeScreen`):**
  - Título: **"Bienvenido [Nombre del tutor]"**.
  - Texto: *"Antes de continuar, asegurémonos que tus datos están correctos."*
  - Botón con flecha derecha **"Empezar"** → navega a `Tutor 4`.

- **`Tutor 4` — Validar datos (`TutorValidateDataScreen`):**
  - Botón `Regresar`.
  - Título **"Tus Datos"** con campos prellenados y editables:
    - Tutor: `Nombre`, `Apellido`, `Número 1`, `Número 2`.
    - *"Datos del estudiante"*: `Nombre`, `Apellido`, `Grado`.
  - Botón con flecha derecha **"Continuar"** → navega a `Tutor 5`.

- **`Tutor 5` — Establecer punto de abordaje (`TutorPickupPinScreen`):**
  - Título: **"Establece el punto de abordaje"**.
  - Subtítulo de privacidad: *"Nadie tendrá acceso a esta ubicación más que el dueño de este dispositivo."*
  - Mapa interactivo (`flutter_map`) donde el tutor coloca/ajusta el pin de recolección (incluyendo botón rápido para centrar en su ubicación actual).
  - Botón **"Finalizar"** → navega a `Tutor 6`.

- **`Tutor 6` — Pantalla genérica de carga (`TutorSavingScreen`):**
  - Indicador circular animado + texto **"Guardando tu información"**.
  - Guarda perfil y pin en MongoDB y transiciona automáticamente a `Tutor 7`.

- **`Tutor 7` — Inicio / Próximas recolecciones (`TutorHomeScreen`):**
  - Título: **"Próximas recolecciones"**.
  - Lista de los días de la semana (**Lunes, Martes, Miércoles, Jueves, Viernes**); cada fila tiene un botón `X` (o toggle cancelar/reactivar) para cancelar la recolección de un día específico y persistirlo en MongoDB.
  - Nota informativa visible: *"Nota: El mismo día podrás cancelar el servicio 1 hora antes."*
  - **Botón flotante (FAB) con ícono `!` / editar:** navega a editar los datos y el pin (`Tutor 4` → `Tutor 5`).
  - **Control Demo discreto:** opción para **"Simular notificación 1h antes"** (además de la programación local automática respecto a la `startTime` de la ruta).

- **Flujo Día de Recolección (Notificación + Confirmación + Seguimiento en vivo):**
  1. **Notificación local Android (1 hora antes):** Alta prioridad, sonido, visible en pantalla bloqueada con mensaje *"La recolección empezará pronto, confirma el servicio"*. Al tocarla abre `TutorConfirmServiceScreen`.
  2. **Confirmar servicio (`TutorConfirmServiceScreen`):**
     - Título: **"Confirma tu servicio"**, texto: *"El servicio de recolección empezará pronto. Por favor confirma."*
     - Dos botones circulares grandes:
       - `X` — **"No lo necesito"**
       - `✓` — **"Confirmar"**
     - Al tocar cualquiera de las dos opciones, abrir **diálogo de confirmación obligatorio**: *"¿Estás seguro de confirmar/rechazar el servicio?"* (`NO` / `SÍ`).
     - Si rechaza (`SÍ`): guarda en BD y navega a `Tutor 7` (*Próximas recolecciones*).
     - Si confirma (`SÍ`): guarda en BD y navega a `TutorLiveTrackingScreen`.
  3. **Seguimiento en vivo (`TutorLiveTrackingScreen`):**
     - **Barra superior de estatus dinámica** (cambia color y texto en tiempo real):
       - `Preparando transporte`
       - `Transporte en camino`
       - `Transporte cerca de tu ubicación` (dispara notificación local)
       - `El transporte llegó a tu punto` (dispara notificación local)
       - `Estudiante a bordo - Rumbo a la escuela`
       - `Transporte en pausa` / `Avería reportada` (alerta visual + notificación local)
       - `Llegó a la escuela` (dispara notificación local + muestra aviso de llegada + regresa automáticamente a `Tutor 7` después de **5 minutos**, o **10 segundos** en Modo Demo).
     - **Mapa en vivo (`flutter_map`)** con el autobús en movimiento, ruta trazada, pin de abordaje del tutor y pin de la escuela.
     - **Botón flotante `!` (información):** muestra detalles de la ruta y estado actual.

---

### 6.4 Flujo del Chofer (`Chofer 5` → `Chofer 1` → `Chofer 2` → `Chofer 3` → `Chofer 4`)

- **`Chofer 5` — Inicio de sesión con código de ruta (`DriverCodeScreen`):**
  - Título **"¡Hola!!"**, texto *"Ingresa el código de ruta para iniciar"*.
  - Campo `Código` (acepta `RUT-XXX` o `UUID`) y botón **"Ingresar"**.
  - Al validar → navega a `Chofer 1`.

- **`Chofer 1` — Inicio / Mapa de ruta (`DriverRouteScreen`):**
  - Encabezado **"¡Hola!"**.
  - Si el coordinador aún no inicia la ruta: muestra estado de espera conectado a Socket.IO (*"Esperando a que el coordinador inicie la ruta..."*).
  - Al iniciar la ruta: muestra **"Todo listo para la ruta"** y el mapa a gran tamaño con la polilínea trazada por OSRM y las paradas marcadas exclusivamente como **`Punto A`, `Punto B`, `Punto C`...** y **`Escuela`** (sin nombres de alumnos).
  - Muestra badge si el coordinador cambió el estatus a `En pausa` o `Avería`.
  - **Botón flotante rojo SOS** (ícono de alerta/campana en esquina inferior) → abre `Chofer 3`.
  - **Controles de GPS Real / Modo Simulación** (panel compacto colapsable): permite emitir ubicación por GPS real o simular el movimiento del vehículo punto por punto a lo largo de la polilínea.

- **`Chofer 2` — Confirmación de recolección (Overlay / BottomSheet en `DriverRouteScreen`):**
  - Cuando el transporte se aproxima/pasa sobre una parada (`< 50m` en GPS real o al alcanzarla en simulación), aparece automáticamente el panel inferior/modal:
    - Texto: **"Confirmar recolección de alumno — Punto [X]"** (sin nombre del alumno).
    - Botón **"Confirmar"**.
  - Al confirmar: actualiza en backend (`picked_up`), notifica en tiempo real al coordinador y al tutor, y oculta el panel para continuar al siguiente punto.
  - El **botón flotante rojo SOS** sigue accesible.

- **`Chofer 3` — Reportar problema / SOS (`DriverSosScreen`):**
  - Botón `Atrás`.
  - Título: **"Reportar problema"**.
  - Texto: *"Contacta de inmediato al coordinador para reportar cualquier problema."*
  - Botón rojo **"Reportar"**:
    1. Envía evento SOS al backend, cambiando automáticamente el estatus del viaje a **`En pausa`** y notificando al coordinador y tutores.
    2. Abre la app de teléfono nativa con el número del coordinador prellenado (`tel:<coordinatorPhone>`).

- **`Chofer 4` — Término del viaje (`DriverTripFinishedScreen`):**
  - Se muestra automáticamente cuando el autobús llega a la escuela y el coordinador confirma la llegada en `Coordinador 5`.
  - Título: **"Viaje finalizado"**.
  - Texto: *"Gracias por tu servicio. El próximo viaje aparecerá aquí cuando esté disponible."* + horario de la siguiente ruta (ej. *"Siguiente ruta programada: mañana a las 07:30"*).
  - Botón discreto para volver a espera de ruta (`Chofer 1`) o cambiar de rol.

---

## 7. Configuración de Android, Permisos y Entorno

- Configurar `AndroidManifest.xml` en `/frontend/android/app/src/main/AndroidManifest.xml` con los permisos necesarios:
  - `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`.
  - `<queries>` para el intent `tel:` de `url_launcher`.
  - `usesCleartextTraffic="true"` habilitado para pruebas locales contra Node.js en HTTP.
- Configurar `docker-compose.yml` en la raíz levantando `mongo:7` con volumen persistente y puerto `27017`, más `.env.example` documentando tanto conexión local (`mongodb://localhost:27017/sts`) como Atlas (`mongodb+srv://...`).

---

## 8. Plan de Ejecución y Criterios de Aceptación

Ejecuta el desarrollo en este orden y verifica cada fase antes de avanzar:

1. **Infraestructura y Backend:** Crear `docker-compose.yml`, `.env.example`, modelos Mongoose, seed idempotente, endpoints REST (verificando sanitización del rol Chofer) y eventos Socket.IO. Probar arranque del servidor y endpoints clave.
2. **Base de Flutter y Diseño:** Configurar `pubspec.yaml`, permisos Android, tema Material 3 claro azul amigable, servicio HTTP + Socket.IO, servicio de mapas OSRM (`flutter_map`), notificaciones locales y configuración de URL del backend.
3. **Pantallas por Rol:** Implementar `RoleSelectionScreen`, luego **Coordinador (`0`–`6`)**, **Tutor (`1`–`7` + Día de Recolección)** y **Chofer (`5`, `1`–`4`)** con el Modo Simulación integrado.
4. **Verificación End-to-End:** Comprobar que:
   - El coordinador puede iniciar sesión (`admin`/`1234`), crear/editar una ruta, definir la escuela en el mapa, agregar un alumno y compartir `ALU-XXXX` y `RUT-XXX`.
   - El tutor puede entrar con `ALU-XXXX`, editar datos, fijar su pin, cancelar un día en `Tutor 7`, disparar la notificación de 1 hora antes, confirmar el servicio y ver el mapa en vivo.
   - El chofer puede entrar con `RUT-XXX`, ver solo puntos anónimos (`Punto A`, `Punto B`...), simular el recorrido, confirmar recolecciones (actualizando palomitas verdes en Coordinador y estatus en Tutor) y activar el botón SOS (cambiando el estatus a `En pausa` y abriendo el marcador telefónico).
   - Al llegar a la escuela, el coordinador puede confirmar la llegada (o reportar un problema con dropdown de alumno y llamada al tutor), el chofer pasa a `Viaje finalizado` y el tutor recibe notificación de llegada y vuelve a `Próximas recolecciones`.