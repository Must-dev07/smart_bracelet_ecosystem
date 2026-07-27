#pragma once
/**
 * Sample — one sensor sampling round. Pure C++ (no Arduino deps) so the
 * encoding logic is unit-testable on the host with g++.
 *
 * BLE payload contract (little-endian float32, must match the Flutter
 * BleService parser):
 *   heart_rate   : 4 bytes  f32   bpm
 *   temperature  : 4 bytes  f32   °C
 *   spo2         : 4 bytes  f32   %
 *   movement     : 28 bytes 7×f32 ax,ay,az,gx,gy,gz,magnitude
 *   battery      : 4 bytes  f32   %
 */

#include <cmath>
#include <cstdint>
#include <cstring>

namespace sb {

struct Movement {
  float ax = 0, ay = 0, az = 0;
  float gx = 0, gy = 0, gz = 0;
  float magnitude = 0;
};

struct Sample {
  uint32_t uptime_ms = 0;
  float heart_rate = NAN;
  float temperature = NAN;
  float spo2 = NAN;
  Movement movement{};
  float battery_pct = NAN;
  bool skin_contact = false;
  bool valid = false;  // at least one vital successfully read
};

/** Write a float32 little-endian into buf (4 bytes). */
inline void encode_f32_le(float v, uint8_t* buf) {
  static_assert(sizeof(float) == 4, "float must be 32-bit");
  uint32_t bits;
  std::memcpy(&bits, &v, 4);
  buf[0] = static_cast<uint8_t>(bits & 0xFF);
  buf[1] = static_cast<uint8_t>((bits >> 8) & 0xFF);
  buf[2] = static_cast<uint8_t>((bits >> 16) & 0xFF);
  buf[3] = static_cast<uint8_t>((bits >> 24) & 0xFF);
}

/** Read a float32 little-endian from buf (4 bytes). */
inline float decode_f32_le(const uint8_t* buf) {
  uint32_t bits = static_cast<uint32_t>(buf[0]) |
                  (static_cast<uint32_t>(buf[1]) << 8) |
                  (static_cast<uint32_t>(buf[2]) << 16) |
                  (static_cast<uint32_t>(buf[3]) << 24);
  float v;
  std::memcpy(&v, &bits, 4);
  return v;
}

/** Encode the 7-float movement payload (28 bytes). */
inline void encode_movement(const Movement& m, uint8_t out[28]) {
  encode_f32_le(m.ax, out + 0);
  encode_f32_le(m.ay, out + 4);
  encode_f32_le(m.az, out + 8);
  encode_f32_le(m.gx, out + 12);
  encode_f32_le(m.gy, out + 16);
  encode_f32_le(m.gz, out + 20);
  encode_f32_le(m.magnitude, out + 24);
}

/**
 * Movement magnitude: deviation of total acceleration from 1 g.
 * A resting baby reads ≈0; jerky motion reads >0.5.
 */
inline float movement_magnitude(float ax, float ay, float az) {
  const float g = std::sqrt(ax * ax + ay * ay + az * az);
  return std::fabs(g - 1.0f);
}

}  // namespace sb
