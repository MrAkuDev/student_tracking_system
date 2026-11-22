const { Route, Student, Coordinator } = require('../models');
const { HttpError, asyncHandler, isOid } = require('../utils/errors');
const { routeJSON, studentJSON, driverRouteJSON, driverStopJSON } = require('../utils/serialize');
const svc = require('../services/routeService');
const emit = require('../sockets/emitters');
const { IncidentReport } = require('../models');
const { applyStudentPatch } = require('./coordinatorController');

const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const ciExact = (code) => new RegExp(`^${escapeRe(code)}$`, 'i');

// ---------- Auth / acceso ----------

const coordinatorLogin = asyncHandler(async (req, res) => {
  const { username, password } = req.body || {};
  if (typeof username !== 'string' || typeof password !== 'string' || !username || !password) {
    throw new HttpError(400, 'Usuario y contraseña son obligatorios');
  }
  const c = await Coordinator.findOne({ username: username.trim() });
  if (!c || c.password !== password) {
    throw new HttpError(401, 'Usuario o contraseña incorrectos');
  }
  res.json({
    coordinator: { id: String(c._id), username: c.username, name: c.name, phone: c.phone },
  });
});

function readCode(req) {
  const code = req.body && req.body.code;
  if (typeof code !== 'string' || !code.trim()) throw new HttpError(400, 'El código es obligatorio');
  return code.trim();
}

const tutorAccess = asyncHandler(async (req, res) => {
  const code = readCode(req);
  const student = await Student.findOne({ $or: [{ shortCode: ciExact(code) }, { uuid: code }] });
  if (!student) throw new HttpError(404, 'Código no válido');
  const route = await svc.findRoute(String(student.routeId));
  const school = await svc.getSchool();
  res.json({
    student: studentJSON(student),
    route: routeJSON(route),
    coordinatorPhone: await svc.getCoordinatorPhone(route),
    school,
  });
});

const driverAccess = asyncHandler(async (req, res) => {
  const code = readCode(req);
  const route = await Route.findOne({ $or: [{ shortCode: ciExact(code) }, { uuid: code }] });
  if (!route) throw new HttpError(404, 'Código de ruta no válido');
  const stops = await svc.getVisibleStops(route);
  res.json({
    route: driverRouteJSON(route, stops),
    coordinatorPhone: await svc.getCoordinatorPhone(route),
  });
});

// ---------- Tutor ----------

const tutorGetStudent = asyncHandler(async (req, res) => {
  const student = await svc.findStudent(req.params.id);
  const route = await svc.findRoute(String(student.routeId));
  res.json({ student: studentJSON(student), route: routeJSON(route) });
});

const tutorUpdateProfile = asyncHandler(async (req, res) => {
  const student = await svc.findStudent(req.params.id);
  applyStudentPatch(student, req.body);
  await student.save();
  res.json(studentJSON(student));
});

const DAY_KEYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

const tutorSchedule = asyncHandler(async (req, res) => {
  const student = await svc.findStudent(req.params.id);
  const { day, enabled } = req.body || {};
  if (!DAY_KEYS.includes(day)) throw new HttpError(400, 'day debe ser monday..friday');
  if (typeof enabled !== 'boolean') throw new HttpError(400, 'enabled debe ser booleano');
  student.weeklySchedule[day] = enabled;
  await student.save();
  res.json(studentJSON(student));
});

const tutorTodayConfirmation = asyncHandler(async (req, res) => {
  const student = await svc.findStudent(req.params.id);
  const decision = req.body && req.body.decision;
  if (!['confirmed', 'rejected'].includes(decision)) {
    throw new HttpError(400, 'decision debe ser confirmed o rejected');
  }
  student.todayServiceStatus = decision;
  await student.save();
  emit.emitToStaff(student.routeId, 'student_service_updated', {
    routeId: String(student.routeId),
    studentId: String(student._id),
    todayServiceStatus: decision,
  });
  res.json(studentJSON(student));
});

const tutorLive = asyncHandler(async (req, res) => {
  const student = await svc.findStudent(req.params.id);
  const route = await svc.findRoute(String(student.routeId));
  const stops = await svc.getVisibleStops(route);
  res.json({
    route: routeJSON(route),
    student: studentJSON(student),
    stops: stops.map((s) => ({
      lat: s.pickupLocation.lat,
      lng: s.pickupLocation.lng,
      stopOrder: s.stopOrder,
    })),
  });
});

// ---------- Chofer (sanitizado) ----------

const driverStops = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.routeId);
  const stops = await svc.getVisibleStops(route);
  res.json(driverRouteJSON(route, stops));
});

const driverConfirmPickup = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.routeId);
  const studentId = req.body && req.body.studentId;
  if (!isOid(studentId)) throw new HttpError(400, 'studentId inválido');
  if (!svc.RUNNING.includes(route.status) && route.status !== 'arrived_school') {
    throw new HttpError(409, 'La ruta no está en curso');
  }
  const student = await Student.findOne({ _id: studentId, routeId: route._id });
  if (!student || student.stopOrder === null || student.stopOrder === undefined) {
    throw new HttpError(404, 'Parada no encontrada');
  }
  if (student.pickupStatus === 'dropped_at_school') {
    throw new HttpError(409, 'La parada ya fue completada');
  }
  if (student.pickupStatus !== 'picked_up') {
    student.pickupStatus = 'picked_up';
    await student.save();
    emit.emitPickupUpdated(route._id, student);
  }
  const stops = await svc.getStops(route._id);
  res.json({ ok: true, stops: stops.map(driverStopJSON) });
});

const driverSos = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.routeId);
  if (!svc.RUNNING.includes(route.status)) throw new HttpError(409, 'La ruta no está en curso');
  route.status = 'paused';
  route.sosActive = true;
  await route.save();
  await IncidentReport.create({
    routeId: route._id,
    reportedByRole: 'driver',
    description: 'SOS: el chofer reportó un problema durante la ruta',
  });
  const at = new Date().toISOString();
  emit.emitToStaff(route._id, 'driver_sos_triggered', { routeId: String(route._id), at });
  await emit.emitRouteStatus(route._id, 'paused', 'sos');
  res.json({ ok: true, status: 'paused', coordinatorPhone: await svc.getCoordinatorPhone(route) });
});

const driverArrivedSchool = asyncHandler(async (req, res) => {
  await svc.setArrivedSchool(req.params.routeId, 'manual');
  res.json({ ok: true });
});

// ---------- Utilidad ----------

const health = (req, res) => res.json({ ok: true });
const schoolConfig = asyncHandler(async (req, res) => res.json(await svc.getSchool()));

module.exports = {
  coordinatorLogin,
  tutorAccess,
  driverAccess,
  tutorGetStudent,
  tutorUpdateProfile,
  tutorSchedule,
  tutorTodayConfirmation,
  tutorLive,
  driverStops,
  driverConfirmPickup,
  driverSos,
  driverArrivedSchool,
  health,
  schoolConfig,
};
