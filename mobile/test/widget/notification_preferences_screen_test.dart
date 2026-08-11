/// Widget tests for notification preferences (Section 11): alert is always
/// shown as locked/on; the three mutable categories toggle via the repo.
import 'package:bracelet_monitor/providers/providers.dart';
import 'package:bracelet_monitor/repositories/repositories.dart';
import 'package:bracelet_monitor/screens/notification_preferences_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationRepository extends Mock implements NotificationRepository {}

Widget _wrap(NotificationRepository repo) => ProviderScope(
      overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: NotificationPreferencesScreen()),
    );

void main() {
  late MockNotificationRepository repo;

  setUp(() => repo = MockNotificationRepository());

  testWidgets('shows all categories with alert locked on', (tester) async {
    when(() => repo.getPreferences()).thenAnswer(
        (_) async => {'bracelet': true, 'medical': true, 'system': true});

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Bracelet'), findsOneWidget);
    expect(find.text('Medical'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    // Three mutable switches (alert has no Switch, just a lock icon).
    expect(find.byType(SwitchListTile), findsNWidgets(3));
  });

  testWidgets('toggling bracelet off calls updatePreference', (tester) async {
    when(() => repo.getPreferences()).thenAnswer(
        (_) async => {'bracelet': true, 'medical': true, 'system': true});
    when(() => repo.updatePreference('bracelet', false)).thenAnswer(
        (_) async => {'bracelet': false, 'medical': true, 'system': true});

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Bracelet'));
    await tester.pump();

    verify(() => repo.updatePreference('bracelet', false)).called(1);
  });
}
