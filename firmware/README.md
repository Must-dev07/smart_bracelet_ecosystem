# Smart Bracelet Firmware (ESP32)

C++ firmware for the newborn-monitoring bracelet: samples vitals, exposes
them over a BLE GATT **Health Service**, buffers offline, manages power.

> **Disclaimer** — This device flags abnormal readings for caregiver or
> medical follow-up. It is **not** a medical diagnosis device.

## Architecture

```
firmware/
├── platformio.ini              # board, framework, library deps
├── include/                    # PURE C++ (no Arduino) — host-testable
│   ├── config/config.h         # UUIDs, pins, thresholds, cadences
│   ├── core/sample.h           # Sample struct + float32 LE encoding
│   ├── core/ring_buffer.h      # offline buffer (overwrite-oldest)
│   ├── core/battery_model.h    # LiPo mV → % piecewise model + EMA
│   └── core/vitals_filter.h    # plausibility windows + median filter
├── src/
│   ├── main.cpp                # sampling loop, buffering, watchdog, sleep
│   ├── ble/health_service.h    # GATT server (bonded + encrypted)
│   └── sensors/                # pluggable SensorDriver implementations
│       ├── max30102_driver.h   # HR + SpO2 (I2C)
│       ├── temperature_driver.h# DS18B20 skin temp (1-Wire)
│       ├── mpu6050_driver.h    # accel/gyro + movement magnitude (I2C)
│       ├── battery_driver.h    # ADC + divider → SoC %
│       └── skin_contact_driver.h # debounced contact detect
└── test_host/test_main.cpp     # g++ unit tests (no hardware)
```

**Pluggable sensors** — every sensor implements `sb::SensorDriver`
(`include/sensors/sensor_driver.h`). To add one: write a driver, append it
to the `g_sensors[]` registry in `main.cpp`. Nothing else changes.

## BLE contract (must match the Flutter app)

Service `8e7f1a20-5b3c-4d2e-9f10-0a1b2c3d4e5f` — all payloads little-endian:

| Characteristic | UUID suffix | Props | Payload |
|---|---|---|---|
| Heart rate | `…1a21` | read/notify | float32 (bpm) |
| Temperature | `…1a22` | read/notify | float32 (°C) |
| SpO2 | `…1a23` | read/notify | float32 (%) |
| Movement | `…1a24` | read/notify | 7×float32: ax ay az gx gy gz magnitude |
| Battery | `…1a25` | read/notify | float32 (%) |
| Command | `…1a26` | write | UTF-8: `mode:normal` \| `mode:powersave` \| `flush` |
| Device info | `…1a27` | read | `fw=<version>;serial=<serial>` |

Security: BLE bonding (Secure Connections, Just Works), encrypted
characteristic access. Advertising resumes automatically on disconnect.

## Behaviour

- **Sampling**: every 5 s (normal) / 30 s (power-save via command).
- **Connected**: publishes each sample as notifications; drains any
  offline backlog first (oldest → newest).
- **Disconnected**: samples go into a 720-slot ring buffer (~1 h);
  when full the *oldest* is dropped.
- **Watchdog**: 30 s task watchdog reboots a stalled loop.
- **Critical battery** (≤5 %): sensors powered down, deep sleep 5 min
  cycles until recharged.
- **Degraded mode**: a sensor failing `begin()` logs `FAILED` and is
  skipped; the rest keep working.

## Wiring (ESP32 DevKit)

| Module | Pin(s) |
|---|---|
| MAX30102 (I2C) | SDA=21, SCL=22, VIN=3V3, GND |
| MPU6050 (I2C) | SDA=21, SCL=22 (shared bus), VCC=3V3, GND |
| DS18B20 | DATA=4 (4.7 kΩ pull-up to 3V3), VDD=3V3, GND |
| Battery sense | Battery+ → 100 kΩ → **GPIO34** → 100 kΩ → GND |
| Skin contact | electrode/touch pad → **GPIO32** (internal pull-down) |

## Build & flash (your machine — not the sandbox)

```bash
pip install platformio          # once
cd firmware
pio run                         # compile
pio run -t upload               # flash over USB
pio device monitor -b 115200    # watch logs
```

The device advertises as `SB-BRACELET-<serial>`; the mobile app scans by
service UUID, bonds, then registers the bracelet using the serial from the
device-info characteristic.

## Host-side tests (run in CI / sandbox — no hardware)

```bash
cd firmware/test_host
g++ -std=c++17 -I../include -Wall -Wextra -Werror -o test_host test_main.cpp
./test_host       # 184 checks, 0 failure(s)
```

Covers the float32 BLE payload contract, ring-buffer semantics (order,
overwrite-oldest, wrap-around), the battery model (anchors, monotonicity,
interpolation, EMA), plausibility windows and the median spike filter.
