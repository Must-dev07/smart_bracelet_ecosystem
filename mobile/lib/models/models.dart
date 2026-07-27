/// Domain entities mirroring the backend API payloads.
/// Pure Dart (no Flutter imports) so they are trivially unit-testable.
library models;

class User {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // parent | doctor | admin

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        email: json['email'] as String,
        firstName: (json['first_name'] ?? '') as String,
        lastName: (json['last_name'] ?? '') as String,
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
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

  const Baby({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.weightGrams,
    required this.gender,
    this.assignedDoctor,
  });

  factory Baby.fromJson(Map<String, dynamic> json) => Baby(
        id: json['id'] as int,
        name: json['name'] as String,
        birthDate: DateTime.parse(json['birth_date'] as String),
        weightGrams: json['weight_grams'] as int,
        gender: json['gender'] as String,
        assignedDoctor: json['assigned_doctor'] as int?,
      );
}

class Bracelet {
  final int id;
  final String serialNumber;
  final String firmwareVersion;
  final int? babyId;
  final double? batteryLevel;
  final String status;

  const Bracelet({
    required this.id,
    required this.serialNumber,
    required this.firmwareVersion,
    this.babyId,
    this.batteryLevel,
    required this.status,
  });

  factory Bracelet.fromJson(Map<String, dynamic> json) => Bracelet(
        id: json['id'] as int,
        serialNumber: json['serial_number'] as String,
        firmwareVersion: (json['firmware_version'] ?? '') as String,
        babyId: json['baby'] as int?,
        batteryLevel: (json['battery_level'] as num?)?.toDouble(),
        status: json['status'] as String,
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
  final DateTime? acknowledgedAt;
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
    this.acknowledgedAt,
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
        acknowledgedAt: json['acknowledged_at'] == null
            ? null
            : DateTime.parse(json['acknowledged_at'] as String),
        disclaimer: (json['disclaimer'] ?? '') as String,
      );

  bool get isActive => resolvedAt == null;
}

class AppNotification {
  final int id;
  final int? alertId;
  final String title;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    this.alertId,
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
