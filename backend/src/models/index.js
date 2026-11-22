const mongoose = require('mongoose');
const { Schema } = mongoose;

const Coordinator = mongoose.model(
  'Coordinator',
  new Schema({
    username: { type: String, required: true, unique: true, trim: true },
    password: { type: String, required: true },
    name: { type: String, default: '' },
    phone: { type: String, default: '' },
  })
);

const SchoolConfig = mongoose.model(
  'SchoolConfig',
  new Schema({
    name: { type: String, default: 'Escuela Primaria STS' },
    address: { type: String, default: '' },
    location: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
    },
  })
);

const routeSchema = new Schema({
  uuid: { type: String, required: true, unique: true },
  shortCode: { type: String, required: true, unique: true },
  name: { type: String, default: 'Nueva ruta' },
  startTime: { type: String, default: '07:30' },
  schoolLocation: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    address: { type: String, default: '' },
  },
  status: {
    type: String,
    enum: ['idle', 'in_progress', 'paused', 'breakdown', 'arrived_school', 'completed'],
    default: 'idle',
  },
  currentLocation: {
    lat: Number,
    lng: Number,
    updatedAt: Date,
  },
  polyline: { type: [[Number]], default: [] },
  sosActive: { type: Boolean, default: false },
  activeTripId: { type: Schema.Types.ObjectId, default: null },
  coordinatorId: { type: Schema.Types.ObjectId, ref: 'Coordinator', default: null },
});
const Route = mongoose.model('Route', routeSchema);

const studentSchema = new Schema({
  uuid: { type: String, required: true, unique: true },
  shortCode: { type: String, required: true, unique: true },
  routeId: { type: Schema.Types.ObjectId, ref: 'Route', required: true, index: true },
  firstName: { type: String, required: true, trim: true },
  lastName: { type: String, required: true, trim: true },
  grade: { type: String, default: '' },
  tutor: {
    firstName: { type: String, default: '' },
    lastName: { type: String, default: '' },
    phone1: { type: String, default: '' },
    phone2: { type: String, default: '' },
  },
  pickupLocation: {
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
    isSet: { type: Boolean, default: false },
  },
  weeklySchedule: {
    monday: { type: Boolean, default: true },
    tuesday: { type: Boolean, default: true },
    wednesday: { type: Boolean, default: true },
    thursday: { type: Boolean, default: true },
    friday: { type: Boolean, default: true },
  },
  todayServiceStatus: {
    type: String,
    enum: ['pending', 'confirmed', 'rejected'],
    default: 'pending',
  },
  pickupStatus: {
    type: String,
    enum: ['pending', 'approaching', 'arrived_stop', 'picked_up', 'dropped_at_school'],
    default: 'pending',
  },
  stopLabel: { type: String, default: null },
  stopOrder: { type: Number, default: null },
});
const Student = mongoose.model('Student', studentSchema);

const IncidentReport = mongoose.model(
  'IncidentReport',
  new Schema({
    routeId: { type: Schema.Types.ObjectId, ref: 'Route', required: true, index: true },
    reportedByRole: { type: String, enum: ['coordinator', 'driver'], default: 'coordinator' },
    description: { type: String, required: true },
    involvedStudentId: { type: Schema.Types.ObjectId, ref: 'Student', default: null },
    createdAt: { type: Date, default: Date.now },
  })
);

module.exports = { Coordinator, SchoolConfig, Route, Student, IncidentReport };
