class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

const OID = /^[0-9a-fA-F]{24}$/;
const isOid = (v) => typeof v === 'string' && OID.test(v);

function notFound(req, res) {
  res.status(404).json({ error: `Ruta no encontrada: ${req.method} ${req.originalUrl}` });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'El cuerpo de la petición no es un JSON válido' });
  }
  if (err.type === 'entity.too.large') {
    return res.status(400).json({ error: 'El cuerpo de la petición es demasiado grande' });
  }
  if (err.name === 'ValidationError') {
    const msg = Object.values(err.errors || {}).map((e) => e.message).join('; ');
    return res.status(400).json({ error: msg || 'Datos inválidos' });
  }
  if (err.name === 'CastError') {
    return res.status(400).json({ error: `Valor inválido para "${err.path}"` });
  }
  if (err.code === 11000) {
    return res.status(409).json({ error: 'Ya existe un registro con esos datos' });
  }
  if (err.status && err.status >= 400 && err.status < 500) {
    return res.status(err.status).json({ error: err.message });
  }
  console.error('[error]', err);
  return res.status(500).json({ error: 'Error interno del servidor' });
}

module.exports = { HttpError, asyncHandler, isOid, notFound, errorHandler };
