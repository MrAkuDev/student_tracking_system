# STS — Student Tracking System

Prototipo de alta fidelidad de la aplicación móvil Android **STS (Student Tracking System)** para el control y monitoreo en tiempo real de rutas de transporte escolar, con backend en **Node.js + Express + MongoDB + Socket.IO** y app móvil en **Flutter (Material Design 3)**.

---

## Estructura del Proyecto

```text
student_tracking_system/
├── docker-compose.yml          # MongoDB 7 local listo para usar
├── .env.example                # Variables de entorno de referencia
├── building.md                 # Contrato técnico REST/Socket.IO y bitácora
├── assets/                     # Bocetos originales de pantallas
├── backend/                    # API REST + Socket.IO + Mongoose + Seed
└── frontend/                   # Aplicación Flutter Android (3 roles)
```

---

## 1. Levantar Base de Datos y Backend

### Opción A — MongoDB local con Docker
```bash
docker compose up -d
```

### Opción B — MongoDB Atlas
Cambia únicamente `MONGO_URI` en `backend/.env` por tu cadena `mongodb+srv://...`.

### Opción C — Sin instalar MongoDB ni Docker (en memoria)
```bash
cd backend
npm run start:memory      # Levanta MongoDB en memoria con seed demo
```

### Iniciar el servidor Node.js (con Docker o MongoDB Atlas)
```bash
cd backend
cp .env.example .env      # En Windows PowerShell: copy .env.example .env
npm install               # En PowerShell si hay ExecutionPolicy: npm.cmd install
npm start                 # Escucha en http://0.0.0.0:3000
```

- Con `AUTO_SEED=true` (por defecto), si la base de datos está vacía se precargan los datos demo automáticamente.
- También puedes ejecutar el seed manualmente de forma idempotente:
  ```bash
  npm run seed
  ```
- **Endpoints de administración de BD (también disponibles desde la app en Configurar servidor):**
  - `POST /api/admin/reset-db` — Elimina rutas, alumnos e incidentes, conservando solo el coordinador (`admin`/`1234`) y la escuela base.
  - `POST /api/admin/seed-demo` — Reinicia la BD y vuelve a cargar el dataset demo (`RUT-101`, `RUT-102`, `ALU-1001..ALU-1003`).
- Para verificar todo el backend sin instalar MongoDB (usa `mongodb-memory-server` + 4 clientes Socket.IO):
  ```bash
  npm run test:smoke
  ```

---

## 2. Ejecutar la Aplicación Flutter (Android)

Requisitos: Flutter SDK (`>= 3.27.0`) y Android Studio / emulador Android o dispositivo físico.

```bash
cd frontend
flutter pub get
flutter run
```

### Generar APK instalable para teléfono Android
```bash
cd frontend
flutter build apk --release
```
El archivo listo para instalar se genera en `frontend/build/app/outputs/flutter-apk/app-release.apk` (ya incluye todos los permisos necesarios: Internet, GPS, notificaciones, llamadas `tel:` y compartir códigos).

> Si en tu máquina falta algún archivo del Gradle Wrapper, revisa [`frontend/README_ANDROID.md`](frontend/README_ANDROID.md).

### Configurar URL del servidor y administrar la BD desde la app
En la pantalla inicial (`¡Hola!`), toca el ícono de engranaje (arriba a la derecha):
- **Nube (Render, por defecto):** `https://student-tracking-system-6pxx.onrender.com`
- **Emulador Android (local):** `http://10.0.2.2:3000`
- **Dispositivo físico en la misma red Wi-Fi:** `http://<IP-LOCAL-DE-TU-PC>:3000`

Usa el botón **Probar conexión** (`GET /api/health`) antes de guardar. *(Nota: en el plan gratuito de Render la primera petición tras inactividad puede tardar ~30–50 s en despertar.)*

En la misma pantalla, bajo **Base de datos (Pruebas y Demo)**, puedes ejecutar con confirmación:
- **Cargar datos demo (Seed):** restaura las rutas y alumnos de ejemplo.
- **Resetear base de datos:** deja la base de datos limpia (solo `admin` / `1234` y escuela base) para crear rutas desde cero.

---

## 3. Credenciales y Códigos Demo (Seed Inicial)

| Rol | Credencial / Código | Detalles |
|---|---|---|
| **Coordinador** | Usuario: `admin` / Password: `1234` | Coordinadora Ana López (`+526141234567`) |
| **Chofer** | `RUT-101` (Ruta Norte, 07:30) o `RUT-102` (Ruta Sur) | Vista 100% anónima (`Punto A`, `Punto B`..., `Escuela`) |
| **Tutor** | `ALU-1001`, `ALU-1002` (confirmados hoy) o `ALU-1003` (pendiente) | Todos precargados en `RUT-101` con pin cercano a la escuela |

---

## 4. Guía Rápida de Prueba End-to-End (Modo Demo)

1. **Activar Modo Demo:** Toca el chip **Demo** en la esquina superior derecha (disponible en selección de rol, Tutor y Chofer). Esto habilita el simulador de recorrido y acorta el temporizador post-llegada de **5 minutos → 10 segundos**.
2. **Coordinador:** Inicia sesión (`admin` / `1234`) → abre `Ruta Norte (RUT-101)` → puedes editar hora, mover el pin de la escuela o agregar/compartir alumnos → toca **Iniciar ruta** → el sistema calcula la polilínea OSRM y abre el mapa en vivo.
3. **Tutor:** Entra con `ALU-1001` (o cambia de rol desde el menú `⋮`) → valida datos y pin → en *Próximas recolecciones* prueba cancelar un día o pulsa **Simular notificación (1h antes)** → confirma el servicio → observa el seguimiento en vivo y las alertas de proximidad.
4. **Chofer:** Entra con `RUT-101` → verás únicamente paradas anónimas (`Punto A`, `Punto B`, `Escuela`) → abre el panel de **Simulación** → pulsa **Reproducir** o **Siguiente parada** para activar el panel **Confirmar recolección de alumno** → prueba el botón rojo **SOS** (pausa el viaje y abre el marcador con el teléfono del coordinador) → pulsa **Llegar a escuela**.
5. **Cierre de ruta:** En el Coordinador aparecerá **Confirmar llegada** (o **Reportar problema** con selector de alumno y llamada al tutor). Al confirmar, el Chofer pasa a **Viaje finalizado** y el Tutor recibe el aviso de llegada y regresa automáticamente a *Próximas recolecciones*.
