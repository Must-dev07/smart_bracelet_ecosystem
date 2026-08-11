/// Pure-Dart model (de)serialization tests.
import 'package:bracelet_monitor/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Measurement round-trip to ingest JSON', () {
    final m = Measurement(
      braceletId: 3,
      heartRate: 132.5,
      temperature: 36.9,
      spo2: 97,
      movement: const {
        'accel': [0.1, 0.2, 9.8],
        'gyro': [0.0, 0.0, 0.0],
        'magnitude': 0.4,
      },
      battery: 76,
      recordedAt: DateTime.utc(2026, 7, 20, 10, 30),
    );
    final json = m.toIngestJson();
    expect(json['bracelet'], 3);
    expect(json['heart_rate'], 132.5);
    expect(json['recorded_at'], '2026-07-20T10:30:00.000Z');
    expect(json['skin_contact'], true);
  });

  test('Alert.fromJson parses disclaimer and activity', () {
    final alert = Alert.fromJson({
      'id': 1,
      'baby': 2,
      'baby_name': 'Léa',
      'type': 'low_oxygen',
      'severity': 'critical',
      'message': 'SpO2 flagged for follow-up.',
      'value': 88.0,
      'triggered_at': '2026-07-20T10:00:00Z',
      'resolved_at': null,
      'acknowledged_at': null,
      'disclaimer': 'This alert ... is not a medical diagnosis.',
    });
    expect(alert.isActive, true);
    expect(alert.disclaimer, contains('not a medical diagnosis'));
  });

  test('User full name', () {
    const u = User(
        id: 1, email: 'a@b.c', firstName: 'Marie', lastName: 'Dupont', role: 'parent');
    expect(u.fullName, 'Marie Dupont');
  });

  test('User.fromJson decodes doctor/parent profile ids', () {
    final u = User.fromJson({
      'id': 5,
      'email': 'doc@example.com',
      'first_name': 'A',
      'last_name': 'B',
      'role': 'doctor',
      'phone': '',
      'doctor_profile_id': 42,
      'parent_profile_id': null,
    });
    expect(u.doctorProfileId, 42);
    expect(u.parentProfileId, null);
  });

  test('Baby.copyWith clears assignedDoctor explicitly', () {
    final baby = Baby(
      id: 1,
      name: 'Emma',
      birthDate: DateTime.utc(2026, 1, 1),
      weightGrams: 3200,
      gender: 'female',
      assignedDoctor: 7,
    );
    final cleared = baby.copyWith(clearAssignedDoctor: true);
    expect(cleared.assignedDoctor, null);
    expect(cleared.name, 'Emma'); // other fields preserved

    final reassigned = baby.copyWith(assignedDoctor: 9);
    expect(reassigned.assignedDoctor, 9);
  });

  test('Alert.fromJson decodes acknowledge/resolve audit trail', () {
    final alert = Alert.fromJson({
      'id': 1,
      'baby': 2,
      'baby_name': 'Léa',
      'type': 'high_temp',
      'severity': 'critical',
      'message': 'Temp flagged',
      'value': 38.4,
      'triggered_at': '2026-07-20T10:00:00Z',
      'resolved_at': null,
      'resolved_by_name': null,
      'acknowledged_at': '2026-07-20T10:05:00Z',
      'acknowledged_by_name': 'Marie Dupont',
      'auto_resolves_on_acknowledge': false,
      'disclaimer': '...',
    });
    expect(alert.isActive, true); // acknowledged but NOT auto-resolved
    expect(alert.acknowledgedByName, 'Marie Dupont');
    expect(alert.autoResolvesOnAcknowledge, false);
  });

  test('AppNotification.fromJson decodes category, defaults to system', () {
    final withCategory = AppNotification.fromJson({
      'id': 1, 'alert': null, 'category': 'bracelet', 'title': 'Paired',
      'body': '...', 'status': 'sent', 'created_at': '2026-07-20T10:00:00Z',
      'read_at': null,
    });
    expect(withCategory.category, 'bracelet');
    expect(withCategory.isUnread, true);

    final withoutCategory = AppNotification.fromJson({
      'id': 2, 'alert': null, 'title': 'X', 'body': 'Y', 'status': 'sent',
      'created_at': '2026-07-20T10:00:00Z', 'read_at': '2026-07-20T11:00:00Z',
    });
    expect(withoutCategory.category, 'system');
    expect(withoutCategory.isUnread, false);
  });

  test('MedicalHistoryEntry.fromJson round-trip', () {
    final entry = MedicalHistoryEntry.fromJson({
      'id': 1,
      'title': 'Vaccination — Hep B',
      'details': 'First dose administered.',
      'recorded_by': 4,
      'supersedes': null,
      'created_at': '2026-07-20T10:00:00Z',
    });
    expect(entry.title, 'Vaccination — Hep B');
    expect(entry.recordedBy, 4);
    expect(entry.supersedes, null);
  });

  test('DoctorProfile.fromJson flattens nested user', () {
    final d = DoctorProfile.fromJson({
      'id': 3,
      'user': {'id': 10, 'first_name': 'Jean', 'last_name': 'Martin', 'email': 'j@m.c', 'phone': ''},
      'license_number': 'LIC-001',
      'specialty': 'Pediatrics',
    });
    expect(d.id, 3);
    expect(d.userId, 10);
    expect(d.fullName, 'Jean Martin');
    expect(d.specialty, 'Pediatrics');
  });

  test('ParentProfile.fromJson flattens nested user', () {
    final p = ParentProfile.fromJson({
      'id': 6,
      'user': {'id': 11, 'first_name': 'Sophie', 'last_name': 'Bernard', 'email': 's@b.c', 'phone': ''},
      'address': '10 Rue de Paris',
      'emergency_contact': '+33...',
    });
    expect(p.fullName, 'Sophie Bernard');
    expect(p.address, '10 Rue de Paris');
  });

  test('DoctorAssignmentRequest.fromJson decodes status/isPending', () {
    final pending = DoctorAssignmentRequest.fromJson({
      'id': 1, 'baby': 2, 'baby_name': 'Léa', 'doctor': 3, 'doctor_name': 'Dr X',
      'doctor_specialty': 'Pediatrics', 'requested_by': 5, 'status': 'pending',
      'note': '', 'created_at': '2026-07-20T10:00:00Z', 'responded_at': null,
    });
    expect(pending.isPending, true);

    final accepted = DoctorAssignmentRequest.fromJson({
      'id': 2, 'baby': 2, 'baby_name': 'Léa', 'doctor': 3, 'doctor_name': 'Dr X',
      'doctor_specialty': 'Pediatrics', 'requested_by': 5, 'status': 'accepted',
      'note': '', 'created_at': '2026-07-20T10:00:00Z',
      'responded_at': '2026-07-20T11:00:00Z',
    });
    expect(accepted.isPending, false);
  });
}
