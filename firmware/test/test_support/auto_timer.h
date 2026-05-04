#pragma once
// Stub auto_timer.h for native host testing.
//
// Provides a minimal AutoTimer struct that satisfies the interface used by
// stream_handler.cpp (activate, deactivate, setOnInterval, setOffInterval,
// tick) without pulling in any real timer logic.
//
// The real AutoTimer implementation is provided in task 7.1.  This stub is
// used only during host-native compilation of stream_handler tests.
//
// AUTO_TIMER_H_DEFINED is set here so that the real src/auto_timer.h skips
// its struct definition when this stub has already been included first.
#define AUTO_TIMER_H_DEFINED

struct AutoTimer {
    bool active = false;
    int  onIntervalMs  = 0;
    int  offIntervalMs = 0;

    void activate()              { active = true;  }
    void deactivate()            { active = false; }
    void setOnInterval(int ms)   { onIntervalMs  = ms; }
    void setOffInterval(int ms)  { offIntervalMs = ms; }
    void tick()                  { /* no-op stub */ }
};

// Global instance — defined in the test file (or here as inline for ODR safety)
// The test file must define:  AutoTimer autoTimer;
