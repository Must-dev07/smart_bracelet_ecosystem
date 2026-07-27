/**
 * Host-side unit tests for the firmware's pure-logic modules.
 * No Arduino/ESP32 dependency — compiled and executed with plain g++:
 *
 *   g++ -std=c++17 -I../include -Wall -Wextra -Werror -o test_host test_main.cpp && ./test_host
 *
 * Covers: float32 LE encoding round-trips (BLE payload contract),
 * ring-buffer semantics (order, overwrite-oldest, flush), the LiPo
 * battery model, plausibility windows, and the median filter.
 */

#include <cmath>
#include <cstdio>
#include <cstring>

#include "core/battery_model.h"
#include "core/ring_buffer.h"
#include "core/sample.h"
#include "core/vitals_filter.h"

static int g_failures = 0;
static int g_checks = 0;

#define CHECK(cond)                                                     \
  do {                                                                  \
    ++g_checks;                                                         \
    if (!(cond)) {                                                      \
      ++g_failures;                                                     \
      std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);       \
    }                                                                   \
  } while (0)

#define CHECK_NEAR(a, b, eps)                                           \
  do {                                                                  \
    ++g_checks;                                                         \
    if (std::fabs((a) - (b)) > (eps)) {                                 \
      ++g_failures;                                                     \
      std::printf("FAIL %s:%d  %s=%f !~ %s=%f\n", __FILE__, __LINE__,   \
                  #a, static_cast<double>(a), #b, static_cast<double>(b)); \
    }                                                                   \
  } while (0)

// ---------------------------------------------------------------- f32 LE
static void test_f32_encoding() {
  // Round-trip a spread of values, incl. vitals-typical ones.
  const float values[] = {0.0f, 1.0f, -1.0f, 36.75f, 98.0f, 142.5f,
                          0.015625f, 3.1415926f, 1e-6f, 65504.0f};
  for (float v : values) {
    uint8_t buf[4];
    sb::encode_f32_le(v, buf);
    CHECK_NEAR(sb::decode_f32_le(buf), v, 1e-6f * std::fabs(v) + 1e-9f);
  }

  // Known byte pattern: 1.0f == 0x3F800000 → LE bytes 00 00 80 3F.
  uint8_t buf[4];
  sb::encode_f32_le(1.0f, buf);
  CHECK(buf[0] == 0x00 && buf[1] == 0x00 && buf[2] == 0x80 && buf[3] == 0x3F);

  // Movement payload layout: 7 floats, 28 bytes, field order fixed.
  sb::Movement m;
  m.ax = 0.1f; m.ay = -0.2f; m.az = 0.98f;
  m.gx = 5.0f; m.gy = -3.5f; m.gz = 0.25f;
  m.magnitude = 0.042f;
  uint8_t mv[28];
  sb::encode_movement(m, mv);
  CHECK_NEAR(sb::decode_f32_le(mv + 0), 0.1f, 1e-6f);
  CHECK_NEAR(sb::decode_f32_le(mv + 4), -0.2f, 1e-6f);
  CHECK_NEAR(sb::decode_f32_le(mv + 8), 0.98f, 1e-6f);
  CHECK_NEAR(sb::decode_f32_le(mv + 12), 5.0f, 1e-6f);
  CHECK_NEAR(sb::decode_f32_le(mv + 16), -3.5f, 1e-6f);
  CHECK_NEAR(sb::decode_f32_le(mv + 20), 0.25f, 1e-6f);
  CHECK_NEAR(sb::decode_f32_le(mv + 24), 0.042f, 1e-6f);
}

// ---------------------------------------------------------------- movement
static void test_movement_magnitude() {
  // At rest, gravity only → magnitude ≈ 0.
  CHECK_NEAR(sb::movement_magnitude(0.0f, 0.0f, 1.0f), 0.0f, 1e-5f);
  CHECK_NEAR(sb::movement_magnitude(0.0f, 1.0f, 0.0f), 0.0f, 1e-5f);
  // Free fall → |g|=0 → magnitude = 1.
  CHECK_NEAR(sb::movement_magnitude(0.0f, 0.0f, 0.0f), 1.0f, 1e-5f);
  // Vigorous shake: 2 g total → magnitude = 1.
  CHECK_NEAR(sb::movement_magnitude(2.0f, 0.0f, 0.0f), 1.0f, 1e-5f);
}

// ---------------------------------------------------------------- ring buffer
static void test_ring_buffer() {
  sb::RingBuffer<int, 4> rb;
  CHECK(rb.empty());
  CHECK(rb.capacity() == 4);

  // FIFO order preserved.
  CHECK(!rb.push(1));
  CHECK(!rb.push(2));
  CHECK(!rb.push(3));
  CHECK(rb.size() == 3);
  int v = 0;
  CHECK(rb.pop(v) && v == 1);
  CHECK(rb.pop(v) && v == 2);
  CHECK(rb.size() == 1);

  // Fill to capacity, then overflow: oldest must be dropped.
  CHECK(!rb.push(4));
  CHECK(!rb.push(5));
  CHECK(!rb.push(6));
  CHECK(rb.full());
  CHECK(rb.push(7));  // returns true → dropped oldest (3)
  CHECK(rb.size() == 4);
  CHECK(rb.pop(v) && v == 4);
  CHECK(rb.pop(v) && v == 5);
  CHECK(rb.pop(v) && v == 6);
  CHECK(rb.pop(v) && v == 7);
  CHECK(rb.empty());
  CHECK(!rb.pop(v));  // pop on empty fails

  // Sustained wrap-around: 1000 pushes through a size-4 buffer keeps the
  // most recent 4 in order.
  for (int i = 0; i < 1000; ++i) rb.push(i);
  CHECK(rb.size() == 4);
  for (int expect = 996; expect < 1000; ++expect) {
    CHECK(rb.pop(v) && v == expect);
  }

  // A buffer of Sample structs works identically (compile + semantics).
  sb::RingBuffer<sb::Sample, 8> sbuf;
  sb::Sample s;
  s.heart_rate = 120.0f;
  s.uptime_ms = 42;
  sbuf.push(s);
  sb::Sample out;
  CHECK(sbuf.pop(out));
  CHECK_NEAR(out.heart_rate, 120.0f, 1e-6f);
  CHECK(out.uptime_ms == 42);
}

// ---------------------------------------------------------------- battery
static void test_battery_model() {
  // Divider ratio 2.0: 1900 mV at pin → 3800 mV battery.
  CHECK_NEAR(sb::adc_mv_to_battery_mv(1900.0f, 2.0f), 3800.0f, 1e-3f);

  // Anchor points of the discharge curve.
  CHECK_NEAR(sb::battery_percent_from_mv(3300.0f), 0.0f, 1e-3f);
  CHECK_NEAR(sb::battery_percent_from_mv(4200.0f), 100.0f, 1e-3f);
  CHECK_NEAR(sb::battery_percent_from_mv(3800.0f), 55.0f, 1e-3f);

  // Clamping outside the range.
  CHECK_NEAR(sb::battery_percent_from_mv(3000.0f), 0.0f, 1e-3f);
  CHECK_NEAR(sb::battery_percent_from_mv(4400.0f), 100.0f, 1e-3f);

  // Monotonic: more volts never means less charge.
  float prev = -1.0f;
  for (float mv = 3200.0f; mv <= 4300.0f; mv += 10.0f) {
    const float pct = sb::battery_percent_from_mv(mv);
    CHECK(pct >= prev);
    prev = pct;
  }

  // Interpolation inside a segment: midpoint of 3750(40%)–3800(55%).
  CHECK_NEAR(sb::battery_percent_from_mv(3775.0f), 47.5f, 0.01f);

  // EMA filter converges and smooths.
  sb::BatteryFilter f(0.5f);
  CHECK_NEAR(f.update(80.0f), 80.0f, 1e-6f);   // first sample = init
  CHECK_NEAR(f.update(60.0f), 70.0f, 1e-6f);   // 0.5*60 + 0.5*80
  CHECK_NEAR(f.update(70.0f), 70.0f, 1e-6f);
}

// ---------------------------------------------------------------- filters
static void test_plausibility_and_median() {
  // Plausibility windows (match backend validation).
  CHECK(sb::hr_plausible(120.0f));
  CHECK(!sb::hr_plausible(-5.0f));
  CHECK(!sb::hr_plausible(900.0f));
  CHECK(sb::temp_plausible(36.8f));
  CHECK(!sb::temp_plausible(80.0f));
  CHECK(sb::spo2_plausible(97.0f));
  CHECK(!sb::spo2_plausible(101.0f));

  // Median filter suppresses a single spike.
  sb::MedianFilter5 mf;
  CHECK(std::isnan(mf.median()));  // needs ≥3 samples
  mf.push(120.0f);
  mf.push(122.0f);
  CHECK(std::isnan(mf.median()));
  mf.push(280.0f);  // motion spike
  CHECK_NEAR(mf.median(), 122.0f, 1e-6f);  // spike rejected
  mf.push(121.0f);
  mf.push(119.0f);
  CHECK_NEAR(mf.median(), 121.0f, 1e-6f);

  // reset() clears state.
  mf.reset();
  CHECK(std::isnan(mf.median()));
}

// ---------------------------------------------------------------- main
int main() {
  test_f32_encoding();
  test_movement_magnitude();
  test_ring_buffer();
  test_battery_model();
  test_plausibility_and_median();

  std::printf("\n%d checks, %d failure(s)\n", g_checks, g_failures);
  return g_failures == 0 ? 0 : 1;
}
