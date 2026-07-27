/**
 * Smart Bracelet firmware — main loop.
 *
 * Responsibilities:
 *  - initialise the pluggable sensor registry (SensorDriver interface)
 *  - sample vitals every SAMPLE_INTERVAL_MS (× POWERSAVE_MULTIPLIER in
 *    power-save mode)
 *  - publish over the BLE Health Service when a phone is connected
 *  - buffer samples in a ring buffer while disconnected, flushing the
 *    backlog (oldest first) on reconnect or on a "flush" command
 *  - feed a hardware watchdog; deep-sleep on critical battery
 *
 * Commands (BLE command characteristic, UTF-8):
 *  "mode:normal"     → 5 s cadence
 *  "mode:powersave"  → 30 s cadence
 *  "flush"           → drain the offline buffer immediately
 */

#include <Arduino.h>
#include <Wire.h>
#include <esp_sleep.h>
#include <esp_task_wdt.h>

#include "ble/health_service.h"
#include "config/config.h"
#include "core/ring_buffer.h"
#include "core/sample.h"
#include "sensors/battery_driver.h"
#include "sensors/max30102_driver.h"
#include "sensors/mpu6050_driver.h"
#include "sensors/sensor_driver.h"
#include "sensors/skin_contact_driver.h"
#include "sensors/temperature_driver.h"

using sb::Sample;

// ---------------------------------------------------------------- globals
static sb::Max30102Driver g_max30102;
static sb::TemperatureDriver g_temperature;
static sb::Mpu6050Driver g_mpu6050;
static sb::BatteryDriver g_battery;
static sb::SkinContactDriver g_skin;

// Pluggable registry — add a driver here and nowhere else.
static sb::SensorDriver* g_sensors[] = {
    &g_max30102, &g_temperature, &g_mpu6050, &g_battery, &g_skin,
};

static sb::HealthService g_ble;
static sb::RingBuffer<Sample, BUFFER_CAPACITY> g_buffer;

static bool g_powersave = false;
static uint32_t g_last_sample_ms = 0;

// ---------------------------------------------------------------- helpers
static String deviceSerial() {
  uint64_t mac = ESP.getEfuseMac();
  char buf[13];
  snprintf(buf, sizeof(buf), "%04X%08X", static_cast<uint16_t>(mac >> 32),
           static_cast<uint32_t>(mac));
  return String(buf);
}

static void onBleCommand(const std::string& cmd) {
  if (cmd == "mode:powersave") {
    g_powersave = true;
    Serial.println("[cmd] power-save mode ON (30 s cadence)");
  } else if (cmd == "mode:normal") {
    g_powersave = false;
    Serial.println("[cmd] normal mode (5 s cadence)");
  } else if (cmd == "flush") {
    Serial.printf("[cmd] flush requested (%u buffered)\n",
                  static_cast<unsigned>(g_buffer.size()));
    Sample s;
    while (g_ble.connected() && g_buffer.pop(s)) {
      g_ble.publish(s);
      delay(30);  // pace notifications so the central keeps up
    }
  } else {
    Serial.printf("[cmd] unknown command: %s\n", cmd.c_str());
  }
}

static void enterCriticalBatterySleep() {
  Serial.println("[power] battery critical — deep sleeping");
  for (auto* s : g_sensors) s->sleep();
  esp_sleep_enable_timer_wakeup(
      static_cast<uint64_t>(CRITICAL_SLEEP_SECONDS) * 1000000ULL);
  esp_deep_sleep_start();
}

// ---------------------------------------------------------------- arduino
void setup() {
  Serial.begin(115200);
  Serial.printf("\nSmart Bracelet fw %s\n", FIRMWARE_VERSION);

  // Hardware watchdog: reboot if the loop stalls.
  esp_task_wdt_init(WDT_TIMEOUT_SECONDS, true);
  esp_task_wdt_add(nullptr);

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);

  for (auto* s : g_sensors) {
    const bool ok = s->begin();
    Serial.printf("[init] %-12s %s\n", s->name(), ok ? "OK" : "FAILED (degraded)");
  }

  const String serial = deviceSerial();
  Serial.printf("[init] serial %s — advertising BLE\n", serial.c_str());
  g_ble.begin(serial.c_str(), onBleCommand);
}

void loop() {
  esp_task_wdt_reset();

  const uint32_t interval =
      SAMPLE_INTERVAL_MS * (g_powersave ? POWERSAVE_MULTIPLIER : 1);
  const uint32_t now = millis();
  if (now - g_last_sample_ms < interval) {
    delay(50);
    return;
  }
  g_last_sample_ms = now;

  // ---- sample all sensors into one Sample
  Sample s;
  s.uptime_ms = now;
  for (auto* drv : g_sensors) {
    if (drv->read(s)) s.valid = true;
  }

  // ---- critical battery → deep sleep (checked after battery read)
  if (!isnan(s.battery_pct) && s.battery_pct <= BATTERY_CRITICAL_PCT) {
    enterCriticalBatterySleep();
  }

  // ---- publish or buffer
  if (g_ble.connected()) {
    // Drain backlog first (oldest first) so history reaches the app in order.
    Sample old;
    while (g_buffer.pop(old)) {
      g_ble.publish(old);
      delay(30);
      esp_task_wdt_reset();
    }
    g_ble.publish(s);
  } else if (s.valid) {
    const bool dropped = g_buffer.push(s);
    if (dropped) Serial.println("[buffer] full — oldest sample dropped");
  }

  Serial.printf(
      "[sample] hr=%.0f temp=%.2f spo2=%.0f mov=%.2f batt=%.0f%% contact=%d "
      "ble=%d buf=%u\n",
      s.heart_rate, s.temperature, s.spo2, s.movement.magnitude, s.battery_pct,
      s.skin_contact ? 1 : 0, g_ble.connected() ? 1 : 0,
      static_cast<unsigned>(g_buffer.size()));
}
