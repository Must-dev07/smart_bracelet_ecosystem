/// BLE service: scan → connect → discover Health Service → subscribe to all
/// vitals characteristics → stream parsed readings. Handles auto-reconnect
/// with exponential backoff and exposes a connection-status stream for the UI.
///
/// Wire formats (must match firmware/ble/health_service.cpp):
///   heart_rate : float32 LE (bpm)
///   temperature: float32 LE (°C)
///   spo2       : float32 LE (%)
///   movement   : 7 x float32 LE (ax,ay,az,gx,gy,gz,magnitude)
///   battery    : float32 LE (%)
///   device_info: UTF-8 string "fw=<version>;serial=<sn>"
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/app_config.dart';
import '../models/models.dart';

enum BleStatus { disconnected, scanning, connecting, connected, reconnecting }

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

class BleService {
  final _statusCtrl = StreamController<BleStatus>.broadcast();
  final _vitalsCtrl = StreamController<LiveVitals>.broadcast();

  Stream<BleStatus> get status => _statusCtrl.stream;
  Stream<LiveVitals> get vitals => _vitalsCtrl.stream;

  BluetoothDevice? _device;
  LiveVitals _current = LiveVitals(timestamp: DateTime.now());
  StreamSubscription<BluetoothConnectionState>? _connSub;
  final List<StreamSubscription> _charSubs = [];
  int _reconnectAttempt = 0;
  bool _userDisconnected = false;
  String firmwareVersion = '';
  String deviceSerial = '';

  /// Scan for devices advertising the Health Service.
  Future<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 8)}) async {
    _statusCtrl.add(BleStatus.scanning);
    final results = <ScanResult>[];
    final sub = FlutterBluePlus.scanResults.listen((batch) {
      for (final r in batch) {
        if (!results.any((e) => e.device.remoteId == r.device.remoteId)) {
          results.add(r);
        }
      }
    });
    await FlutterBluePlus.startScan(
      withServices: [Guid(AppConfig.healthServiceUuid)],
      timeout: timeout,
    );
    await FlutterBluePlus.isScanning.where((s) => s == false).first;
    await sub.cancel();
    _statusCtrl.add(_device == null ? BleStatus.disconnected : BleStatus.connected);
    return results;
  }

  Future<void> connect(BluetoothDevice device) async {
    _userDisconnected = false;
    _device = device;
    _statusCtrl.add(BleStatus.connecting);
    // bondingInstructions: createBond persists the bond on Android; on iOS the
    // OS manages pairing automatically when an encrypted characteristic is read.
    await device.connect(timeout: const Duration(seconds: 15));
    try {
      await device.createBond();
    } catch (_) {
      // iOS or already bonded — safe to ignore.
    }
    _reconnectAttempt = 0;
    await _subscribeAll(device);
    _statusCtrl.add(BleStatus.connected);

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && !_userDisconnected) {
        _scheduleReconnect();
      }
    });
  }

  Future<void> _subscribeAll(BluetoothDevice device) async {
    for (final s in _charSubs) {
      await s.cancel();
    }
    _charSubs.clear();

    final services = await device.discoverServices();
    final health = services.firstWhere(
      (s) => s.uuid == Guid(AppConfig.healthServiceUuid),
      orElse: () => throw StateError('Health Service not found on device'),
    );

    for (final c in health.characteristics) {
      final uuid = c.uuid.str128.toLowerCase();
      if (uuid == AppConfig.deviceInfoCharUuid) {
        final bytes = await c.read();
        _parseDeviceInfo(bytes);
        continue;
      }
      if (uuid == AppConfig.commandCharUuid) continue; // write-only
      if (!c.properties.notify) continue;
      await c.setNotifyValue(true);
      _charSubs.add(c.onValueReceived.listen((bytes) => _onData(uuid, bytes)));
    }
  }

  void _parseDeviceInfo(List<int> bytes) {
    final info = String.fromCharCodes(bytes);
    for (final part in info.split(';')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        if (kv[0] == 'fw') firmwareVersion = kv[1];
        if (kv[0] == 'serial') deviceSerial = kv[1];
      }
    }
  }

  double _f32(List<int> bytes, [int offset = 0]) =>
      ByteData.sublistView(Uint8List.fromList(bytes))
          .getFloat32(offset, Endian.little);

  void _onData(String uuid, List<int> bytes) {
    if (bytes.isEmpty) return;
    if (uuid == AppConfig.hrCharUuid) {
      _current = _current.copyWith(heartRate: _f32(bytes));
    } else if (uuid == AppConfig.tempCharUuid) {
      _current = _current.copyWith(temperature: _f32(bytes));
    } else if (uuid == AppConfig.spo2CharUuid) {
      _current = _current.copyWith(spo2: _f32(bytes));
    } else if (uuid == AppConfig.batteryCharUuid) {
      _current = _current.copyWith(battery: _f32(bytes));
    } else if (uuid == AppConfig.movementCharUuid && bytes.length >= 28) {
      _current = _current.copyWith(movement: {
        'accel': [_f32(bytes, 0), _f32(bytes, 4), _f32(bytes, 8)],
        'gyro': [_f32(bytes, 12), _f32(bytes, 16), _f32(bytes, 20)],
        'magnitude': _f32(bytes, 24),
      });
    } else {
      return;
    }
    _vitalsCtrl.add(_current);
  }

  /// Exponential backoff: 1s, 2s, 4s … capped at 60s, forever until the user
  /// explicitly disconnects.
  void _scheduleReconnect() {
    if (_userDisconnected || _device == null) return;
    _statusCtrl.add(BleStatus.reconnecting);
    final delay = Duration(seconds: min(60, pow(2, _reconnectAttempt).toInt()));
    _reconnectAttempt++;
    Timer(delay, () async {
      if (_userDisconnected || _device == null) return;
      try {
        await connect(_device!);
      } catch (_) {
        _scheduleReconnect();
      }
    });
  }

  /// Send a command (rename / reset / OTA-trigger) to the command characteristic.
  Future<void> sendCommand(String command) async {
    final device = _device;
    if (device == null) throw StateError('Not connected');
    final services = await device.discoverServices();
    final health =
        services.firstWhere((s) => s.uuid == Guid(AppConfig.healthServiceUuid));
    final cmd = health.characteristics
        .firstWhere((c) => c.uuid == Guid(AppConfig.commandCharUuid));
    await cmd.write(command.codeUnits, withoutResponse: false);
  }

  Future<void> disconnect() async {
    _userDisconnected = true;
    for (final s in _charSubs) {
      await s.cancel();
    }
    _charSubs.clear();
    await _connSub?.cancel();
    await _device?.disconnect();
    _device = null;
    _statusCtrl.add(BleStatus.disconnected);
  }

  /// Logout: drop connection AND remove the OS bond (Section 5.3 spec).
  Future<void> clearBond() async {
    final device = _device;
    await disconnect();
    try {
      await device?.removeBond();
    } catch (_) {
      // iOS: bonds are OS-managed; nothing to do.
    }
  }

  void dispose() {
    _statusCtrl.close();
    _vitalsCtrl.close();
  }
}
