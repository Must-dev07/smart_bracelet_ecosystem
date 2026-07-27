#pragma once
/**
 * Global firmware configuration — Smart Bracelet (newborn monitoring).
 *
 * BLE UUIDs are the canonical contract shared with the Flutter app
 * (mobile/lib/core/app_config.dart) — DO NOT change one side only.
 */

// ---------------------------------------------------------------- identity
#define FIRMWARE_VERSION "1.0.0"
// Serial number is derived from the ESP32 efuse MAC at boot (see main.cpp).
#define DEVICE_NAME_PREFIX "SB-BRACELET-"

// ---------------------------------------------------------------- BLE GATT
#define UUID_HEALTH_SERVICE "8e7f1a20-5b3c-4d2e-9f10-0a1b2c3d4e5f"
#define UUID_CHAR_HEART_RATE "8e7f1a21-5b3c-4d2e-9f10-0a1b2c3d4e5f"
#define UUID_CHAR_TEMPERATURE "8e7f1a22-5b3c-4d2e-9f10-0a1b2c3d4e5f"
#define UUID_CHAR_SPO2 "8e7f1a23-5b3c-4d2e-9f10-0a1b2c3d4e5f"
#define UUID_CHAR_MOVEMENT "8e7f1a24-5b3c-4d2e-9f10-0a1b2c3d4e5f"
#define UUID_CHAR_BATTERY "8e7f1a25-5b3c-4d2e-9f10-0a1b2c3d4e5f"
#define UUID_CHAR_COMMAND "8e7f1a26-5b3c-4d2e-9f10-0a1b2c3d4e5f"
#define UUID_CHAR_DEVICE_INFO "8e7f1a27-5b3c-4d2e-9f10-0a1b2c3d4e5f"

// ---------------------------------------------------------------- sampling
// Milliseconds between sensor sampling rounds (normal mode).
#define SAMPLE_INTERVAL_MS 5000
// Notification interval when a central is connected.
#define NOTIFY_INTERVAL_MS 5000
// Power-save mode multiplier (command "mode:powersave").
#define POWERSAVE_MULTIPLIER 6  // 30 s effective interval

// ---------------------------------------------------------------- buffering
// Samples retained while disconnected (ring buffer, oldest overwritten).
#define BUFFER_CAPACITY 720  // 1 h at 5 s cadence

// ---------------------------------------------------------------- power
#define BATTERY_ADC_PIN 34
// Voltage divider: battery -- R1 -- ADC -- R2 -- GND (R1 = R2 = 100k).
#define BATTERY_DIVIDER_RATIO 2.0f
#define BATTERY_MIN_MV 3300.0f  // 0 %
#define BATTERY_MAX_MV 4200.0f  // 100 %
#define BATTERY_CRITICAL_PCT 5.0f
// Deep-sleep duration when battery is critical (seconds).
#define CRITICAL_SLEEP_SECONDS 300

// ---------------------------------------------------------------- pins
#define I2C_SDA_PIN 21
#define I2C_SCL_PIN 22
#define ONE_WIRE_PIN 4       // DS18B20 skin temperature
#define SKIN_CONTACT_PIN 32  // capacitive/galvanic contact detect (digital)

// ---------------------------------------------------------------- watchdog
#define WDT_TIMEOUT_SECONDS 30
