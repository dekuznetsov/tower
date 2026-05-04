#pragma once

// =============================================================================
// AutoTimer — non-blocking millis()-based pump cycle timer for Auto Mode.
//
// When active, the timer alternates the pump between on and off phases using
// the configured on/off intervals.  All pump state changes are applied through
// applyPumpState() so the safety interlock is always enforced.
//
// Requirements: 4.1, 4.2, 4.3
//
// Note: AUTO_TIMER_H_DEFINED is set by the test-support stub (test_support/
// auto_timer.h) when it is included first during host-native test builds.
// In that case the struct definition below is skipped to avoid a redefinition
// error, and the stub's definition is used instead.
// =============================================================================

#ifndef AUTO_TIMER_H_DEFINED
#define AUTO_TIMER_H_DEFINED

struct AutoTimer {
    unsigned long lastToggleMs  = 0;
    bool          pumpOn        = false;
    unsigned long onIntervalMs  = 60000UL;   // default 1 minute on
    unsigned long offIntervalMs = 60000UL;   // default 1 minute off
    bool          active        = false;

    void activate();
    void deactivate();
    void setOnInterval(int minutes);   // converts minutes → ms
    void setOffInterval(int minutes);  // converts minutes → ms
    void tick();
};

#endif  // AUTO_TIMER_H_DEFINED

// Global instance — defined in auto_timer.cpp
extern AutoTimer autoTimer;
