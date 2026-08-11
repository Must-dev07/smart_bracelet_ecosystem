/// Widget tests for the doctor's pending patient-requests inbox (Section 3).
import 'package:bracelet_monitor/models/models.dart';
import 'package:bracelet_monitor/providers/providers.dart';
import 'package:bracelet_monitor/repositories/repositories.dart';
import 'package:bracelet_monitor/screens/doctor_requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDoctorAssignmentRepository extends Mock
    implements DoctorAssignmentRepository {}

Widget _wrap(DoctorAssignmentRepository repo) => ProviderScope(
      overrides: [doctorAssignmentRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: DoctorRequestsScreen()),
    );

void main() {
  late MockDoctorAssignmentRepository repo;

  setUp(() => repo = MockDoctorAssignmentRepository());

  final sample = DoctorAssignmentRequest(
    id: 1,
    babyId: 2,
    babyName: 'Emma',
    doctorId: 3,
    doctorName: 'Dr. Martin',
    doctorSpecialty: 'Pediatrics',
    status: 'pending',
    note: 'Recommended by our GP.',
    createdAt: DateTime(2026, 7, 20, 10),
  );

  testWidgets('shows pending requests with note', (tester) async {
    when(() => repo.inbox(status: any(named: 'status')))
        .thenAnswer((_) async => [sample]);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Emma'), findsOneWidget);
    expect(find.text('Recommended by our GP.'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('shows empty state when no pending requests', (tester) async {
    when(() => repo.inbox(status: any(named: 'status')))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('No pending patient requests'), findsOneWidget);
  });

  testWidgets('tapping Accept calls repository.accept', (tester) async {
    when(() => repo.inbox(status: any(named: 'status')))
        .thenAnswer((_) async => [sample]);
    when(() => repo.accept(1)).thenAnswer((_) async => sample);

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept'));
    await tester.pump();

    verify(() => repo.accept(1)).called(1);
  });
}
