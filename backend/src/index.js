const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { createServer } = require('./server');

const PORT = parseInt(process.env.PORT, 10) || 3000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/sts';
const AUTO_SEED = String(process.env.AUTO_SEED || 'true').toLowerCase() !== 'false';

createServer({ mongoUri: MONGO_URI, port: PORT, host: '0.0.0.0', autoSeed: AUTO_SEED })
  .then(({ port }) => {
    console.log(`[sts] API + Socket.IO escuchando en http://0.0.0.0:${port}`);
  })
  .catch((err) => {
    console.error(`[sts] No se pudo iniciar el servidor: ${err.message}`);
    process.exit(1);
  });

process.on('unhandledRejection', (err) => console.error('[unhandledRejection]', err));
