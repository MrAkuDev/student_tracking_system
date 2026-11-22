import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/enums.dart';
import '../models/json_utils.dart';
import '../models/socket_events.dart';
import '../providers/server_config_provider.dart';

/// Cliente Socket.IO (contrato `building.md` §4).
///
/// Uso típico en una pantalla:
/// ```dart
/// final socket = context.read<SocketService>();
/// socket.joinRoute(routeId, UserRole.driver);          // conecta si hace falta
/// _sub = socket.onRouteStarted.listen((e) { ... });    // cancelar en dispose()
/// ```
/// Las salas se recuerdan y se re-unen automáticamente tras una reconexión.
/// Al cambiar la URL del servidor se reconecta solo.
class SocketService {
  SocketService(this._config) {
    _config.addListener(_onConfigChanged);
  }

  final ServerConfigProvider _config;
  io.Socket? _socket;
  String? _connectedUrl;
  bool _disposed = false;

  final Set<String> _routeRooms = <String>{}; // "routeId|role"
  final Set<String> _studentRooms = <String>{};

  final _connectionCtrl = StreamController<bool>.broadcast();
  final _busCtrl = StreamController<BusLocationEvent>.broadcast();
  final _statusCtrl = StreamController<RouteStatusEvent>.broadcast();
  final _startedCtrl = StreamController<RouteStartedEvent>.broadcast();
  final _polylineCtrl = StreamController<PolylineEvent>.broadcast();
  final _pickupCtrl = StreamController<PickupUpdateEvent>.broadcast();
  final _proximityCtrl = StreamController<ProximityEvent>.broadcast();
  final _sosCtrl = StreamController<SosEvent>.broadcast();
  final _tripCompletedCtrl = StreamController<TripCompletedEvent>.broadcast();
  final _serviceCtrl = StreamController<StudentServiceEvent>.broadcast();

  // ---- Streams por evento --------------------------------------------------
  /// `true`/`false` al conectar/desconectar.
  Stream<bool> get onConnectionChanged => _connectionCtrl.stream;

  /// `bus_location_updated`
  Stream<BusLocationEvent> get onBusLocation => _busCtrl.stream;

  /// `route_status_changed`
  Stream<RouteStatusEvent> get onRouteStatusChanged => _statusCtrl.stream;

  /// `route_started`
  Stream<RouteStartedEvent> get onRouteStarted => _startedCtrl.stream;

  /// `route_polyline_updated`
  Stream<PolylineEvent> get onPolylineUpdated => _polylineCtrl.stream;

  /// `student_pickup_updated`
  Stream<PickupUpdateEvent> get onStudentPickupUpdated => _pickupCtrl.stream;

  /// `proximity_alert`
  Stream<ProximityEvent> get onProximityAlert => _proximityCtrl.stream;

  /// `driver_sos_triggered`
  Stream<SosEvent> get onDriverSos => _sosCtrl.stream;

  /// `trip_completed`
  Stream<TripCompletedEvent> get onTripCompleted => _tripCompletedCtrl.stream;

  /// `student_service_updated`
  Stream<StudentServiceEvent> get onStudentServiceUpdated =>
      _serviceCtrl.stream;

  bool get isConnected => _socket?.connected ?? false;

  // ---- Conexión ------------------------------------------------------------

