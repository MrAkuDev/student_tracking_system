const { Route, Student } = require('../models');
const { haversine } = require('../utils/geo');
const emit = require('../sockets/emitters');
const routeService = require('./routeService');

const APPROACHING_M = 300;
const ARRIVED_STOP_M = 50;
const ARRIVED_SCHOOL_M = 60;

/**
 * Persiste la ubicación del bus, la retransmite y evalúa proximidad
 * a las paradas (<300 m approaching, <50 m arrived_stop) y a la escuela (<60 m).
 */
async function processLocation(routeId, lat, lng) {
  const updatedAt = new Date();
  const route = await Route.findByIdAndUpdate(
    routeId,
    { $set: { currentLocation: { lat, lng, updatedAt } } },
    { new: true }
  );
  if (!route) return;

  emit.emitToRoute(routeId, 'bus_location_updated', {
    routeId: String(routeId),
    lat,
    lng,
    updatedAt: updatedAt.toISOString(),
  });

  if (route.status !== 'in_progress') return;

  const stops = await Student.find({ routeId, stopOrder: { $ne: null } });
  for (const s of stops) {
    if (!['pending', 'approaching'].includes(s.pickupStatus)) continue;
    if (!routeService.hasPin(s)) continue;
    const d = haversine(lat, lng, s.pickupLocation.lat, s.pickupLocation.lng);
    let next = null;
    if (d < ARRIVED_STOP_M) next = 'arrived_stop';
    else if (d < APPROACHING_M && s.pickupStatus === 'pending') next = 'approaching';
    if (!next || next === s.pickupStatus) continue;

    s.pickupStatus = next;
    await Student.updateOne({ _id: s._id }, { $set: { pickupStatus: next } });
    emit.emitPickupUpdated(routeId, s);
    emit.emitToStudent(s._id, 'proximity_alert', {
      routeId: String(routeId),
      studentId: String(s._id),
      type: next,
      distance: Math.round(d),
    });
  }

  const allPicked = stops.length > 0 && stops.every((s) => s.pickupStatus === 'picked_up');
  if (allPicked) {
    const d = haversine(lat, lng, route.schoolLocation.lat, route.schoolLocation.lng);
    if (d < ARRIVED_SCHOOL_M) await routeService.setArrivedSchool(routeId, 'auto');
  }
}

module.exports = { processLocation, APPROACHING_M, ARRIVED_STOP_M, ARRIVED_SCHOOL_M };
