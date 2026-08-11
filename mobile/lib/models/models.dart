/// Domain entities mirroring the backend API payloads.
/// Pure Dart (no Flutter imports) so they are trivially unit-testable.
library models;

class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // parent | doctor | admin
  final String phone;
  final int? doctorProfileId;
  final int? parentProfileId;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.phone = '',
    this.doctorProfileId,
    this.parentProfileId,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        firstName: (json['first_name'] ?? '') as String,
        lastName: (json['last_name'] ?? '') as String,
        role: json['role'] as String,
        phone: (json['phone'] ?? '') as String,
        doctorProfileId: json['doctor_profile_id'] as int?,
        parentProfileId: json['parent_profile_id'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'phone': phone,
        'doctor_profile_id': doctorProfileId,
        'parent_profile_id': parentProfileId,
      };

  String get fullName => '$firstName $lastName'.trim();
}

class Baby {
  final int id;
  final String name;
  final DateTime birthDate;
  final int weightGrams;
  final String gender;
  final int? assignedDoctor;
  final String? parentName;

  const Baby({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.weightGrams,
    required this.gender,
    this.assignedDoctor,
    this.parentName,
  });

  factory Baby.fromJson(Map<String, dynamic> json) => Baby(
        id: json['id'] as int,
        name: json['name'] as String,
        birthDate: DateTime.parse(json['birth_date'] as String),
        weightGrams: json['weight_grams'] as int,
        gender: json['gender'] as String,
        assignedDoctor: json['assigned_doctor'] as int?,
        parentName: json['parent_name'] as String?,
      );

  /// `clearAssignedDoctor: true` explicitly sets assignedDoctor to null
  /// (plain omission just keeps the current value — needed since `null` is
  /// a valid target value, not "unset").
  Baby copyWith({int? assignedDoctor, bool clearAssignedDoctor = false}) => Baby(
        id: id,
        name: name,
        birthDate: birthDate,
        weightGrams: weightGrams,
        gender: gender,
        assignedDoctor:
            clearAssignedDoctor ? null : (assignedDoctor ?? this.assignedDoctor),
        parentName: parentName,
      );
}

/// Append-only medical history entry (Section 4). Doctors/admins can append;
/// parents and doctors can only ever read — entries are never edited/deleted.
class MedicalHistoryEntry {
  final int id;
  final String title;
  final String details;
  final int? recordedBy;
  final int? supersedes;
  final DateTime createdAt;

  const MedicalHistoryEntry({
    required this.id,
    required this.title,
    required this.details,
    this.recordedBy,
    this.supersedes,
    required this.createdAt,
  });

