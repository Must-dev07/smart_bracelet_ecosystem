#pragma once
/**
 * SensorDriver — the pluggable sensor interface (spec Section 2).
 *
 * Every physical sensor implements this contract; main.cpp iterates a
 * registry of SensorDriver* so adding a sensor is: write a driver, add it
 * to the array. No other file changes.
 */

#include "core/sample.h"

namespace sb {

class SensorDriver {
 public:
  virtual ~SensorDriver() = default;

  /** Human-readable name for logs. */
  virtual const char* name() const = 0;

  /** Initialise hardware. Return false on failure (device continues in
   *  degraded mode; the driver's read() then leaves the sample untouched). */
  virtual bool begin() = 0;

  /** Read into the shared sample. Return true if a value was written. */
  virtual bool read(Sample& sample) = 0;

  /** Prepare for deep sleep (power down LEDs, etc.). Default: no-op. */
  virtual void sleep() {}

  /** Restore after wake. Default: re-run begin(). */
  virtual void wake() { begin(); }

  bool healthy() const { return healthy_; }

 protected:
  bool healthy_ = false;
};

}  // namespace sb
