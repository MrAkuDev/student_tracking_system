const { Route, Student, Coordinator, SchoolConfig } = require('../models');
const { HttpError, isOid } = require('../utils/errors');
const { haversine } = require('../utils/geo');
const { v4: uuidv4 } = require('uuid');
const emit = require('../sockets/emitters');
const mongoose = require('mongoose');

const DAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
const WEEKDAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
const RUNNING = ['in_progress', 'paused', 'breakdown'];
const DEFAULT_SCHOOL = {
  name: 'Escuela Primaria STS',
  address: 'Chihuahua, Chihuahua, México',
  location: { lat: 28.6353, lng: -106.0889 },
};

async function getSchool() {
  const s = await SchoolConfig.findOne().lean();
  if (!s) return { ...DEFAULT_SCHOOL };
  return {
    name: s.name,
    address: s.address,
    location: { lat: s.location.lat, lng: s.location.lng },
  };
}

async function findRoute(id) {
  if (!isOid(id)) throw new HttpError(404, 'Ruta no encontrada');
  const route = await Route.findById(id);
  if (!route) throw new HttpError(404, 'Ruta no encontrada');
  return route;
}

async function findStudent(id) {
  if (!isOid(id)) throw new HttpError(404, 'Alumno no encontrado');
  const student = await Student.findById(id);
  if (!student) throw new HttpError(404, 'Alumno no encontrado');
  return student;
}

async function getCoordinatorPhone(route) {
  let c = null;
  if (route.coordinatorId) c = await Coordinator.findById(route.coordinatorId).lean();
  if (!c) c = await Coordinator.findOne().lean();
  return c ? c.phone : '';
}

function isEligibleToday(student, now = new Date()) {
  if (student.todayServiceStatus !== 'confirmed') return false;
  const key = DAYS[now.getDay()];
  if (WEEKDAYS.includes(key) && student.weeklySchedule && student.weeklySchedule[key] === false) {
    return false;
  }
  return true;
}

function hasPin(student) {
  const p = student.pickupLocation;
  return !!(p && p.isSet && Number.isFinite(p.lat) && Number.isFinite(p.lng));
}

function stopLabelFor(index) {
  // 0 -> A ... 25 -> Z, 26 -> AA
  let n = index;
  let s = '';
  do {
    s = String.fromCharCode(65 + (n % 26)) + s;
    n = Math.floor(n / 26) - 1;
  } while (n >= 0);
  return `Punto ${s}`;
}

async function getStops(routeId) {
  return Student.find({ routeId, stopOrder: { $ne: null } }).sort({ stopOrder: 1 });
}

/** Paradas visibles según estado de la ruta (vacías si no iniciada / completada). */
async function getVisibleStops(route) {
  if (route.status === 'idle' || route.status === 'completed') return [];
  return getStops(route._id);
}

async function startRoute(route) {
  if (RUNNING.includes(route.status)) throw new HttpError(409, 'La ruta ya está en curso');
  const students = await Student.find({ routeId: route._id });
  const eligible = students.filter((s) => isEligibleToday(s));
  if (!eligible.length) throw new HttpError(400, 'No hay alumnos confirmados para hoy');
  const stops = eligible.filter(hasPin);
  if (!stops.length) {
    throw new HttpError(400, 'Los alumnos confirmados aún no han fijado su punto de abordaje');
  }
  const { lat, lng } = route.schoolLocation;
  const dist = (s) => haversine(s.pickupLocation.lat, s.pickupLocation.lng, lat, lng);
  stops.sort((a, b) => dist(b) - dist(a) || String(a._id).localeCompare(String(b._id)));

  await Student.updateMany(
    { routeId: route._id },
    { $set: { pickupStatus: 'pending', stopLabel: null, stopOrder: null } }
  );
  await Student.bulkWrite(
    stops.map((s, i) => ({
      updateOne: {
        filter: { _id: s._id },
        update: { $set: { stopLabel: stopLabelFor(i), stopOrder: i + 1 } },
      },
    }))
  );

  route.status = 'in_progress';
  route.sosActive = false;
  route.activeTripId = new mongoose.Types.ObjectId();
  route.currentLocation = undefined;
  await route.save();

  await emit.emitRouteStatus(route._id, 'in_progress', 'manual');
  emit.emitToRoute(route._id, 'route_started', { routeId: String(route._id) });
  return getStops(route._id);
}

/** Marca arrived_school (idempotente). reason: 'manual' | 'auto'. */
async function setArrivedSchool(routeId, reason = 'manual') {
  const route = await findRoute(String(routeId));
  if (route.status === 'arrived_school') return route;
  if (!RUNNING.includes(route.status)) throw new HttpError(409, 'La ruta no está en curso');
  const updated = await Route.findOneAndUpdate(
    { _id: route._id, status: { $in: RUNNING } },
    { $set: { status: 'arrived_school', sosActive: false } },
    { new: true }
  );
  if (!updated) return findRoute(String(routeId));
  await emit.emitRouteStatus(route._id, 'arrived_school', reason);
  return updated;
}

async function confirmArrival(route) {
  if (route.status === 'idle' || route.status === 'completed') {
    throw new HttpError(409, 'La ruta no está en curso');
  }
  const picked = await Student.find({ routeId: route._id, pickupStatus: 'picked_up' });
  await Student.updateMany(
    { routeId: route._id, pickupStatus: 'picked_up' },
    { $set: { pickupStatus: 'dropped_at_school' } }
  );
  await Student.updateMany({ routeId: route._id }, { $set: { todayServiceStatus: 'pending' } });
  route.status = 'completed';
  route.sosActive = false;
  route.activeTripId = null;
  await route.save();

  for (const s of picked) {
    s.pickupStatus = 'dropped_at_school';
    emit.emitPickupUpdated(route._id, s);
  }
  await emit.emitRouteStatus(route._id, 'completed', 'manual');
  await emit.emitToRouteAndStudents(route._id, 'trip_completed', { routeId: String(route._id) });
  return route;
}

module.exports = {
  RUNNING,
  getSchool,
  findRoute,
  findStudent,
  getCoordinatorPhone,
  isEligibleToday,
  hasPin,
  getStops,
  getVisibleStops,
  startRoute,
  setArrivedSchool,
  confirmArrival,
  uuidv4,
};
