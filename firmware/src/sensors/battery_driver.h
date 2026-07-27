#pragma once
/**
 * Battery driver — LiPo voltage via ADC + resistor divider, converted to
 * a smoothed state-of-charge percentage (model in core/battery_model.h).
 */

#include <esp_adc_cal.h>

#include "config/config.h"
#include "core/battery_model.h"
#include "sensors/sensor_driver.h"

namespace sb {

class BatteryDriver final : public SensorDriver {
 public:
  const char* name() const override { return "Battery"; }

  bool begin() override {
    analogReadResolution(12);
    analogSetPinAttenuation(BATTERY_ADC_PIN, ADC_11db);  // up to ~3.1 V at pin
    // Factory calibration for accurate mV conversion.
    esp_adc_cal_characterize(ADC_UNIT_1, ADC_ATTEN_DB_11, ADC_WIDTH_BIT_12,
                             1100, &adc_chars_);
    healthy_ = true;
    return true;
  }

  bool read(Sample& sample) override {
    // Average 8 raw reads to reduce ADC noise.
    uint32_t acc = 0;
    for (int i = 0; i < 8; ++i) acc += analogRead(BATTERY_ADC_PIN);
    const uint32_t raw = acc / 8;
    const uint32_t adc_mv = esp_adc_cal_raw_to_voltage(raw, &adc_chars_);
    const float batt_mv = adc_mv_to_battery_mv(static_cast<float>(adc_mv),
                                               BATTERY_DIVIDER_RATIO);
    const float pct = battery_percent_from_mv(batt_mv);
    sample.battery_pct = filter_.update(pct);
    return true;
  }

  float last_percent() const { return filter_.value(); }

 private:
  esp_adc_cal_characteristics_t adc_chars_{};
  BatteryFilter filter_{0.2f};
};

}  // namespace sb
