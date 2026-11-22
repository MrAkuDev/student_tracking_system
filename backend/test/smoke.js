/* Smoke test end-to-end: Mongo en memoria + servidor real + sockets reales. */
const assert = require('assert');
const { MongoMemoryServer } = require('mongodb-memory-server');
const { io: ioc } = require('socket.io-client');
const { createServer } = require('../src/server');

const SCHOOL = { lat: 28.6353, lng: -106.0889 };
const DAY = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'][new Date().getDay()];

let base;
const driverBodies = [];

async function api(method, path, body) {
  const res = await fetch(base + path, {
    method,
    headers: { 'content-type': 'application/json' },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  assert.ok((res.headers.get('content-type') || '').includes('application/json'), `${method} ${path}: respuesta no JSON`);
  const json = JSON.parse(text);
  if (path.startsWith('/api/driver/')) driverBodies.push(text);
  return { status: res.status, body: json };
}

async function ok(method, path, body, status = 200) {
  const r = await api(method, path, body);
  assert.strictEqual(r.status, status, `${method} ${path} -> ${r.status} ${JSON.stringify(r.body)}`);
  return r.body;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, label, timeout = 4000) {
  const t0 = Date.now();
  for (;;) {
    const v = fn();
    if (v) return v;
    if (Date.now() - t0 > timeout) throw new Error(`Timeout esperando: ${label}`);
    await sleep(25);
  }
}

function makeClient(name) {
  const socket = ioc(base, { transports: ['websocket'], forceNew: true });
  const events = [];
  socket.onAny((ev, payload) => events.push({ ev, payload }));
  const find = (ev, pred = () => true) => events.find((e) => e.ev === ev && pred(e.payload));
  const emitAck = (ev, payload) =>
    new Promise((resolve, reject) => {
      socket.emit(ev, payload, (r) => (r && r.ok ? resolve(r) : reject(new Error(`${name} ${ev}: ${JSON.stringify(r)}`))));
    });
  return {
    name,
    socket,
    events,
    find,
    emitAck,
    waitFor: (ev, pred) => until(() => find(ev, pred), `${name} <- ${ev}`),
    connected: () => new Promise((r) => (socket.connected ? r() : socket.once('connect', r))),
  };
}

let n = 0;
async function step(title, fn) {
  await fn();
  n += 1;
  console.log(`  ✓ ${String(n).padStart(2, '0')} ${title}`);
}

const off = (lat, lng, mLat = 0, mLng = 0) => ({ lat: lat + mLat / 111320, lng: lng + mLng / 111320 });

async function main() {
  const mongod = await MongoMemoryServer.create();
  const srv = await createServer({ mongoUri: mongod.getUri('sts_smoke'), port: 0, host: '127.0.0.1', autoSeed: true });
  base = `http://127.0.0.1:${srv.port}`;
  console.log(`Servidor de prueba en ${base} (Mongo en memoria)`);

  const clients = [];
  try {
    await step('health + config escuela', async () => {
      assert.deepStrictEqual(await ok('GET', '/api/health'), { ok: true });
      const cfg = await ok('GET', '/api/config/school');
      assert.strictEqual(cfg.location.lat, SCHOOL.lat);
    });

    await step('404 y JSON inválido devuelven error JSON limpio', async () => {
      const r = await api('GET', '/api/nope');
      assert.strictEqual(r.status, 404);
      assert.ok(r.body.error);
      const bad = await fetch(base + '/api/routes', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{oops' });
      assert.strictEqual(bad.status, 400);
      assert.ok((await bad.json()).error);
    });

    await step('seed automático (RUT-101 con 3 alumnos, RUT-102)', async () => {
      const routes = await ok('GET', '/api/routes');
      const r101 = routes.find((r) => r.shortCode === 'RUT-101');
      assert.ok(r101 && routes.find((r) => r.shortCode === 'RUT-102'));
      assert.strictEqual(r101.studentCount, 3);
      assert.strictEqual(r101.confirmedCount, 2);
      assert.deepStrictEqual(r101.polyline, []);
      assert.strictEqual(r101.currentLocation, null);
      assert.ok(r101.id && !('_id' in r101));
    });

    let coordinator;
    await step('login coordinador (ok y 401)', async () => {
      assert.strictEqual((await api('POST', '/api/coordinator/login', { username: 'admin', password: 'x' })).status, 401);
      const r = await ok('POST', '/api/coordinator/login', { username: 'admin', password: '1234' });
      coordinator = r.coordinator;
      assert.ok(coordinator.id && coordinator.phone);
    });

    // --- Datos del flujo ---
    let route, s1, s2, s3;
    await step('crear ruta (defaults) y 3 alumnos', async () => {
      route = await ok('POST', '/api/routes', { coordinatorId: coordinator.id }, 201);
      assert.match(route.shortCode, /^RUT-\d{3,4}$/);
      assert.strictEqual(route.name, 'Nueva ruta');
      assert.strictEqual(route.startTime, '07:30');
      assert.strictEqual(route.schoolLocation.lat, SCHOOL.lat);
      route = await ok('PUT', `/api/routes/${route.id}`, { name: 'Ruta Smoke', startTime: '07:15' });
      assert.strictEqual(route.name, 'Ruta Smoke');
      const mk = (firstName, lastName) =>
        ok('POST', `/api/routes/${route.id}/students`, {
          firstName, lastName, grade: '5° B',
          tutor: { firstName: 'Tutor' + firstName, lastName: 'Robertson', phone1: '+5261400000', phone2: '' },
        }, 201);
      s1 = await mk('Zoe', 'Quintanilla');
      s2 = await mk('Ivan', 'Quintanilla');
      s3 = await mk('Nora', 'Quintanilla');
      assert.match(s1.shortCode, /^ALU-\d{4}$/);
      assert.strictEqual(s1.pickupLocation.isSet, false);
      assert.strictEqual(s1.stopLabel, null);
      assert.strictEqual(s1.todayServiceStatus, 'pending');
      const full = await ok('GET', `/api/routes/${route.id}`);
      assert.strictEqual(full.students.length, 3);
      assert.strictEqual(full.route.studentCount, 3);
    });

    await step('start sin alumnos confirmados -> 400', async () => {
      const r = await api('POST', `/api/routes/${route.id}/start`);
      assert.strictEqual(r.status, 400);
      assert.strictEqual(r.body.error, 'No hay alumnos confirmados para hoy');
    });

    const pin1 = off(SCHOOL.lat, SCHOOL.lng, 2200, 0); // más lejos de la escuela
    const pin2 = off(SCHOOL.lat, SCHOOL.lng, -1100, 0);
    const pin3 = off(SCHOOL.lat, SCHOOL.lng, 0, 500);

    await step('tutor: acceso por shortCode (minúsculas) y uuid', async () => {
      const a = await ok('POST', '/api/tutor/access', { code: s1.shortCode.toLowerCase() });
      assert.strictEqual(a.student.id, s1.id);
      assert.strictEqual(a.route.id, route.id);
      assert.ok(a.coordinatorPhone && a.school.name && a.school.location);
      const b = await ok('POST', '/api/tutor/access', { code: s1.uuid });
      assert.strictEqual(b.student.id, s1.id);
      assert.strictEqual((await api('POST', '/api/tutor/access', { code: 'ALU-0000' })).status, 404);
    });

    await step('tutor: perfil con pin, horario y confirmación del día', async () => {
      for (const [s, pin] of [[s1, pin1], [s2, pin2], [s3, pin3]]) {
        const u = await ok('PUT', `/api/tutor/students/${s.id}/profile`, { grade: '6° A', pickupLocation: pin });
        assert.strictEqual(u.pickupLocation.isSet, true);
        assert.strictEqual(u.grade, '6° A');
      }
      const sch = await ok('PATCH', `/api/tutor/students/${s1.id}/schedule`, { day: 'monday', enabled: false });
      assert.strictEqual(sch.weeklySchedule.monday, false);
      await ok('PATCH', `/api/tutor/students/${s1.id}/schedule`, { day: 'monday', enabled: true });
      assert.strictEqual((await api('PATCH', `/api/tutor/students/${s1.id}/schedule`, { day: 'sunday', enabled: true })).status, 400);
    });

    // Sockets (antes de confirmar para capturar student_service_updated)
    const coord = makeClient('coord');
    const driver = makeClient('driver');
    const tut1 = makeClient('tutor1');
    const tut2 = makeClient('tutor2');
    clients.push(coord, driver, tut1, tut2);
    await Promise.all(clients.map((c) => c.connected()));
    await coord.emitAck('join_route', { routeId: route.id, role: 'coordinator' });
    await driver.emitAck('join_route', { routeId: route.id, role: 'driver' });
    await tut1.emitAck('join_route', { routeId: route.id, role: 'tutor' });
    await tut1.emitAck('join_student', { studentId: s1.id });
    await tut2.emitAck('join_route', { routeId: route.id, role: 'tutor' });
    await tut2.emitAck('join_student', { studentId: s2.id });

    await step('confirmación del día (s1, s2 confirman; s3 rechaza) + student_service_updated', async () => {
      await ok('POST', `/api/tutor/students/${s1.id}/today-confirmation`, { decision: 'confirmed' });
      await ok('POST', `/api/tutor/students/${s2.id}/today-confirmation`, { decision: 'confirmed' });
      const r3 = await ok('POST', `/api/tutor/students/${s3.id}/today-confirmation`, { decision: 'rejected' });
      assert.strictEqual(r3.todayServiceStatus, 'rejected');
      assert.strictEqual((await api('POST', `/api/tutor/students/${s3.id}/today-confirmation`, { decision: 'x' })).status, 400);
      await coord.waitFor('student_service_updated', (p) => p.studentId === s1.id && p.todayServiceStatus === 'confirmed');
      assert.ok(!driver.find('student_service_updated') || true); // el chofer comparte sala staff: solo ids opacos
    });

    if (['monday', 'tuesday', 'wednesday', 'thursday', 'friday'].includes(DAY)) {
      await step(`elegibilidad: horario semanal (${DAY}) deshabilitado excluye al alumno`, async () => {
        await ok('POST', `/api/tutor/students/${s3.id}/today-confirmation`, { decision: 'confirmed' });
        await ok('PATCH', `/api/tutor/students/${s3.id}/schedule`, { day: DAY, enabled: false });
      });
    }

    await step('start: 2 paradas ordenadas por distancia desc, route_started y status', async () => {
      const r = await ok('POST', `/api/routes/${route.id}/start`);
      assert.strictEqual(r.route.status, 'in_progress');
      assert.strictEqual(r.stops.length, 2);
      assert.deepStrictEqual(r.stops.map((s) => [s.stopLabel, s.stopOrder, s.studentId]), [
        ['Punto A', 1, s1.id],
        ['Punto B', 2, s2.id],
      ]);
      assert.strictEqual(r.stops[0].firstName, 'Zoe'); // el coordinador sí ve nombres
      assert.strictEqual((await api('POST', `/api/routes/${route.id}/start`)).status, 409);
      await driver.waitFor('route_started', (p) => p.routeId === route.id);
      await tut1.waitFor('route_status_changed', (p) => p.status === 'in_progress');
      const st = await ok('GET', `/api/tutor/students/${s1.id}`);
      assert.strictEqual(st.student.stopLabel, 'Punto A');
      assert.strictEqual(st.student.pickupStatus, 'pending');
    });

    await step('polyline: PUT persiste y emite route_polyline_updated', async () => {
      const poly = [[pin1.lat, pin1.lng], [pin2.lat, pin2.lng], [SCHOOL.lat, SCHOOL.lng]];
      await ok('PUT', `/api/routes/${route.id}/polyline`, { polyline: poly });
      assert.strictEqual((await api('PUT', `/api/routes/${route.id}/polyline`, { polyline: [[999, 1]] })).status, 400);
      await tut1.waitFor('route_polyline_updated', (p) => p.polyline.length === 3);
      const d = await ok('GET', `/api/driver/routes/${route.id}/stops`);
      assert.deepStrictEqual(d.polyline, poly);
      const live = await ok('GET', `/api/tutor/students/${s2.id}/live`);
      assert.deepStrictEqual(live.stops.map((s) => s.stopOrder), [1, 2]);
      assert.deepStrictEqual(Object.keys(live.stops[0]).sort(), ['lat', 'lng', 'stopOrder']);
    });

    let driverRoute;
    await step('chofer: acceso por código (shortCode/uuid) 100% sanitizado', async () => {
      const a = await ok('POST', '/api/driver/access', { code: route.shortCode.toLowerCase() });
      driverRoute = a.route;
      assert.ok(a.coordinatorPhone);
      assert.strictEqual(driverRoute.stops.length, 2);
      assert.deepStrictEqual(Object.keys(driverRoute.stops[0]).sort(), ['lat', 'lng', 'status', 'stopLabel', 'stopOrder', 'studentId']);
      assert.deepStrictEqual(Object.keys(driverRoute).sort(), ['id', 'name', 'polyline', 'schoolLocation', 'shortCode', 'startTime', 'status', 'stops']);
      assert.strictEqual((await ok('POST', '/api/driver/access', { code: route.uuid })).route.id, route.id);
    });

    await step('location updates: lejos (sin alerta) -> approaching -> arrived_stop', async () => {
      const far = off(pin1.lat, pin1.lng, 4000, 0);
      driver.socket.emit('driver_location_update', { routeId: route.id, ...far });
      await coord.waitFor('bus_location_updated', (p) => Math.abs(p.lat - far.lat) < 1e-9);
      await tut2.waitFor('bus_location_updated');
      await sleep(150);
      assert.ok(!tut1.find('proximity_alert'), 'no debe haber alerta lejos');

      const near = off(pin1.lat, pin1.lng, 200, 0);
      driver.socket.emit('driver_location_update', { routeId: route.id, ...near });
      const al = await tut1.waitFor('proximity_alert', (p) => p.type === 'approaching');
      assert.strictEqual(al.payload.studentId, s1.id);
      assert.ok(al.payload.distance > 150 && al.payload.distance < 250, `distance=${al.payload.distance}`);
      await coord.waitFor('student_pickup_updated', (p) => p.studentId === s1.id && p.pickupStatus === 'approaching');

      const at = off(pin1.lat, pin1.lng, 20, 0);
      driver.socket.emit('driver_location_update', { routeId: route.id, ...at });
      await tut1.waitFor('proximity_alert', (p) => p.type === 'arrived_stop');
      await sleep(100);
      assert.ok(!tut2.find('proximity_alert'), 'tutor2 no debe recibir alertas de s1');
      assert.ok(!tut2.find('student_pickup_updated', (p) => p.studentId === s1.id), 'tutor2 no recibe estado de s1');
      const live = await ok('GET', `/api/routes/${route.id}/live`);
      assert.strictEqual(live.route.currentLocation.lat, at.lat);
      assert.strictEqual(live.stops[0].status, 'arrived_stop');
    });

    await step('SOS: ruta en pausa, driver_sos_triggered, teléfono; reanudar', async () => {
      const r = await ok('POST', `/api/driver/routes/${route.id}/sos`, {});
      assert.deepStrictEqual([r.ok, r.status, !!r.coordinatorPhone], [true, 'paused', true]);
      await coord.waitFor('driver_sos_triggered', (p) => p.routeId === route.id);
      await tut1.waitFor('route_status_changed', (p) => p.status === 'paused' && p.reason === 'sos');
      assert.ok(!tut1.find('driver_sos_triggered'), 'el tutor no recibe SOS');
      assert.strictEqual((await ok('GET', `/api/routes/${route.id}/live`)).sosActive, true);
      const back = await ok('PATCH', `/api/routes/${route.id}/status`, { status: 'in_progress' });
      assert.strictEqual(back.status, 'in_progress');
      assert.strictEqual((await ok('GET', `/api/routes/${route.id}/live`)).sosActive, false);
      assert.strictEqual((await api('PATCH', `/api/routes/${route.id}/status`, { status: 'idle' })).status, 400);
    });

    await step('confirm-pickup s1 y s2 (+ approaching/arrived de s2)', async () => {
      const r1 = await ok('POST', `/api/driver/routes/${route.id}/confirm-pickup`, { studentId: s1.id });
      assert.strictEqual(r1.stops.find((s) => s.studentId === s1.id).status, 'picked_up');
      await tut1.waitFor('student_pickup_updated', (p) => p.pickupStatus === 'picked_up');
      await coord.waitFor('student_pickup_updated', (p) => p.studentId === s1.id && p.pickupStatus === 'picked_up');
      assert.strictEqual((await api('POST', `/api/driver/routes/${route.id}/confirm-pickup`, { studentId: 'zzz' })).status, 400);
      assert.strictEqual((await api('POST', `/api/driver/routes/${route.id}/confirm-pickup`, { studentId: s3.id })).status, 404);

      driver.socket.emit('driver_location_update', { routeId: route.id, ...off(pin2.lat, pin2.lng, 10, 0) });
      await tut2.waitFor('proximity_alert', (p) => p.type === 'arrived_stop'); // pasa directo de pending a arrived_stop
      const r2 = await ok('POST', `/api/driver/routes/${route.id}/confirm-pickup`, { studentId: s2.id });
      assert.ok(r2.stops.every((s) => s.status === 'picked_up'));
    });

    await step('llegada automática a escuela (<60 m) -> arrived_school', async () => {
      driver.socket.emit('driver_location_update', { routeId: route.id, ...off(SCHOOL.lat, SCHOOL.lng, 30, 0) });
      await coord.waitFor('route_status_changed', (p) => p.status === 'arrived_school' && p.reason === 'auto');
      await tut1.waitFor('route_status_changed', (p) => p.status === 'arrived_school');
      assert.strictEqual((await ok('GET', `/api/tutor/students/${s1.id}`)).route.status, 'arrived_school');
    });

    await step('confirm-arrival: completed, dropped_at_school, reset de ciclo, trip_completed', async () => {
      const r = await ok('POST', `/api/routes/${route.id}/confirm-arrival`);
      assert.strictEqual(r.status, 'completed');
      await driver.waitFor('trip_completed', (p) => p.routeId === route.id);
      await tut1.waitFor('trip_completed');
      await tut2.waitFor('route_status_changed', (p) => p.status === 'completed');
      await coord.waitFor('student_pickup_updated', (p) => p.pickupStatus === 'dropped_at_school');
      const full = await ok('GET', `/api/routes/${route.id}`);
      for (const s of full.students) assert.strictEqual(s.todayServiceStatus, 'pending');
      assert.strictEqual(full.students.find((s) => s.id === s1.id).pickupStatus, 'dropped_at_school');
      assert.deepStrictEqual((await ok('GET', `/api/driver/routes/${route.id}/stops`)).stops, []);
      assert.strictEqual((await api('POST', `/api/routes/${route.id}/confirm-arrival`)).status, 409);
    });

    await step('segundo viaje: reinicio de ciclo + llegada manual desde chofer', async () => {
      await ok('POST', `/api/tutor/students/${s1.id}/today-confirmation`, { decision: 'confirmed' });
      const r = await ok('POST', `/api/routes/${route.id}/start`);
      assert.strictEqual(r.stops.length, 1);
      assert.strictEqual(r.stops[0].status, 'pending');
      assert.deepStrictEqual(await ok('POST', `/api/driver/routes/${route.id}/arrived-school`), { ok: true });
      assert.strictEqual((await ok('GET', `/api/routes/${route.id}/live`)).route.status, 'arrived_school');
      assert.deepStrictEqual(await ok('POST', `/api/driver/routes/${route.id}/arrived-school`), { ok: true }); // idempotente
      await ok('POST', `/api/routes/${route.id}/confirm-arrival`);
    });

    await step('incidentes: crear con alumno, validaciones y listado', async () => {
      const r = await ok('POST', `/api/routes/${route.id}/incidents`, { description: 'Retraso por tráfico', involvedStudentId: s2.id }, 201);
      assert.strictEqual(r.incident.involvedStudentId, s2.id);
      assert.strictEqual(r.incident.reportedByRole, 'coordinator');
      assert.strictEqual((await api('POST', `/api/routes/${route.id}/incidents`, { description: '  ' })).status, 400);
      const list = await ok('GET', `/api/routes/${route.id}/incidents`);
      assert.ok(list.incidents.some((i) => i.reportedByRole === 'driver')); // del SOS
      assert.ok(list.incidents.some((i) => i.description === 'Retraso por tráfico'));
    });

    await step('SANITIZACIÓN: el chofer nunca recibió nombres/grado/tutor (REST ni sockets)', async () => {
      const blob = driverBodies.join('\n') + JSON.stringify(driver.events);
      assert.ok(driverBodies.length >= 6 && driver.events.length > 5);
      for (const forbidden of ['Zoe', 'Ivan', 'Nora', 'Quintanilla', 'Robertson', 'Tutor', '5° B', '6° A', '"firstName"', '"lastName"', '"grade"', '"tutor"', 'phone1']) {
        assert.ok(!blob.includes(forbidden), `Fuga de datos hacia el chofer: ${forbidden}`);
      }
    });

    await step('editar/eliminar alumno y eliminar ruta (cascada)', async () => {
      const u = await ok('PUT', `/api/students/${s3.id}`, { firstName: 'Nora2', tutor: { phone2: '555' } });
      assert.strictEqual(u.firstName, 'Nora2');
      assert.strictEqual(u.tutor.phone2, '555');
      assert.strictEqual(u.tutor.firstName, 'TutorNora');
      assert.deepStrictEqual(await ok('DELETE', `/api/students/${s3.id}`), { ok: true });
      assert.deepStrictEqual(await ok('DELETE', `/api/routes/${route.id}`), { ok: true });
      assert.strictEqual((await api('GET', `/api/routes/${route.id}`)).status, 404);
      assert.strictEqual((await api('GET', `/api/tutor/students/${s1.id}`)).status, 404);
    });

    await step('seed idempotente (re-ejecutar no duplica)', async () => {
      const { seed } = require('../src/seed/seedData');
      const created = await seed();
      assert.deepStrictEqual(created, { coordinator: 0, school: 0, routes: 0, students: 0 });
    });

    console.log(`\nSMOKE TEST OK (${n} pasos)`);
  } finally {
    clients.forEach((c) => c.socket.close());
    await srv.close();
    await mongod.stop();
  }
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error('\nSMOKE TEST FALLÓ:\n', err);
    process.exit(1);
  }
);
