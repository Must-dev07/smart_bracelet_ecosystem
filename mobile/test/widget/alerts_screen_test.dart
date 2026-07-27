/// Widget tests for the Alerts screen (spec 5.4) with mocked repository.
import 'package:bracelet_monitor/models/models.dart';
import 'package:bracelet_monitor/providers/providers.dart';
import 'package:bracelet_monitor/repositories/repositories.dart';
import 'package:bracelet_monitor/screens/alerts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAlertRepository extends Mock implements AlertRepository {}

Widget _wrap(Widget child, AlertRepository repo) => ProviderScope(
      overrides: [alertRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: child),
    );

void main() {
  late MockAlertRepository repo;

  setUp(() => repo = MockAlertRepository());

  final sample = Alert(
    id: 1,
    babyId: 1,
    babyName: 'Léa',
    type: 'high_temp',
    severity: 'critical',
    message: 'Temperature reading 39.0°C flagged for follow-up.',
    value: 39.0,
    triggeredAt: DateTime(2026, 7, 20, 10),
    disclaimer: 'This alert flags a reading. It is not a medical diagnosis.',
  );

  testWidgets('shows alerts with severity badge and disclaimer',
      (tester) async {
    when(() => repo.list(status: any(named: 'status'), babyId: any(named: 'babyId')))
        .thenAnswer((_) async => [sample]);

    await tester.pumpWidget(_wrap(const AlertsScreen(), repo));
    await tester.pumpAndSettle();

    expect(find.text('high temp'), findsOneWidget);
    expect(find.text('CRITICAL'), findsOneWidget);
    // Non-diagnostic disclaimer must be visible (Section 0 rule 10).
    expect(find.textContaining('does not provide medical diagnoses'),
        findsOneWidget);
  });

  testWidgets('shows empty state when no alerts', (tester) async {
    when(() => repo.list(status: any(named: 'status'), babyId: any(named: 'babyId')))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(const AlertsScreen(), repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('No alerts'), findsOneWidget);
  });
}
