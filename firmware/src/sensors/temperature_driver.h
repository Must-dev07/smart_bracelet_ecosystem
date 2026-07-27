#pragma once
/**
 * DS18B20 skin-temperature driver (1-Wire on ONE_WIRE_PIN).
 * Waterproof-probe variant recommended for skin contact through the
 * bracelet strap. 12-bit resolution, median-filtered.
 */

#include <DallasTemperature.h>
#include <OneWire.h>

#include "config/config.h"
#include "core/vitals_filter.h"
#include "sensors/sensor_driver.h"

namespace sb {

class TemperatureDriver final : public SensorDriver {
 public:
  TemperatureDriver() : one_wire_(ONE_WIRE_PIN), dallas_(&one_wire_) {}

  const char* name() const override { return "DS18B20"; }

  bool begin() override {
    dallas_.begin();
    healthy_ = dallas_.getDeviceCount() > 0;
    if (healthy_) {
      dallas_.setResolution(12);
      dallas_.setWaitForConversion(true);
    }
    return healthy_;
  }

  bool read(Sample& sample) override {
    if (!healthy_) return false;
    dallas_.requestTemperatures();
    const float c = dallas_.getTempCByIndex(0);
    if (c == DEVICE_DISCONNECTED_C || !temp_plausible(c)) return false;
    filter_.push(c);
    const float med = filter_.median();
    if (isnan(med)) return false;
    sample.temperature = med;
    return true;
  }

 private:
  OneWire one_wire_;
  DallasTemperature dallas_;
  MedianFilter5 filter_;
};

}  // namespace sb
