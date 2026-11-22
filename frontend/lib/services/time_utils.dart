import 'package:flutter/material.dart';

/// Claves del contrato para los días hábiles.
const List<String> kWeekdayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
];

const Map<String, String> kWeekdayLabels = {
  'monday': 'Lunes',
  'tuesday': 'Martes',
  'wednesday': 'Miércoles',
  'thursday': 'Jueves',
  'friday': 'Viernes',
};

class TimeUtils {
  TimeUtils._();

  /// "07:30" → TimeOfDay (07:30 si es inválido).
  static TimeOfDay parseHHmm(String s) {
    final parts = s.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim());
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return const TimeOfDay(hour: 7, minute: 30);
  }

  /// TimeOfDay → "07:30" (formato del contrato).
  static String toHHmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// "07:30" → "07:30 AM".
  static String to12h(String hhmm) {
    final t = parseHHmm(hhmm);
    final h12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h12.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  /// Próxima ocurrencia (hoy o mañana) de la hora "HH:mm".
  static DateTime nextOccurrence(String hhmm, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final t = parseHHmm(hhmm);
    var at = DateTime(n.year, n.month, n.day, t.hour, t.minute);
    if (!at.isAfter(n)) at = at.add(const Duration(days: 1));
    return at;
  }

  /// Clave del día (`monday`..`friday`) o `null` si es fin de semana.
  static String? weekdayKey(DateTime d) =>
      d.weekday >= 1 && d.weekday <= 5 ? kWeekdayKeys[d.weekday - 1] : null;
}
