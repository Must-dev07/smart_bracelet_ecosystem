/// Widget test for Live Monitoring: disconnected state shows the pairing CTA;
/// connected state renders vital tiles from the BLE stream.
import 'dart:async';

import 'package:bracelet_monitor/providers/providers.dart';
import 'package:bracelet_monitor/repositories/repositories.dart';
import 'package:bracelet_monitor/screens/live_monitoring_screen.dart';
import 'package:bracelet_monitor/services/ble_service.dart';
import 'package:bracelet_monitor/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBleService extends Mock implements BleService {}

class MockSyncService extends Mock implements SyncService {}

class MockMeasurementRepository extends Mock implements MeasurementRepository {}

Widget _wrap(BleService ble) {
  final sync = MockSyncService();
  when(() => sync.start(interval: any(named: 'interval'))).thenReturn(null);
  when(() => sync.syncOnce()).thenAnswer((_) async => 0);
  final repo = MockMeasurementRepository();
  return ProviderScope(
    overrides: [
      bleServiceProvider.overrideWithValue(ble),
      syncServiceProvider.overrideWithValue(sync),
      measurementRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(home: LiveMonitoringScreen()),
  );
}

void main() {
  testWidgets('disconnected: shows pair CTA', (tester) async {
    final ble = MockBleService();
    when(() => ble.status)
        .thenAnswer((_) => Stream.value(BleStatus.disconnected));
    when(() => ble.vitals).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_wrap(ble));
    await tester.pump();

    expect(find.text('No bracelet connected.'), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth_searching), findsOneWidget);
  });

  testWidgets('connected: renders live vitals', (tester) async {
    final ble = MockBleService();
    final vitals = LiveVitals(
      heartRate: 128,
      temperature: 37.1,
      spo2: 98,
      battery: 82,
      timestamp: DateTime.now(),
    );
    when(() => ble.status)
        .thenAnswer((_) => Stream.value(BleStatus.connected));
    when(() => ble.vitals).thenAnswer((_) => Stream.value(vitals));

    await tester.pumpWidget(_wrap(ble));
    await tester.pump();
    await tester.pump();

    expect(find.text('128'), findsOneWidget);   // HR
    expect(find.text('37.1'), findsOneWidget);  // temp
    expect(find.text('98'), findsOneWidget);    // SpO2
  });
}
