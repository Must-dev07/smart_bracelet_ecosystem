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
}
