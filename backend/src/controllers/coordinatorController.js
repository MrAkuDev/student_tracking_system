const { Route, Student, Coordinator, IncidentReport } = require('../models');
const { HttpError, asyncHandler, isOid } = require('../utils/errors');
const { isLat, isLng } = require('../utils/geo');
const { newRouteCode, newStudentCode } = require('../utils/codes');
const {
  routeJSON,
  studentJSON,
  coordinatorStopJSON,
  incidentJSON,
} = require('../utils/serialize');
const svc = require('../services/routeService');
const emit = require('../sockets/emitters');

const str = (v) => (typeof v === 'string' ? v.trim() : undefined);

function parseSchoolLocation(input, base) {
  if (input === undefined || input === null) return base;
  if (typeof input !== 'object') throw new HttpError(400, 'schoolLocation inválida');
  const lat = input.lat !== undefined ? input.lat : base.lat;
  const lng = input.lng !== undefined ? input.lng : base.lng;
  if (!isLat(lat) || !isLng(lng)) throw new HttpError(400, 'Coordenadas de la escuela inválidas');
  const address = input.address !== undefined ? String(input.address) : base.address || '';
  return { lat, lng, address };
}

async function countsByRoute(routeIds) {
  const rows = await Student.aggregate([
    { $match: { routeId: { $in: routeIds } } },
    {
      $group: {
        _id: '$routeId',
        studentCount: { $sum: 1 },
        confirmedCount: { $sum: { $cond: [{ $eq: ['$todayServiceStatus', 'confirmed'] }, 1, 0] } },
      },
    },
  ]);
  const map = new Map();
  rows.forEach((r) => map.set(String(r._id), r));
  return map;
}

const listRoutes = asyncHandler(async (req, res) => {
  const filter = {};
  if (req.query.coordinatorId) {
    if (!isOid(req.query.coordinatorId)) throw new HttpError(400, 'coordinatorId inválido');
    filter.coordinatorId = req.query.coordinatorId;
  }
  const routes = await Route.find(filter).sort({ shortCode: 1 });
  const counts = await countsByRoute(routes.map((r) => r._id));
  res.json(routes.map((r) => routeJSON(r, counts.get(String(r._id)) || {})));
});

const createRoute = asyncHandler(async (req, res) => {
  const body = req.body || {};
  const school = await svc.getSchool();
  const base = { lat: school.location.lat, lng: school.location.lng, address: school.address };
  const schoolLocation = parseSchoolLocation(body.schoolLocation, base);
  let coordinatorId = null;
  if (body.coordinatorId !== undefined && body.coordinatorId !== null) {
    if (!isOid(body.coordinatorId)) throw new HttpError(400, 'coordinatorId inválido');
    coordinatorId = body.coordinatorId;
  } else {
    const c = await Coordinator.findOne().sort({ _id: 1 }).lean();
    coordinatorId = c ? c._id : null;
  }
  const route = await Route.create({
    uuid: svc.uuidv4(),
    shortCode: await newRouteCode(),
    name: str(body.name) || 'Nueva ruta',
    startTime: str(body.startTime) || '07:30',
    schoolLocation,
    coordinatorId,
  });
  res.status(201).json(routeJSON(route, { studentCount: 0, confirmedCount: 0 }));
});

const getRoute = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const students = await Student.find({ routeId: route._id }).sort({ lastName: 1, firstName: 1 });
  res.json({
    route: routeJSON(route, {
      studentCount: students.length,
      confirmedCount: students.filter((s) => s.todayServiceStatus === 'confirmed').length,
    }),
    students: students.map(studentJSON),
  });
});

const updateRoute = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const body = req.body || {};
  if (body.name !== undefined) {
    if (!str(body.name)) throw new HttpError(400, 'El nombre de la ruta no puede estar vacío');
    route.name = str(body.name);
  }
  if (body.startTime !== undefined) {
    if (!/^\d{1,2}:\d{2}$/.test(String(body.startTime))) {
      throw new HttpError(400, 'startTime debe tener formato HH:mm');
    }
    route.startTime = String(body.startTime);
  }
  if (body.schoolLocation !== undefined) {
    route.schoolLocation = parseSchoolLocation(body.schoolLocation, route.schoolLocation);
  }
  await route.save();
  res.json(routeJSON(route));
});

const deleteRoute = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  await Student.deleteMany({ routeId: route._id });
  await IncidentReport.deleteMany({ routeId: route._id });
  await route.deleteOne();
  res.json({ ok: true });
});

const startRoute = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const stops = await svc.startRoute(route);
  res.json({ route: routeJSON(route), stops: stops.map(coordinatorStopJSON) });
});

const setPolyline = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const raw = req.body && req.body.polyline;
  if (!Array.isArray(raw)) throw new HttpError(400, 'polyline debe ser un arreglo [[lat,lng],...]');
  const polyline = [];
  for (const p of raw) {
    if (!Array.isArray(p) || p.length < 2 || !isLat(p[0]) || !isLng(p[1])) {
      throw new HttpError(400, 'polyline contiene puntos inválidos (se espera [lat,lng])');
    }
    polyline.push([p[0], p[1]]);
  }
  route.polyline = polyline;
  await route.save();
  emit.emitToRoute(route._id, 'route_polyline_updated', {
    routeId: String(route._id),
    polyline,
  });
  res.json({ ok: true });
});

