#pragma once
/**
 * Skin-contact driver — digital contact detection (capacitive touch pad or
 * galvanic electrode pair on SKIN_CONTACT_PIN). Debounced over 3 reads so a
 * moment of wiggle doesn't flip the state; feeds the backend
 * BRACELET_REMOVED rule.
 */

#include <Arduino.h>

#include "config/config.h"
#include "sensors/sensor_driver.h"

namespace sb {

class SkinContactDriver final : public SensorDriver {
 public:
  const char* name() const override { return "SkinContact"; }

  bool begin() override {
    pinMode(SKIN_CONTACT_PIN, INPUT_PULLDOWN);
    healthy_ = true;
    return true;
  }

  bool read(Sample& sample) override {
    const bool now = digitalRead(SKIN_CONTACT_PIN) == HIGH;
    // 3-state debounce: change reported only after 3 consistent reads.
    if (now == candidate_) {
      if (++stable_count_ >= 3) state_ = candidate_;
    } else {
      candidate_ = now;
      stable_count_ = 1;
    }
    sample.skin_contact = state_;
    return true;
  }

 private:
  bool state_ = false;
  bool candidate_ = false;
  uint8_t stable_count_ = 0;
};

}  // namespace sb
