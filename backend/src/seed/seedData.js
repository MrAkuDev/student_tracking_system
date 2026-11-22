const { Coordinator, SchoolConfig, Route, Student } = require('../models');

const SCHOOL = {
  name: 'Escuela Primaria STS',
  address: 'Av. Universidad, Chihuahua, Chih., México',
  location: { lat: 28.6353, lng: -106.0889 },
};

const ROUTES = [
  { shortCode: 'RUT-101', uuid: '0b6f1c1e-7a52-4c1b-9a0e-1f5e0a101101', name: 'Ruta Norte', startTime: '07:30' },
  { shortCode: 'RUT-102', uuid: '0b6f1c1e-7a52-4c1b-9a0e-1f5e0a102102', name: 'Ruta Sur', startTime: '07:45' },
];

const STUDENTS = [
  {
    shortCode: 'ALU-1001',
    uuid: '5d0a8b52-3a3f-4f0c-8d3b-2c9a00001001',
    route: 'RUT-101',
    firstName: 'Sofía',
    lastName: 'Ramírez',
    grade: '3° A',
    tutor: { firstName: 'Laura', lastName: 'Ramírez', phone1: '+526141110001', phone2: '+526141110002' },
    pin: { lat: 28.6453, lng: -106.0889 },
    todayServiceStatus: 'confirmed',
  },
  {
    shortCode: 'ALU-1002',
    uuid: '5d0a8b52-3a3f-4f0c-8d3b-2c9a00001002',
    route: 'RUT-101',
    firstName: 'Mateo',
    lastName: 'Hernández',
    grade: '4° B',
    tutor: { firstName: 'Carlos', lastName: 'Hernández', phone1: '+526141110003', phone2: '' },
    pin: { lat: 28.6403, lng: -106.0809 },
    todayServiceStatus: 'confirmed',
  },
  {
    shortCode: 'ALU-1003',
    uuid: '5d0a8b52-3a3f-4f0c-8d3b-2c9a00001003',
    route: 'RUT-101',
    firstName: 'Valentina',
    lastName: 'Cruz',
    grade: '2° C',
    tutor: { firstName: 'Marisol', lastName: 'Cruz', phone1: '+526141110004', phone2: '+526141110005' },
    pin: { lat: 28.6313, lng: -106.0969 },
    todayServiceStatus: 'pending',
  },
];

/** Idempotente: solo crea lo que falta, nunca sobrescribe datos existentes. */
async function seed() {
  const created = { coordinator: 0, school: 0, routes: 0, students: 0 };

  let coordinator = await Coordinator.findOne({ username: 'admin' });
  if (!coordinator) {
    coordinator = await Coordinator.create({
      username: 'admin',
      password: '1234',
      name: 'Coordinadora Ana López',
      phone: '+526141234567',
    });
    created.coordinator++;
  }

  if (!(await SchoolConfig.findOne())) {
    await SchoolConfig.create(SCHOOL);
    created.school++;
  }
  const school = await SchoolConfig.findOne();

  const routeByCode = {};
  for (const r of ROUTES) {
    let route = await Route.findOne({ shortCode: r.shortCode });
    if (!route) {
      route = await Route.create({
        ...r,
        status: 'idle',
        schoolLocation: { lat: school.location.lat, lng: school.location.lng, address: school.address },
        coordinatorId: coordinator._id,
      });
      created.routes++;
    }
    routeByCode[r.shortCode] = route;
  }

  for (const s of STUDENTS) {
    if (await Student.findOne({ shortCode: s.shortCode })) continue;
    await Student.create({
      shortCode: s.shortCode,
      uuid: s.uuid,
      routeId: routeByCode[s.route]._id,
      firstName: s.firstName,
      lastName: s.lastName,
      grade: s.grade,
      tutor: s.tutor,
      pickupLocation: { lat: s.pin.lat, lng: s.pin.lng, isSet: true },
      todayServiceStatus: s.todayServiceStatus,
    });
    created.students++;
  }
  return created;
}

async function isDatabaseEmpty() {
  const [c, r, s] = await Promise.all([
    Coordinator.estimatedDocumentCount(),
    Route.estimatedDocumentCount(),
    Student.estimatedDocumentCount(),
  ]);
  return c + r + s === 0;
}

module.exports = { seed, isDatabaseEmpty };

if (require.main === module) {
  require('dotenv').config({ path: require('path').join(__dirname, '..', '..', '.env') });
  const { connectDB, disconnectDB } = require('../config/db');
  connectDB(process.env.MONGO_URI || 'mongodb://localhost:27017/sts')
    .then(() => seed())
    .then((created) => {
      console.log('[seed] listo:', created);
      return disconnectDB();
    })
    .catch((err) => {
      console.error('[seed] error:', err.message);
      process.exit(1);
    });
}
