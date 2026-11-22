import 'package:flutter/material.dart';

import '../screens/coordinator/confirm_arrival_screen.dart';
import '../screens/coordinator/coordinator_home_screen.dart';
import '../screens/coordinator/coordinator_live_route_screen.dart';
import '../screens/coordinator/coordinator_login_screen.dart';
import '../screens/coordinator/report_problem_screen.dart';
import '../screens/coordinator/route_detail_edit_screen.dart';
import '../screens/coordinator/school_location_picker_screen.dart';
import '../screens/coordinator/student_form_screen.dart';
import '../screens/driver/driver_code_screen.dart';
import '../screens/driver/driver_route_screen.dart';
import '../screens/driver/driver_sos_screen.dart';
import '../screens/driver/driver_trip_finished_screen.dart';
import '../screens/onboarding/role_selection_screen.dart';
import '../screens/onboarding/server_settings_screen.dart';
import '../screens/tutor/tutor_code_screen.dart';
import '../screens/tutor/tutor_confirm_service_screen.dart';
import '../screens/tutor/tutor_home_screen.dart';
import '../screens/tutor/tutor_live_tracking_screen.dart';
import '../screens/tutor/tutor_no_code_info_screen.dart';
import '../screens/tutor/tutor_pickup_pin_screen.dart';
import '../screens/tutor/tutor_saving_screen.dart';
import '../screens/tutor/tutor_validate_data_screen.dart';
import '../screens/tutor/tutor_welcome_screen.dart';

/// Nombres de ruta y registro global de pantallas de STS.
class AppRoutes {
  AppRoutes._();

  // Onboarding
  static const String roleSelection = '/';
  static const String serverSettings = '/server-settings';

  // Coordinador (0–6 + selector de escuela)
  static const String coordinatorLogin = '/coordinator/login';
  static const String coordinatorHome = '/coordinator/home';
  static const String coordinatorRouteEdit = '/coordinator/route-edit';
  static const String coordinatorSchoolPicker = '/coordinator/school-picker';
  static const String coordinatorStudentForm = '/coordinator/student-form';
  static const String coordinatorLive = '/coordinator/live';
  static const String coordinatorConfirmArrival = '/coordinator/confirm-arrival';
  static const String coordinatorReportProblem = '/coordinator/report-problem';

  // Tutor (1–7 + Día de recolección)
  static const String tutorCode = '/tutor/code';
  static const String tutorNoCodeInfo = '/tutor/no-code';
  static const String tutorWelcome = '/tutor/welcome';
  static const String tutorValidateData = '/tutor/validate-data';
  static const String tutorPickupPin = '/tutor/pickup-pin';
  static const String tutorSaving = '/tutor/saving';
  static const String tutorHome = '/tutor/home';
  static const String tutorConfirmService = '/tutor/confirm-service';
  static const String tutorLiveTracking = '/tutor/live';

  // Chofer (5, 1–2, 3, 4)
  static const String driverCode = '/driver/code';
  static const String driverRoute = '/driver/route';
  static const String driverSos = '/driver/sos';
  static const String driverTripFinished = '/driver/trip-finished';

  /// Lee los argumentos tipados de la ruta actual (null si no coinciden).
  static T? argsOf<T>(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is T ? args : null;
  }

  static Map<String, WidgetBuilder> get routes => {
        roleSelection: (_) => const RoleSelectionScreen(),
        serverSettings: (_) => const ServerSettingsScreen(),
        // Coordinador
        coordinatorLogin: (_) => const CoordinatorLoginScreen(),
        coordinatorHome: (_) => const CoordinatorHomeScreen(),
        coordinatorRouteEdit: (_) => const RouteDetailEditScreen(),
        coordinatorSchoolPicker: (_) => const SchoolLocationPickerScreen(),
        coordinatorStudentForm: (_) => const StudentFormScreen(),
        coordinatorLive: (_) => const CoordinatorLiveRouteScreen(),
        coordinatorConfirmArrival: (_) => const ConfirmArrivalScreen(),
        coordinatorReportProblem: (_) => const ReportProblemScreen(),
        // Tutor
        tutorCode: (_) => const TutorCodeScreen(),
        tutorNoCodeInfo: (_) => const TutorNoCodeInfoScreen(),
        tutorWelcome: (_) => const TutorWelcomeScreen(),
        tutorValidateData: (_) => const TutorValidateDataScreen(),
        tutorPickupPin: (_) => const TutorPickupPinScreen(),
        tutorSaving: (_) => const TutorSavingScreen(),
        tutorHome: (_) => const TutorHomeScreen(),
        tutorConfirmService: (_) => const TutorConfirmServiceScreen(),
        tutorLiveTracking: (_) => const TutorLiveTrackingScreen(),
        // Chofer
        driverCode: (_) => const DriverCodeScreen(),
        driverRoute: (_) => const DriverRouteScreen(),
        driverSos: (_) => const DriverSosScreen(),
        driverTripFinished: (_) => const DriverTripFinishedScreen(),
      };
}
