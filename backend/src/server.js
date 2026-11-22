const http = require('http');
const express = require('express');
const cors = require('cors');
const { connectDB, disconnectDB } = require('./config/db');
const { initSockets } = require('./sockets');
const routes = require('./routes');
const { notFound, errorHandler } = require('./utils/errors');
const { seed, isDatabaseEmpty } = require('./seed/seedData');

function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '5mb' }));
  app.get('/', (req, res) => res.json({ ok: true, service: 'sts-backend' }));
  app.use('/api', routes);
  app.use(notFound);
  app.use(errorHandler);
  return app;
}

async function createServer({ mongoUri, port = 3000, host = '0.0.0.0', autoSeed = true } = {}) {
  const app = createApp();
  const server = http.createServer(app);
  const io = initSockets(server);
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, host, resolve);
  });
  const actualPort = server.address().port;
  console.log(`[sts] Puerto ${actualPort} abierto en ${host}, conectando a MongoDB...`);

  try {
    await connectDB(mongoUri);
    if (autoSeed && (await isDatabaseEmpty())) {
      const created = await seed();
      console.log('[seed] BD vacía, datos iniciales cargados:', created);
    }
  } catch (err) {
    await new Promise((resolve) => io.close(() => resolve()));
    if (server.listening) await new Promise((resolve) => server.close(() => resolve()));
    throw err;
  }

  const close = async () => {
    await new Promise((resolve) => io.close(() => resolve()));
    if (server.listening) await new Promise((resolve) => server.close(() => resolve()));
    await disconnectDB();
  };
  return { app, server, io, port: actualPort, close };
}

module.exports = { createApp, createServer };
