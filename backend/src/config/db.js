const mongoose = require('mongoose');

mongoose.set('strictQuery', true);

async function connectDB(uri) {
  if (!uri) throw new Error('MONGO_URI no está definido (ver backend/.env.example)');
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 8000 });
  return mongoose.connection;
}

async function disconnectDB() {
  await mongoose.disconnect();
}

module.exports = { connectDB, disconnectDB };
