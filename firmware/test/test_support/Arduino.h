#pragma once
// Fake Arduino.h for native host testing.
// Provides the minimal types and constants needed by firmware source files.
// This file is placed in the test include path so it shadows the real Arduino.h.

#include <string>
#include <cstdint>

// Arduino String type — backed by std::string
class String {
public:
    String() = default;
    String(const char* s) : _s(s ? s : "") {}
    String(const std::string& s) : _s(s) {}

    bool operator==(const String& other) const { return _s == other._s; }
    bool operator==(const char* other)   const { return _s == other; }
    bool operator!=(const String& other) const { return !(*this == other); }
    bool operator!=(const char* other)   const { return !(*this == other); }

    const char* c_str() const { return _s.c_str(); }
    std::string toStdString() const { return _s; }

private:
    std::string _s;
};

// Arduino digital pin levels
static constexpr int HIGH = 1;
static constexpr int LOW  = 0;

// ---------------------------------------------------------------------------
// millis() stub — returns a controllable global for testing.
//
// Test files that need to control time should:
//   1. Declare:  extern unsigned long g_millis_value;
//   2. Define:   unsigned long g_millis_value = 0;  (in the test .cpp)
//   3. Advance:  g_millis_value = <desired_ms>;
//
// The extern declaration here allows firmware source files (auto_timer.cpp,
// sensor_reporter.cpp, etc.) to call millis() without knowing about the
// test infrastructure.
// ---------------------------------------------------------------------------
extern unsigned long g_millis_value;

inline unsigned long millis() {
    return g_millis_value;
}
