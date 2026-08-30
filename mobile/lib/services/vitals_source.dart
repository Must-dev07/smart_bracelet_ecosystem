// Section 22: BLE Simulator and Real BLE Device both implement this one
// interface. Every screen (pairing, live monitoring, bracelet info) talks
// to a `VitalsSource`, never to `flutter_blue_plus` or the simulator
// directly — so which implementation is in use is purely a dependency-
// injection choice made in one place (`providers.dart`'s
// `bleServiceProvider`, driven by `useSimulatedBleProvider`), not something
// any screen needs to know about.
import 'dart:async';

import '../models/models.dart';

enum BleStatus { disconnected, scanning, connecting, connected, reconnecting }

/// A vitals reading in progress — fields fill in as characteristics/simulated
/// ticks arrive, same shape regardless of source.
class LiveVitals {
  final double? heartRate;
  final double? temperature;
  final double? spo2;
  final Map<String, dynamic>? movement;
  final double? battery;
  final bool skinContact;
  final DateTime timestamp;

  const LiveVitals({
    this.heartRate,
    this.temperature,
    this.spo2,
    this.movement,
    this.battery,
    this.skinContact = true,
    required this.timestamp,
  });

  LiveVitals copyWith({
    double? heartRate,
    double? temperature,
    double? spo2,
    Map<String, dynamic>? movement,
    double? battery,
    bool? skinContact,
  }) =>
      LiveVitals(
        heartRate: heartRate ?? this.heartRate,
        temperature: temperature ?? this.temperature,
        spo2: spo2 ?? this.spo2,
        movement: movement ?? this.movement,
        battery: battery ?? this.battery,
        skinContact: skinContact ?? this.skinContact,
        timestamp: DateTime.now(),
      );

  Measurement toMeasurement(int braceletId) => Measurement(
        braceletId: braceletId,
        heartRate: heartRate,
        temperature: temperature,
        spo2: spo2,
        movement: movement,
        battery: battery,
        skinContact: skinContact,
        recordedAt: timestamp,
      );
}

/// A device found during scan — deliberately generic (no flutter_blue_plus
/// types leak past this point) so the same pairing UI works for a real
/// nearby bracelet or a simulated one.
class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  const DiscoveredDevice({required this.id, required this.name, this.rssi = 0});
}

abstract class VitalsSource {
  Stream<BleStatus> get status;
  Stream<LiveVitals> get vitals;

  String get firmwareVersion;
  String get deviceSerial;

  // --- Connection telemetry (Section 6) ---
  int get reconnectAttempts;
  DateTime? get connectedSince;
  DateTime? get lastPacketAt;
  int get packetsPerMinute;

  Future<List<DiscoveredDevice>> scan({Duration timeout});
  Future<void> connect(DiscoveredDevice device);
  Future<void> sendCommand(String command);
  Future<void> disconnect();

  /// Drop the connection AND any OS-level pairing/bond, where applicable.
  Future<void> clearBond();

  void dispose();
}
