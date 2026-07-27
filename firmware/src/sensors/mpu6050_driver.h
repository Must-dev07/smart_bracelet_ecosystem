#pragma once
/**
 * MPU6050 driver — 3-axis accel + gyro over I2C.
 * Outputs g / deg/s and a motion magnitude (deviation from 1 g) used by
 * the backend NO_MOVEMENT rule.
 */

#include <MPU6050.h>

#include "core/sample.h"
#include "sensors/sensor_driver.h"

namespace sb {

class Mpu6050Driver final : public SensorDriver {
 public:
  const char* name() const override { return "MPU6050"; }

  bool begin() override {
    mpu_.initialize();
    healthy_ = mpu_.testConnection();
    if (healthy_) {
      mpu_.setFullScaleAccelRange(MPU6050_ACCEL_FS_2);  // ±2 g
      mpu_.setFullScaleGyroRange(MPU6050_GYRO_FS_250);  // ±250 °/s
      mpu_.setDLPFMode(MPU6050_DLPF_BW_20);             // 20 Hz low-pass
    }
    return healthy_;
  }

  bool read(Sample& sample) override {
    if (!healthy_) return false;
    int16_t ax, ay, az, gx, gy, gz;
    mpu_.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

    // ±2 g → 16384 LSB/g ; ±250 °/s → 131 LSB/(°/s)
    sample.movement.ax = ax / 16384.0f;
    sample.movement.ay = ay / 16384.0f;
    sample.movement.az = az / 16384.0f;
    sample.movement.gx = gx / 131.0f;
    sample.movement.gy = gy / 131.0f;
    sample.movement.gz = gz / 131.0f;
    sample.movement.magnitude = movement_magnitude(
        sample.movement.ax, sample.movement.ay, sample.movement.az);
    return true;
  }

  void sleep() override {
    if (healthy_) mpu_.setSleepEnabled(true);
  }

  void wake() override {
    if (healthy_) mpu_.setSleepEnabled(false);
  }

 private:
  MPU6050 mpu_;
};

}  // namespace sb
