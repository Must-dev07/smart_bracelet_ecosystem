#pragma once
/**
 * Battery voltage → percentage model for a single-cell LiPo behind a
 * resistor divider. Pure C++, host-testable.
 *
 * Uses a piecewise-linear approximation of the LiPo discharge curve —
 * a straight 3.3–4.2 V mapping over-reports capacity in the flat middle
 * of the curve, so we anchor on typical open-circuit voltages.
 */

namespace sb {

/** Convert ADC millivolts at the pin to battery millivolts. */
inline float adc_mv_to_battery_mv(float adc_mv, float divider_ratio) {
  return adc_mv * divider_ratio;
}

/** Piecewise-linear LiPo SoC estimate. Clamped to [0, 100]. */
inline float battery_percent_from_mv(float mv) {
  struct Point {
    float mv;
    float pct;
  };
  // Typical 1S LiPo open-circuit voltage anchors.
  static const Point kCurve[] = {
      {3300.0f, 0.0f},  {3500.0f, 5.0f},  {3650.0f, 15.0f}, {3700.0f, 25.0f},
      {3750.0f, 40.0f}, {3800.0f, 55.0f}, {3900.0f, 75.0f}, {4000.0f, 88.0f},
      {4100.0f, 96.0f}, {4200.0f, 100.0f},
  };
  const int n = sizeof(kCurve) / sizeof(kCurve[0]);
  if (mv <= kCurve[0].mv) return 0.0f;
  if (mv >= kCurve[n - 1].mv) return 100.0f;
  for (int i = 1; i < n; ++i) {
    if (mv <= kCurve[i].mv) {
      const float span_mv = kCurve[i].mv - kCurve[i - 1].mv;
      const float t = (mv - kCurve[i - 1].mv) / span_mv;
      return kCurve[i - 1].pct + t * (kCurve[i].pct - kCurve[i - 1].pct);
    }
  }
  return 100.0f;
}

/** Exponential moving average to smooth noisy ADC reads. */
class BatteryFilter {
 public:
  explicit BatteryFilter(float alpha = 0.2f) : alpha_(alpha) {}

  float update(float pct) {
    if (!initialized_) {
      value_ = pct;
      initialized_ = true;
    } else {
      value_ = alpha_ * pct + (1.0f - alpha_) * value_;
    }
    return value_;
  }

  float value() const { return value_; }

 private:
  float alpha_;
  float value_ = 0.0f;
  bool initialized_ = false;
};

}  // namespace sb