  /// Conecta (idempotente). Se llama sola desde [joinRoute]/[joinStudent].
  void connect() {
    if (_disposed) return;
    final url = _config.baseUrl;
    final existing = _socket;
    if (existing != null && _connectedUrl == url) {
      if (!existing.connected) existing.connect();
      return;
    }
    _teardownSocket();
    _connectedUrl = url;

    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _rejoinRooms();
      _emitConnection(true);
    });
    socket.onDisconnect((_) => _emitConnection(false));
    socket.onConnectError((err) {
      debugPrint('SocketService: error de conexión: $err');
      _emitConnection(false);
    });

    _listen<BusLocationEvent>(
        socket, 'bus_location_updated', BusLocationEvent.fromJson, _busCtrl);
    _listen<RouteStatusEvent>(
        socket, 'route_status_changed', RouteStatusEvent.fromJson, _statusCtrl);
    _listen<RouteStartedEvent>(
        socket, 'route_started', RouteStartedEvent.fromJson, _startedCtrl);
    _listen<PolylineEvent>(socket, 'route_polyline_updated',
        PolylineEvent.fromJson, _polylineCtrl);
    _listen<PickupUpdateEvent>(socket, 'student_pickup_updated',
        PickupUpdateEvent.fromJson, _pickupCtrl);
    _listen<ProximityEvent>(
        socket, 'proximity_alert', ProximityEvent.fromJson, _proximityCtrl);
    _listen<SosEvent>(
        socket, 'driver_sos_triggered', SosEvent.fromJson, _sosCtrl);
    _listen<TripCompletedEvent>(
        socket, 'trip_completed', TripCompletedEvent.fromJson, _tripCompletedCtrl);
    _listen<StudentServiceEvent>(socket, 'student_service_updated',
        StudentServiceEvent.fromJson, _serviceCtrl);

    socket.connect();
  }

  void _listen<T>(
    io.Socket socket,
    String event,
    T Function(Map<String, dynamic>) parse,
    StreamController<T> controller,
  ) {
    socket.on(event, (dynamic data) {
      if (controller.isClosed) return;
      try {
        final payload = data is List && data.isNotEmpty ? data.first : data;
        controller.add(parse(asMap(payload)));
      } catch (e) {
        debugPrint('SocketService: payload inválido en "$event": $e');
      }
    });
  }

  void _emitConnection(bool value) {
    if (!_connectionCtrl.isClosed) _connectionCtrl.add(value);
  }

  void _rejoinRooms() {
    final socket = _socket;
    if (socket == null) return;
    for (final key in _routeRooms) {
      final parts = key.split('|');
      socket.emit('join_route', {'routeId': parts[0], 'role': parts[1]});
    }
    for (final id in _studentRooms) {
      socket.emit('join_student', {'studentId': id});
    }
  }

  // ---- Salas ---------------------------------------------------------------

  /// `join_route` {routeId, role}. Conecta si todavía no hay conexión.
  void joinRoute(String routeId, UserRole role) {
    _routeRooms.add('$routeId|${role.value}');
    connect();
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('join_route', {'routeId': routeId, 'role': role.value});
    }
  }

  /// `join_student` {studentId} (tutor). Conecta si hace falta.
  void joinStudent(String studentId) {
    _studentRooms.add(studentId);
    connect();
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('join_student', {'studentId': studentId});
    }
  }

  // ---- Emisión -------------------------------------------------------------

  /// `driver_location_update` {routeId, lat, lng} (chofer).
  void emitDriverLocation(String routeId, double lat, double lng) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('driver_location_update',
        {'routeId': routeId, 'lat': lat, 'lng': lng});
  }

  // ---- Ciclo de vida ---------------------------------------------------------

  /// Desconecta y olvida las salas (usar al cerrar sesión / cambiar de rol).
  void disconnect() {
    _routeRooms.clear();
    _studentRooms.clear();
    _teardownSocket();
    _emitConnection(false);
  }

  void _teardownSocket() {
    final socket = _socket;
    if (socket != null) {
      socket.clearListeners();
      socket.disconnect();
      socket.dispose();
    }
    _socket = null;
    _connectedUrl = null;
  }

  void _onConfigChanged() {
    if (_disposed) return;
    if (_socket != null && _connectedUrl != _config.baseUrl) {
      // Mantiene las salas recordadas y reconecta a la nueva URL.
      _teardownSocket();
      connect();
    }
  }

  void dispose() {
    _disposed = true;
    _config.removeListener(_onConfigChanged);
    _teardownSocket();
    for (final c in <StreamController<dynamic>>[
      _connectionCtrl,
      _busCtrl,
      _statusCtrl,
      _startedCtrl,
      _polylineCtrl,
      _pickupCtrl,
      _proximityCtrl,
      _sosCtrl,
      _tripCompletedCtrl,
      _serviceCtrl,
    ]) {
      c.close();
    }
  }
}