const patchStatus = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const status = req.body && req.body.status;
  if (!['in_progress', 'paused', 'breakdown'].includes(status)) {
    throw new HttpError(400, 'status debe ser in_progress, paused o breakdown');
  }
  if (!svc.RUNNING.includes(route.status)) throw new HttpError(409, 'La ruta no está en curso');
  route.status = status;
  if (status === 'in_progress') route.sosActive = false;
  await route.save();
  await emit.emitRouteStatus(route._id, status, 'manual');
  res.json(routeJSON(route));
});

const arrivedSchool = asyncHandler(async (req, res) => {
  const route = await svc.setArrivedSchool(req.params.id, 'manual');
  res.json(routeJSON(route));
});

const confirmArrival = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  await svc.confirmArrival(route);
  res.json(routeJSON(route));
});

const createIncident = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const body = req.body || {};
  const description = str(body.description);
  if (!description) throw new HttpError(400, 'La descripción del problema es obligatoria');
  let involvedStudentId = null;
  if (body.involvedStudentId) {
    if (!isOid(body.involvedStudentId)) throw new HttpError(400, 'involvedStudentId inválido');
    const st = await Student.findOne({ _id: body.involvedStudentId, routeId: route._id }).lean();
    if (!st) throw new HttpError(400, 'El alumno indicado no pertenece a la ruta');
    involvedStudentId = st._id;
  }
  const reportedByRole = body.reportedByRole === 'driver' ? 'driver' : 'coordinator';
  const incident = await IncidentReport.create({
    routeId: route._id,
    reportedByRole,
    description,
    involvedStudentId,
  });
  res.status(201).json({ incident: incidentJSON(incident) });
});

const listIncidents = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const items = await IncidentReport.find({ routeId: route._id }).sort({ createdAt: -1 });
  res.json({ incidents: items.map(incidentJSON) });
});

const liveRoute = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const stops = await svc.getVisibleStops(route);
  res.json({
    route: routeJSON(route),
    stops: stops.map(coordinatorStopJSON),
    sosActive: !!route.sosActive,
  });
});

// ---- Alumnos ----

function applyStudentPatch(student, body) {
  const b = body || {};
  for (const k of ['firstName', 'lastName']) {
    if (b[k] !== undefined) {
      if (!str(b[k])) throw new HttpError(400, `${k} no puede estar vacío`);
      student[k] = str(b[k]);
    }
  }
  if (b.grade !== undefined) student.grade = str(b.grade) || '';
  if (b.tutor !== undefined) {
    if (!b.tutor || typeof b.tutor !== 'object') throw new HttpError(400, 'tutor inválido');
    for (const k of ['firstName', 'lastName', 'phone1', 'phone2']) {
      if (b.tutor[k] !== undefined) student.tutor[k] = String(b.tutor[k]).trim();
    }
  }
  if (b.pickupLocation !== undefined && b.pickupLocation !== null) {
    const { lat, lng } = b.pickupLocation;
    if (!isLat(lat) || !isLng(lng)) throw new HttpError(400, 'pickupLocation inválida');
    student.pickupLocation = { lat, lng, isSet: true };
  }
}

const createStudent = asyncHandler(async (req, res) => {
  const route = await svc.findRoute(req.params.id);
  const body = req.body || {};
  if (!str(body.firstName) || !str(body.lastName)) {
    throw new HttpError(400, 'Nombre y apellido del alumno son obligatorios');
  }
  const student = new Student({
    uuid: svc.uuidv4(),
    shortCode: await newStudentCode(),
    routeId: route._id,
    firstName: str(body.firstName),
    lastName: str(body.lastName),
    grade: str(body.grade) || '',
  });
  applyStudentPatch(student, { tutor: body.tutor, pickupLocation: body.pickupLocation });
  await student.save();
  res.status(201).json(studentJSON(student));
});

const updateStudent = asyncHandler(async (req, res) => {
  const student = await svc.findStudent(req.params.id);
  applyStudentPatch(student, req.body);
  await student.save();
  res.json(studentJSON(student));
});

const deleteStudent = asyncHandler(async (req, res) => {
  const student = await svc.findStudent(req.params.id);
  await IncidentReport.updateMany(
    { involvedStudentId: student._id },
    { $set: { involvedStudentId: null } }
  );
  await student.deleteOne();
  res.json({ ok: true });
});

module.exports = {
  applyStudentPatch,
  listRoutes,
  createRoute,
  getRoute,
  updateRoute,
  deleteRoute,
  startRoute,
  setPolyline,
  patchStatus,
  arrivedSchool,
  confirmArrival,
  createIncident,
  listIncidents,
  liveRoute,
  createStudent,
  updateStudent,
  deleteStudent,
};
