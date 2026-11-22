const num = (v) => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const iso = (d) => (d ? new Date(d).toISOString() : null);

function routeJSON(route, counts) {
  const cl = route.currentLocation;
  const out = {
    id: String(route._id),
    uuid: route.uuid,
    shortCode: route.shortCode,
    name: route.name,
    startTime: route.startTime,
    schoolLocation: {
      lat: num(route.schoolLocation && route.schoolLocation.lat),
      lng: num(route.schoolLocation && route.schoolLocation.lng),
      address: (route.schoolLocation && route.schoolLocation.address) || '',
    },
    status: route.status,
    currentLocation:
      cl && num(cl.lat) !== null && num(cl.lng) !== null
        ? { lat: cl.lat, lng: cl.lng, updatedAt: iso(cl.updatedAt) }
        : null,
    polyline: (route.polyline || []).map((p) => [p[0], p[1]]),
    coordinatorId: route.coordinatorId ? String(route.coordinatorId) : null,
  };
  if (counts) {
    out.studentCount = counts.studentCount || 0;
    out.confirmedCount = counts.confirmedCount || 0;
  }
  return out;
}

function studentJSON(s) {
  const t = s.tutor || {};
  const p = s.pickupLocation || {};
  const w = s.weeklySchedule || {};
  return {
    id: String(s._id),
    uuid: s.uuid,
    shortCode: s.shortCode,
    routeId: String(s.routeId),
    firstName: s.firstName,
    lastName: s.lastName,
    grade: s.grade || '',
    tutor: {
      firstName: t.firstName || '',
      lastName: t.lastName || '',
      phone1: t.phone1 || '',
      phone2: t.phone2 || '',
    },
    pickupLocation: { lat: num(p.lat), lng: num(p.lng), isSet: !!p.isSet },
    weeklySchedule: {
      monday: w.monday !== false,
      tuesday: w.tuesday !== false,
      wednesday: w.wednesday !== false,
      thursday: w.thursday !== false,
      friday: w.friday !== false,
    },
    todayServiceStatus: s.todayServiceStatus,
    pickupStatus: s.pickupStatus,
    stopLabel: s.stopLabel || null,
    stopOrder: s.stopOrder === undefined ? null : s.stopOrder,
  };
}

/** Parada sanitizada para el chofer: SIN nombres/grado/tutor. */
function driverStopJSON(s) {
  return {
    studentId: String(s._id),
    stopLabel: s.stopLabel,
    stopOrder: s.stopOrder,
    lat: s.pickupLocation.lat,
    lng: s.pickupLocation.lng,
    status: s.pickupStatus,
  };
}

/** Parada para coordinador (incluye nombres). */
function coordinatorStopJSON(s) {
  return { ...driverStopJSON(s), firstName: s.firstName, lastName: s.lastName };
}

function driverRouteJSON(route, stops) {
  const r = routeJSON(route);
  return {
    id: r.id,
    shortCode: r.shortCode,
    name: r.name,
    startTime: r.startTime,
    status: r.status,
    schoolLocation: r.schoolLocation,
    polyline: r.polyline,
    stops: stops.map(driverStopJSON),
  };
}

function incidentJSON(i) {
  return {
    id: String(i._id),
    routeId: String(i.routeId),
    reportedByRole: i.reportedByRole,
    description: i.description,
    involvedStudentId: i.involvedStudentId ? String(i.involvedStudentId) : null,
    createdAt: iso(i.createdAt),
  };
}

module.exports = {
  routeJSON,
  studentJSON,
  driverStopJSON,
  coordinatorStopJSON,
  driverRouteJSON,
  incidentJSON,
};
