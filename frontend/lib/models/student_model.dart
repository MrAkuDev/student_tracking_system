import 'package:latlong2/latlong.dart';

import 'enums.dart';
import 'json_utils.dart';

/// `{firstName,lastName,phone1,phone2}`
class TutorInfo {
  final String firstName;
  final String lastName;
  final String phone1;
  final String phone2;

  const TutorInfo({
    this.firstName = '',
    this.lastName = '',
    this.phone1 = '',
    this.phone2 = '',
  });

  String get fullName => '$firstName $lastName'.trim();

  factory TutorInfo.fromJson(Object? json) {
    final m = asMap(json);
    return TutorInfo(
      firstName: asString(m['firstName']),
      lastName: asString(m['lastName']),
      phone1: asString(m['phone1']),
      phone2: asString(m['phone2']),
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone1': phone1,
        'phone2': phone2,
      };

  TutorInfo copyWith({
    String? firstName,
    String? lastName,
    String? phone1,
    String? phone2,
  }) =>
      TutorInfo(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone1: phone1 ?? this.phone1,
        phone2: phone2 ?? this.phone2,
      );
}

/// `{lat,lng,isSet}` — pin de abordaje del tutor.
class PickupLocation {
  final double? lat;
  final double? lng;
  final bool isSet;

  const PickupLocation({this.lat, this.lng, this.isSet = false});

  /// `null` si el tutor aún no fijó su pin.
  LatLng? get latLng {
    final la = lat;
    final ln = lng;
    if (isSet && la != null && ln != null) return LatLng(la, ln);
    return null;
  }

  factory PickupLocation.fromJson(Object? json) {
    final m = asMap(json);
    return PickupLocation(
      lat: asDoubleOrNull(m['lat']),
      lng: asDoubleOrNull(m['lng']),
      isSet: asBool(m['isSet']),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'isSet': isSet};
}

/// `{monday..friday: bool}`
class WeeklySchedule {
  final bool monday;
  final bool tuesday;
  final bool wednesday;
  final bool thursday;
  final bool friday;

  const WeeklySchedule({
    this.monday = true,
    this.tuesday = true,
    this.wednesday = true,
    this.thursday = true,
    this.friday = true,
  });

  /// `day` ∈ monday|tuesday|wednesday|thursday|friday.
  bool isEnabled(String day) {
    switch (day) {
      case 'monday':
        return monday;
      case 'tuesday':
        return tuesday;
      case 'wednesday':
        return wednesday;
      case 'thursday':
        return thursday;
      case 'friday':
        return friday;
    }
    return true;
  }

  WeeklySchedule withDay(String day, bool enabled) => WeeklySchedule(
        monday: day == 'monday' ? enabled : monday,
        tuesday: day == 'tuesday' ? enabled : tuesday,
        wednesday: day == 'wednesday' ? enabled : wednesday,
        thursday: day == 'thursday' ? enabled : thursday,
        friday: day == 'friday' ? enabled : friday,
      );

  factory WeeklySchedule.fromJson(Object? json) {
    final m = asMap(json);
    return WeeklySchedule(
      monday: asBool(m['monday'], true),
      tuesday: asBool(m['tuesday'], true),
      wednesday: asBool(m['wednesday'], true),
      thursday: asBool(m['thursday'], true),
      friday: asBool(m['friday'], true),
    );
  }

  Map<String, dynamic> toJson() => {
        'monday': monday,
        'tuesday': tuesday,
        'wednesday': wednesday,
        'thursday': thursday,
        'friday': friday,
      };
}

/// Alumno completo (vista coordinador y tutor). NUNCA se usa en el chofer.
class Student {
  final String id;
  final String uuid;
  final String shortCode;
  final String routeId;
  final String firstName;
  final String lastName;
  final String grade;
  final TutorInfo tutor;
  final PickupLocation pickupLocation;
  final WeeklySchedule weeklySchedule;
  final TodayServiceStatus todayServiceStatus;
  final PickupStatus pickupStatus;
  final String? stopLabel;
  final int? stopOrder;

  const Student({
    required this.id,
    this.uuid = '',
    this.shortCode = '',
    this.routeId = '',
    this.firstName = '',
    this.lastName = '',
    this.grade = '',
    this.tutor = const TutorInfo(),
    this.pickupLocation = const PickupLocation(),
    this.weeklySchedule = const WeeklySchedule(),
    this.todayServiceStatus = TodayServiceStatus.pending,
    this.pickupStatus = PickupStatus.pending,
    this.stopLabel,
    this.stopOrder,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory Student.fromJson(Object? json) {
    final m = asMap(json);
    return Student(
      id: asString(m['id'] ?? m['_id']),
      uuid: asString(m['uuid']),
      shortCode: asString(m['shortCode']),
      routeId: asString(m['routeId']),
      firstName: asString(m['firstName']),
      lastName: asString(m['lastName']),
      grade: asString(m['grade']),
      tutor: TutorInfo.fromJson(m['tutor']),
      pickupLocation: PickupLocation.fromJson(m['pickupLocation']),
      weeklySchedule: WeeklySchedule.fromJson(m['weeklySchedule']),
      todayServiceStatus:
          TodayServiceStatus.parse(asStringOrNull(m['todayServiceStatus'])),
      pickupStatus: PickupStatus.parse(asStringOrNull(m['pickupStatus'])),
      stopLabel: asStringOrNull(m['stopLabel']),
      stopOrder: asIntOrNull(m['stopOrder']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'shortCode': shortCode,
        'routeId': routeId,
        'firstName': firstName,
        'lastName': lastName,
        'grade': grade,
        'tutor': tutor.toJson(),
        'pickupLocation': pickupLocation.toJson(),
        'weeklySchedule': weeklySchedule.toJson(),
        'todayServiceStatus': todayServiceStatus.value,
        'pickupStatus': pickupStatus.value,
        'stopLabel': stopLabel,
        'stopOrder': stopOrder,
      };

  Student copyWith({
    String? firstName,
    String? lastName,
    String? grade,
    TutorInfo? tutor,
    PickupLocation? pickupLocation,
    WeeklySchedule? weeklySchedule,
    TodayServiceStatus? todayServiceStatus,
    PickupStatus? pickupStatus,
  }) =>
      Student(
        id: id,
        uuid: uuid,
        shortCode: shortCode,
        routeId: routeId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        grade: grade ?? this.grade,
        tutor: tutor ?? this.tutor,
        pickupLocation: pickupLocation ?? this.pickupLocation,
        weeklySchedule: weeklySchedule ?? this.weeklySchedule,
        todayServiceStatus: todayServiceStatus ?? this.todayServiceStatus,
        pickupStatus: pickupStatus ?? this.pickupStatus,
        stopLabel: stopLabel,
        stopOrder: stopOrder,
      );
}

/// Cuerpo de `POST /api/routes/:id/students` y `PUT /api/students/:id`.
class StudentPayload {
  final String firstName;
  final String lastName;
  final String grade;
  final TutorInfo tutor;

  const StudentPayload({
    required this.firstName,
    required this.lastName,
    required this.grade,
    required this.tutor,
  });

  factory StudentPayload.fromStudent(Student s) => StudentPayload(
        firstName: s.firstName,
        lastName: s.lastName,
        grade: s.grade,
        tutor: s.tutor,
      );

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'grade': grade,
        'tutor': tutor.toJson(),
      };
}