  factory MedicalHistoryEntry.fromJson(Map<String, dynamic> json) =>
      MedicalHistoryEntry(
        id: json['id'] as int,
        title: json['title'] as String,
        details: (json['details'] ?? '') as String,
        recordedBy: json['recorded_by'] as int?,
        supersedes: json['supersedes'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// A doctor-assignment request (Section 3): a parent requests a doctor for
/// their baby; the doctor accepts or declines. Only acceptance changes the
/// baby's assigned_doctor — a pending request never does.
class DoctorAssignmentRequest {
  final int id;
  final int babyId;
  final String babyName;
  final int doctorId;
  final String doctorName;
  final String doctorSpecialty;
  final int? requestedBy;
  final String status; // pending | accepted | declined | cancelled
  final String note;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const DoctorAssignmentRequest({
    required this.id,
    required this.babyId,
    required this.babyName,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
    this.requestedBy,
    required this.status,
    required this.note,
    required this.createdAt,
    this.respondedAt,
  });

  bool get isPending => status == 'pending';

  factory DoctorAssignmentRequest.fromJson(Map<String, dynamic> json) =>
      DoctorAssignmentRequest(
        id: json['id'] as int,
        babyId: json['baby'] as int,
        babyName: (json['baby_name'] ?? '') as String,
        doctorId: json['doctor'] as int,
        doctorName: (json['doctor_name'] ?? '') as String,
        doctorSpecialty: (json['doctor_specialty'] ?? '') as String,
        requestedBy: json['requested_by'] as int?,
        status: json['status'] as String,
        note: (json['note'] ?? '') as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        respondedAt: json['responded_at'] == null
            ? null
            : DateTime.parse(json['responded_at'] as String),
      );
}
class DoctorProfile {
  final int id; // Doctor.id (NOT the User id — needed for PATCH /doctors/{id}/)
  final int userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String licenseNumber;
  final String specialty;

  const DoctorProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.specialty,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return DoctorProfile(
      id: json['id'] as int,
      userId: user['id'] as int,
      firstName: (user['first_name'] ?? '') as String,
      lastName: (user['last_name'] ?? '') as String,
      email: (user['email'] ?? '') as String,
      phone: (user['phone'] ?? '') as String,
      licenseNumber: (json['license_number'] ?? '') as String,
      specialty: (json['specialty'] ?? '') as String,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

/// A parent's account + contact profile, as seen in the admin parent
/// directory and by a parent editing their own profile.
class ParentProfile {
  final int id; // Parent.id (NOT the User id — needed for PATCH /parents/{id}/)
  final int userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;
  final String emergencyContact;

  const ParentProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.address,
    required this.emergencyContact,
  });

  factory ParentProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return ParentProfile(
      id: json['id'] as int,
      userId: user['id'] as int,
      firstName: (user['first_name'] ?? '') as String,
      lastName: (user['last_name'] ?? '') as String,
      email: (user['email'] ?? '') as String,
      phone: (user['phone'] ?? '') as String,
      address: (json['address'] ?? '') as String,
      emergencyContact: (json['emergency_contact'] ?? '') as String,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
}

class Bracelet {
  final int id;
  final String serialNumber;
  final String nickname;
  final String firmwareVersion;
  final int? babyId;
  final String? babyName;
  final double? batteryLevel;
  final DateTime? lastSeenAt;
  final String status;

  const Bracelet({
    required this.id,
    required this.serialNumber,
    this.nickname = '',
    required this.firmwareVersion,
    this.babyId,
    this.babyName,
    this.batteryLevel,
    this.lastSeenAt,
    required this.status,
  });

  /// Nickname if set, otherwise the serial number — what the UI should show.
  String get displayName => nickname.isNotEmpty ? nickname : serialNumber;

  factory Bracelet.fromJson(Map<String, dynamic> json) => Bracelet(
        id: json['id'] as int,
        serialNumber: json['serial_number'] as String,
        nickname: (json['nickname'] ?? '') as String,
        firmwareVersion: (json['firmware_version'] ?? '') as String,
        babyId: json['baby'] as int?,
        babyName: json['baby_name'] as String?,
        batteryLevel: (json['battery_level'] as num?)?.toDouble(),
        lastSeenAt: json['last_seen_at'] == null
            ? null
            : DateTime.parse(json['last_seen_at'] as String),
        status: json['status'] as String,
      );
}

/// One pair/unpair cycle for a bracelet (Section 5: "history of paired
/// bracelets").
class Pairing {
  final int id;
  final int braceletId;
  final int babyId;
  final String babyName;
  final DateTime pairedAt;
  final DateTime? unpairedAt;

  const Pairing({
    required this.id,
    required this.braceletId,
    required this.babyId,
    required this.babyName,
    required this.pairedAt,
    this.unpairedAt,
  });

  bool get isActive => unpairedAt == null;

  factory Pairing.fromJson(Map<String, dynamic> json) => Pairing(
        id: json['id'] as int,
        braceletId: json['bracelet'] as int,
        babyId: json['baby'] as int,
        babyName: (json['baby_name'] ?? '') as String,
        pairedAt: DateTime.parse(json['paired_at'] as String),
        unpairedAt: json['unpaired_at'] == null
            ? null
            : DateTime.parse(json['unpaired_at'] as String),
      );
}

class Measurement {
  final int? id; // null while local-only (not yet synced)
  final int braceletId;
  final double? heartRate;
  final double? temperature;
  final double? spo2;
  final Map<String, dynamic>? movement;
  final double? battery;
  final bool skinContact;
  final DateTime recordedAt;
  final bool synced;

  const Measurement({
    this.id,
    required this.braceletId,
    this.heartRate,
    this.temperature,
    this.spo2,
    this.movement,
    this.battery,
    this.skinContact = true,
    required this.recordedAt,
    this.synced = false,
  });

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
        id: json['id'] as int?,
        braceletId: json['bracelet'] as int,
        heartRate: (json['heart_rate'] as num?)?.toDouble(),
        temperature: (json['temperature'] as num?)?.toDouble(),
        spo2: (json['spo2'] as num?)?.toDouble(),
        movement: json['movement'] as Map<String, dynamic>?,
        battery: (json['battery'] as num?)?.toDouble(),
        skinContact: (json['skin_contact'] ?? true) as bool,
        recordedAt: DateTime.parse(json['recorded_at'] as String),
        synced: true,
      );

  Map<String, dynamic> toIngestJson() => {
        'bracelet': braceletId,
        'heart_rate': heartRate,
        'temperature': temperature,
        'spo2': spo2,
        'movement': movement,
        'battery': battery,
        'skin_contact': skinContact,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
      };
}

class Alert {
  final int id;
  final int babyId;
  final String babyName;
  final String type;
  final String severity;
  final String message;
  final double? value;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;
  final bool autoResolvesOnAcknowledge;
  final String disclaimer;

  const Alert({
    required this.id,
    required this.babyId,
    required this.babyName,
    required this.type,
    required this.severity,
    required this.message,
    this.value,
    required this.triggeredAt,
    this.resolvedAt,
    this.resolvedByName,
    this.acknowledgedAt,
    this.acknowledgedByName,
    this.autoResolvesOnAcknowledge = false,
    required this.disclaimer,
  });

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as int,
        babyId: json['baby'] as int,
        babyName: (json['baby_name'] ?? '') as String,
        type: json['type'] as String,
        severity: json['severity'] as String,
        message: json['message'] as String,
        value: (json['value'] as num?)?.toDouble(),
        triggeredAt: DateTime.parse(json['triggered_at'] as String),
        resolvedAt: json['resolved_at'] == null
            ? null
            : DateTime.parse(json['resolved_at'] as String),
        resolvedByName: json['resolved_by_name'] as String?,
        acknowledgedAt: json['acknowledged_at'] == null
            ? null
            : DateTime.parse(json['acknowledged_at'] as String),
        acknowledgedByName: json['acknowledged_by_name'] as String?,
        autoResolvesOnAcknowledge:
            (json['auto_resolves_on_acknowledge'] as bool?) ?? false,
        disclaimer: (json['disclaimer'] ?? '') as String,
      );

  bool get isActive => resolvedAt == null;
}

class AppNotification {
  final int id;
  final int? alertId;
  final String category; // alert | bracelet | medical | system
  final String title;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    this.alertId,
    this.category = 'system',
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        alertId: json['alert'] as int?,
        category: (json['category'] ?? 'system') as String,
        title: json['title'] as String,
        body: json['body'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String),
      );

  bool get isUnread => readAt == null;
}
