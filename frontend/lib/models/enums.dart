/// Enums del dominio STS con su valor de contrato (`value`) y etiqueta en español.

enum UserRole {
  coordinator('coordinator', 'Coordinador'),
  tutor('tutor', 'Tutor'),
  driver('driver', 'Chofer');

  const UserRole(this.value, this.label);
  final String value;
  final String label;

  static UserRole? tryParse(String? v) {
    for (final r in UserRole.values) {
      if (r.value == v) return r;
    }
    return null;
  }
}

enum RouteStatus {
  idle('idle', 'Sin iniciar'),
  inProgress('in_progress', 'En progreso'),
  paused('paused', 'En pausa'),
  breakdown('breakdown', 'Avería'),
  arrivedSchool('arrived_school', 'Llegó a la escuela'),
  completed('completed', 'Completada');

  const RouteStatus(this.value, this.label);
  final String value;
  final String label;

  /// Hay un viaje en curso (incluye pausa/avería/llegada pendiente de confirmar).
  bool get isActiveTrip =>
      this == inProgress ||
      this == paused ||
      this == breakdown ||
      this == arrivedSchool;

  static RouteStatus parse(String? v) {
    for (final s in RouteStatus.values) {
      if (s.value == v) return s;
    }
    return RouteStatus.idle;
  }
}

enum PickupStatus {
  pending('pending', 'Pendiente'),
  approaching('approaching', 'Acercándose'),
  arrivedStop('arrived_stop', 'En la parada'),
  pickedUp('picked_up', 'Recogido'),
  droppedAtSchool('dropped_at_school', 'En la escuela');

  const PickupStatus(this.value, this.label);
  final String value;
  final String label;

  /// El alumno ya subió al transporte (palomita verde en coordinador).
  bool get isPickedUp => this == pickedUp || this == droppedAtSchool;

  static PickupStatus parse(String? v) {
    for (final s in PickupStatus.values) {
      if (s.value == v) return s;
    }
    return PickupStatus.pending;
  }
}

enum TodayServiceStatus {
  pending('pending', 'Sin confirmar'),
  confirmed('confirmed', 'Confirmado'),
  rejected('rejected', 'Rechazado');

  const TodayServiceStatus(this.value, this.label);
  final String value;
  final String label;

  static TodayServiceStatus parse(String? v) {
    for (final s in TodayServiceStatus.values) {
      if (s.value == v) return s;
    }
    return TodayServiceStatus.pending;
  }
}
