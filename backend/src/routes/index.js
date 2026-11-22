const express = require('express');
const c = require('../controllers/coordinatorController');
const a = require('../controllers/accessController');

const router = express.Router();

// Utilidad
router.get('/health', a.health);
router.get('/config/school', a.schoolConfig);
router.post('/admin/reset-db', a.adminResetDb);
router.post('/admin/seed-demo', a.adminSeedDemo);

// Auth / acceso
router.post('/coordinator/login', a.coordinatorLogin);
router.post('/tutor/access', a.tutorAccess);
router.post('/driver/access', a.driverAccess);

// Coordinador: rutas
router.get('/routes', c.listRoutes);
router.post('/routes', c.createRoute);
router.get('/routes/:id', c.getRoute);
router.put('/routes/:id', c.updateRoute);
router.delete('/routes/:id', c.deleteRoute);
router.post('/routes/:id/start', c.startRoute);
router.put('/routes/:id/polyline', c.setPolyline);
router.patch('/routes/:id/status', c.patchStatus);
router.post('/routes/:id/arrived-school', c.arrivedSchool);
router.post('/routes/:id/confirm-arrival', c.confirmArrival);
router.post('/routes/:id/incidents', c.createIncident);
router.get('/routes/:id/incidents', c.listIncidents);
router.get('/routes/:id/live', c.liveRoute);

// Coordinador: alumnos
router.post('/routes/:id/students', c.createStudent);
router.put('/students/:id', c.updateStudent);
router.delete('/students/:id', c.deleteStudent);

// Tutor
router.get('/tutor/students/:id', a.tutorGetStudent);
router.put('/tutor/students/:id/profile', a.tutorUpdateProfile);
router.patch('/tutor/students/:id/schedule', a.tutorSchedule);
router.post('/tutor/students/:id/today-confirmation', a.tutorTodayConfirmation);
router.get('/tutor/students/:id/live', a.tutorLive);

// Chofer (sanitizado)
router.get('/driver/routes/:routeId/stops', a.driverStops);
router.post('/driver/routes/:routeId/confirm-pickup', a.driverConfirmPickup);
router.post('/driver/routes/:routeId/sos', a.driverSos);
router.post('/driver/routes/:routeId/arrived-school', a.driverArrivedSchool);

module.exports = router;
