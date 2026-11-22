const { getIO } = require('./index');
const { Student } = require('../models');

const routeRoom = (id) => `route:${id}`;
const staffRoom = (id) => `route:${id}:staff`;
const studentRoom = (id) => `student:${id}`;

function emitToRoute(routeId, event, payload) {
  const io = getIO();
  if (io) io.to(routeRoom(routeId)).emit(event, payload);
}

function emitToStaff(routeId, event, payload) {
  const io = getIO();
  if (io) io.to(staffRoom(routeId)).emit(event, payload);
}

function emitToStudent(studentId, event, payload) {
  const io = getIO();
  if (io) io.to(studentRoom(studentId)).emit(event, payload);
}

/** Emite a la sala de la ruta y a todos los student:<id> de la ruta (un socket en varias salas lo recibe 1 vez). */
async function emitToRouteAndStudents(routeId, event, payload) {
  const io = getIO();
  if (!io) return;
  const students = await Student.find({ routeId }).select('_id').lean();
  let target = io.to(routeRoom(routeId));
  for (const s of students) target = target.to(studentRoom(s._id));
  target.emit(event, payload);
}

async function emitRouteStatus(routeId, status, reason) {
  const payload = { routeId: String(routeId), status };
  if (reason) payload.reason = reason;
  await emitToRouteAndStudents(routeId, 'route_status_changed', payload);
}

/** student_pickup_updated -> staff + tutor del alumno (sin nombres). */
function emitPickupUpdated(routeId, student) {
  const io = getIO();
  if (!io) return;
  const payload = {
    routeId: String(routeId),
    studentId: String(student._id),
    pickupStatus: student.pickupStatus,
  };
  if (student.stopLabel) payload.stopLabel = student.stopLabel;
  io.to(staffRoom(routeId)).to(studentRoom(student._id)).emit('student_pickup_updated', payload);
}

module.exports = {
  emitToRoute,
  emitToStaff,
  emitToStudent,
  emitToRouteAndStudents,
  emitRouteStatus,
  emitPickupUpdated,
};
