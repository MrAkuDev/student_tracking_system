const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { MongoMemoryServer } = require('mongodb-memory-server');
const { createServer } = require('./server');

const PORT = parseInt(process.env.PORT, 10) || 3000;

async function main() {
  console.log('[sts] Iniciando MongoDB en memoria (modo demo sin Docker/Mongo local)...');
  const mongod = await MongoMemoryServer.create();
  const mongoUri = mongod.getUri('sts');

  const srv = await createServer({
    mongoUri,
    port: PORT,
    host: '0.0.0.0',
    autoSeed: true,
  });

  console.log(`[sts] API + Socket.IO escuchando en http://0.0.0.0:${srv.port}`);
  console.log('[sts] Base de datos en memoria lista con seed demo (admin / 1234, RUT-101, ALU-1001).');
  console.log('[sts] Nota: los datos se reinician al detener este proceso.');

  const shutdown = async () => {
    console.log('\n[sts] Deteniendo servidor...');
    await srv.close().catch(() => {});
    await mongod.stop().catch(() => {});
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error(`[sts] No se pudo iniciar el servidor en memoria: ${err.message}`);
  process.exit(1);
});
