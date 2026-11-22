import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'config/routes.dart';
import 'models/enums.dart';
import 'providers/demo_mode_provider.dart';
import 'providers/server_config_provider.dart';
import 'providers/session_provider.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/osrm_service.dart';
import 'services/socket_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final serverConfig = ServerConfigProvider();
  final demoMode = DemoModeProvider();
  final session = SessionProvider();

  await Future.wait([
    serverConfig.load(),
    demoMode.load(),
    session.restore(),
    NotificationService.instance.init(),
  ]);

  final apiService = ApiService(serverConfig);
  final socketService = SocketService(serverConfig);
  final osrmService = OsrmService();
  final locationService = LocationService();

  NotificationService.instance.onTap = (payload) {
    _handleNotificationTap(payload, session);
  };

  final initialRoute = _resolveInitialRoute(
    session,
    NotificationService.instance.launchPayload,
  );
  NotificationService.instance.launchPayload = null;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: serverConfig),
        ChangeNotifierProvider.value(value: demoMode),
        ChangeNotifierProvider.value(value: session),
        Provider<ApiService>.value(value: apiService),
        Provider<SocketService>.value(value: socketService),
        Provider<OsrmService>.value(value: osrmService),
        Provider<LocationService>.value(value: locationService),
      ],
      child: StsApp(initialRoute: initialRoute),
    ),
  );
}

String _resolveInitialRoute(SessionProvider session, String? launchPayload) {
  if (!session.hasSession) return AppRoutes.roleSelection;
  switch (session.role!) {
    case UserRole.coordinator:
      return AppRoutes.coordinatorHome;
    case UserRole.tutor:
      if (launchPayload == NotificationPayloads.confirmService) {
        return AppRoutes.tutorConfirmService;
      }
      if (launchPayload == NotificationPayloads.proximity ||
          launchPayload == NotificationPayloads.arrivedStop ||
          launchPayload == NotificationPayloads.routeStatus ||
          launchPayload == NotificationPayloads.arrivedSchool) {
        return AppRoutes.tutorLiveTracking;
      }
      final student = session.student;
      if (student != null && !student.pickupLocation.isSet) {
        return AppRoutes.tutorValidateData;
      }
      return AppRoutes.tutorHome;
    case UserRole.driver:
      return AppRoutes.driverRoute;
  }
}

void _handleNotificationTap(String? payload, SessionProvider session) {
  if (session.role != UserRole.tutor) return;
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  if (payload == NotificationPayloads.confirmService) {
    nav.pushNamed(AppRoutes.tutorConfirmService);
  } else if (payload == NotificationPayloads.proximity ||
      payload == NotificationPayloads.arrivedStop ||
      payload == NotificationPayloads.routeStatus ||
      payload == NotificationPayloads.arrivedSchool) {
    nav.pushNamed(AppRoutes.tutorLiveTracking);
  }
}

class StsApp extends StatelessWidget {
  const StsApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: initialRoute,
      routes: AppRoutes.routes,
    );
  }
}
