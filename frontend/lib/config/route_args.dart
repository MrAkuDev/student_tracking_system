import 'package:latlong2/latlong.dart';

import '../models/student_model.dart';

/// Argumentos tipados para `Navigator.pushNamed(context, name, arguments: ...)`.
/// Las pantallas los leen con `AppRoutes.argsOf<T>(context)`.
/// Todas las pantallas tienen constructor `const Screen({super.key})` y leen
/// sus argumentos desde aquí (así el router no depende de sus parámetros).

/// Para rutas que solo necesitan el id de la ruta
/// (`coordinatorLive`, `coordinatorConfirmArrival`, `coordinatorReportProblem`).
class RouteIdArgs {
  final String routeId;
  const RouteIdArgs(this.routeId);
}

/// `coordinatorRouteEdit`. `routeId == null` → crear ruta nueva
/// (la pantalla hace `POST /api/routes` al abrirse o al guardar).
class RouteEditArgs {
  final String? routeId;
  const RouteEditArgs({this.routeId});
}

/// `coordinatorStudentForm`. `student == null` → alumno nuevo.
class StudentFormArgs {
  final String routeId;
  final Student? student;
  const StudentFormArgs({required this.routeId, this.student});
}

/// `coordinatorSchoolPicker`. La pantalla hace `Navigator.pop(context, SchoolPickerResult)`
/// al guardar (o `null` si cancela).
class SchoolPickerArgs {
  final LatLng initial;
  final String? address;
  const SchoolPickerArgs({required this.initial, this.address});
}

class SchoolPickerResult {
  final LatLng location;
  final String address;
  const SchoolPickerResult({required this.location, required this.address});
}

/// `tutorValidateData` / `tutorPickupPin`: `editMode == true` cuando el tutor
/// llega desde el FAB de `TutorHomeScreen` (al terminar vuelve a Home).
class TutorFlowArgs {
  final bool editMode;
  const TutorFlowArgs({this.editMode = false});
}
