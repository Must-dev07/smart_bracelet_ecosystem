#pragma once
/**
 * Vitals plausibility filtering + smoothing. Pure C++, host-testable.
 *
 * Raw optical HR/SpO2 readings spike on motion; skin-temp probes glitch on
 * contact loss. The firmware rejects impossible values BEFORE they ever
 * reach BLE (the backend re-validates — defence in depth) and applies a
 * short median filter to suppress single-sample spikes.
 */

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>

namespace sb {

// Plausible physiological windows (match backend serializer validation).
inline bool hr_plausible(float bpm) { return bpm >= 20.0f && bpm <= 300.0f; }
inline bool temp_plausible(float c) { return c >= 25.0f && c <= 45.0f; }
inline bool spo2_plausible(float pct) { return pct >= 0.0f && pct <= 100.0f; }

/** 5-tap median filter; returns NAN until 3 valid samples were fed. */
class MedianFilter5 {
 public:
  void push(float v) {
    buf_[idx_ % 5] = v;
    ++idx_;
  }

  float median() const {
    const std::size_t n = std::min<std::size_t>(idx_, 5);
    if (n < 3) return NAN;
    std::array<float, 5> tmp{};
    for (std::size_t i = 0; i < n; ++i) tmp[i] = buf_[i];
    std::sort(tmp.begin(), tmp.begin() + n);
    return tmp[n / 2];
  }

  void reset() { idx_ = 0; }

 private:
  std::array<float, 5> buf_{};
  std::size_t idx_ = 0;
};

}  // namespace sb
