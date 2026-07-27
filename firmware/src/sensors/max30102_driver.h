#pragma once
/**
 * MAX30102 driver — heart rate + SpO2 (optical, I2C).
 *
 * Uses the SparkFun MAX3010x library for register access and classic
 * beat detection; SpO2 is estimated from the red/IR AC/DC ratio with the
 * standard empirical linear calibration (R → SpO2). Readings failing the
 * plausibility windows are rejected (filter lives in core/vitals_filter.h).
 */

#include <MAX30105.h>
#include <heartRate.h>

#include "core/vitals_filter.h"
#include "sensors/sensor_driver.h"

namespace sb {

class Max30102Driver final : public SensorDriver {
 public:
  const char* name() const override { return "MAX30102"; }

  bool begin() override {
    healthy_ = sensor_.begin(Wire, I2C_SPEED_FAST);
    if (!healthy_) return false;
    // LED config tuned for wrist contact on a newborn bracelet:
    // low amplitude to limit heat, 4-sample averaging, SpO2 mode.
    sensor_.setup(/*powerLevel=*/0x1F, /*sampleAverage=*/4, /*ledMode=*/2,
                  /*sampleRate=*/100, /*pulseWidth=*/411, /*adcRange=*/4096);
    return true;
  }

  bool read(Sample& sample) override {
    if (!healthy_) return false;

    // Drain the FIFO, tracking beats and the AC/DC components.
    uint32_t ir_min = UINT32_MAX, ir_max = 0, red_min = UINT32_MAX, red_max = 0;
    uint64_t ir_sum = 0, red_sum = 0;
    uint16_t n = 0;

    const uint32_t t0 = millis();
    while (millis() - t0 < 1000) {  // 1 s capture window per sampling round
      sensor_.check();
      while (sensor_.available()) {
        const uint32_t ir = sensor_.getFIFOIR();
        const uint32_t red = sensor_.getFIFORed();
        sensor_.nextSample();

        if (checkForBeat(ir)) {
          const uint32_t now = millis();
          if (last_beat_ms_ != 0) {
            const float bpm = 60000.0f / static_cast<float>(now - last_beat_ms_);
            if (hr_plausible(bpm)) hr_filter_.push(bpm);
          }
          last_beat_ms_ = now;
        }

        ir_min = min(ir_min, ir);
        ir_max = max(ir_max, ir);
        red_min = min(red_min, red);
        red_max = max(red_max, red);
        ir_sum += ir;
        red_sum += red;
        ++n;
      }
      yield();
    }

    bool wrote = false;

    const float hr = hr_filter_.median();
    if (!isnan(hr)) {
      sample.heart_rate = hr;
      wrote = true;
    }

    // SpO2: R = (ACred/DCred)/(ACir/DCir); SpO2 ≈ 110 − 25·R (empirical).
    if (n > 25 && ir_sum > 0 && red_sum > 0) {
      const float ir_dc = static_cast<float>(ir_sum) / n;
      const float red_dc = static_cast<float>(red_sum) / n;
      const float ir_ac = static_cast<float>(ir_max - ir_min);
      const float red_ac = static_cast<float>(red_max - red_min);
      if (ir_dc > 5000.0f && ir_ac > 100.0f) {  // finger/wrist actually present
        const float r = (red_ac / red_dc) / (ir_ac / ir_dc);
        float spo2 = 110.0f - 25.0f * r;
        if (spo2 > 100.0f) spo2 = 100.0f;
        if (spo2_plausible(spo2) && spo2 > 70.0f) {
          spo2_filter_.push(spo2);
          const float med = spo2_filter_.median();
          if (!isnan(med)) {
            sample.spo2 = med;
            wrote = true;
          }
        }
      }
    }

    return wrote;
  }

  void sleep() override {
    if (healthy_) sensor_.shutDown();
  }

  void wake() override {
    if (healthy_) sensor_.wakeUp();
  }

 private:
  MAX30105 sensor_;
  MedianFilter5 hr_filter_;
  MedianFilter5 spo2_filter_;
  uint32_t last_beat_ms_ = 0;
};

}  // namespace sb
