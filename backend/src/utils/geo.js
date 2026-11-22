const R = 6371000;
const rad = (d) => (d * Math.PI) / 180;

/** Distancia haversine en metros. */
function haversine(lat1, lng1, lat2, lng2) {
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
}

const isLat = (v) => typeof v === 'number' && Number.isFinite(v) && v >= -90 && v <= 90;
const isLng = (v) => typeof v === 'number' && Number.isFinite(v) && v >= -180 && v <= 180;

module.exports = { haversine, isLat, isLng };
