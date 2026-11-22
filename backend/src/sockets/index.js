const { Server } = require('socket.io');
const { isOid } = require('../utils/errors');
const { isLat, isLng } = require('../utils/geo');

let io = null;

const ROLES = ['coordinator', 'driver', 'tutor'];

function initSockets(httpServer) {
  io = new Server(httpServer, {
    cors: { origin: '*', methods: ['GET', 'POST'] },
    transports: ['websocket', 'polling'],
  });

  io.on('connection', (socket) => {
    const reply = (ack, payload) => {
      if (typeof ack === 'function') ack(payload);
    };

    socket.on('join_route', (payload, ack) => {
      const routeId = payload && payload.routeId;
      if (!isOid(routeId)) return reply(ack, { ok: false, error: 'routeId inválido' });
      // Auth simulada: el rol lo declara el cliente. Cualquier valor desconocido se trata como tutor (sin sala staff).
      const role = ROLES.includes(payload.role) ? payload.role : 'tutor';
      socket.join(`route:${routeId}`);
      if (role !== 'tutor') socket.join(`route:${routeId}:staff`);
      return reply(ack, { ok: true, routeId, role });
    });

    socket.on('join_student', (payload, ack) => {
      const studentId = payload && payload.studentId;
      if (!isOid(studentId)) return reply(ack, { ok: false, error: 'studentId inválido' });
      socket.join(`student:${studentId}`);
      return reply(ack, { ok: true, studentId });
    });

    socket.on('driver_location_update', async (payload, ack) => {
      try {
        const { routeId, lat, lng } = payload || {};
        if (!isOid(routeId) || !isLat(lat) || !isLng(lng)) {
          return reply(ack, { ok: false, error: 'Datos de ubicación inválidos' });
        }
        // require perezoso para evitar dependencia circular
        const { processLocation } = require('../services/proximityService');
        await processLocation(routeId, lat, lng);
        return reply(ack, { ok: true });
      } catch (err) {
        console.error('[socket] driver_location_update', err);
        return reply(ack, { ok: false, error: 'Error procesando la ubicación' });
      }
    });
  });

  return io;
}

const getIO = () => io;

module.exports = { initSockets, getIO };
