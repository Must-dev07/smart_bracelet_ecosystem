#pragma once
/**
 * Fixed-capacity ring buffer for offline sample retention.
 * Overwrites the OLDEST entry when full (newest data wins — the freshest
 * vitals matter most for a monitoring device). Pure C++, host-testable.
 */

#include <array>
#include <cstddef>

namespace sb {

template <typename T, std::size_t N>
class RingBuffer {
 public:
  bool empty() const { return count_ == 0; }
  bool full() const { return count_ == N; }
  std::size_t size() const { return count_; }
  static constexpr std::size_t capacity() { return N; }

  /** Push a value; overwrites the oldest when full. Returns true if an
   *  old value was dropped. */
  bool push(const T& value) {
    bool dropped = false;
    data_[head_] = value;
    head_ = (head_ + 1) % N;
    if (count_ == N) {
      tail_ = (tail_ + 1) % N;  // oldest overwritten
      dropped = true;
    } else {
      ++count_;
    }
    return dropped;
  }

  /** Pop the oldest value. Returns false when empty. */
  bool pop(T& out) {
    if (count_ == 0) return false;
    out = data_[tail_];
    tail_ = (tail_ + 1) % N;
    --count_;
    return true;
  }

  /** Peek the oldest value without removing it. */
  bool peek(T& out) const {
    if (count_ == 0) return false;
    out = data_[tail_];
    return true;
  }

  void clear() {
    head_ = tail_ = count_ = 0;
  }

 private:
  std::array<T, N> data_{};
  std::size_t head_ = 0;
  std::size_t tail_ = 0;
  std::size_t count_ = 0;
};

}  // namespace sb
