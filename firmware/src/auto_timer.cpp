#include "auto_timer.h"

#include <Arduino.h>

#include "pump_control.h"

// =============================================================================
// AutoTimer implementation
//
// All pump state changes go through applyPumpState() so the water-level
// safety interlock is always enforced.
//
// Requirements: 4.1, 4.2, 4.3, 4.4, 3.4
// =============================================================================

// Global instance
AutoTimer autoTimer;

// -----------------------------------------------------------------------------
// activate() — start the auto timer.
//
// Sets active = true, records the current millis() as the start of the first
// phase, and begins with the pump off.  The first toggle (pump on) will occur
// after offIntervalMs milliseconds.
//
// Requirement 4.1
// -----------------------------------------------------------------------------
void AutoTimer::activate() {
    active        = true;
    pumpOn        = false;
    lastToggleMs  = millis();
}

// -----------------------------------------------------------------------------
// deactivate() — stop the auto timer and turn the pump off.
//
// Sets active = false and calls applyPumpState(false) to ensure the pump is
// stopped immediately regardless of its current state.
//
// Requirement 4.4
// -----------------------------------------------------------------------------
void AutoTimer::deactivate() {
    active = false;
    applyPumpState(false);
}

// -----------------------------------------------------------------------------
// setOnInterval(int minutes) — configure the pump-on phase duration.
//
// Converts minutes to milliseconds (minutes * 60 000) and stores the result
// in onIntervalMs.  Takes effect on the next phase transition.
//
// Requirement 3.4
// -----------------------------------------------------------------------------
void AutoTimer::setOnInterval(int minutes) {
    onIntervalMs = static_cast<unsigned long>(minutes) * 60000UL;
}

// -----------------------------------------------------------------------------
// setOffInterval(int minutes) — configure the pump-off phase duration.
//
// Converts minutes to milliseconds (minutes * 60 000) and stores the result
// in offIntervalMs.  Takes effect on the next phase transition.
//
// Requirement 3.4
// -----------------------------------------------------------------------------
void AutoTimer::setOffInterval(int minutes) {
    offIntervalMs = static_cast<unsigned long>(minutes) * 60000UL;
}

// -----------------------------------------------------------------------------
// tick() — advance the timer state machine.
//
// Called on every loop() iteration.  If the timer is not active, returns
// immediately.  Otherwise, computes the elapsed time since the last toggle
// and compares it against the current phase interval:
//
//   - pumpOn == true  → target interval is onIntervalMs
//   - pumpOn == false → target interval is offIntervalMs
//
// When elapsed >= target, the pump state is toggled, lastToggleMs is updated
// to the current millis(), and applyPumpState() is called with the new state.
// applyPumpState() handles the Firebase write and the safety interlock.
//
// Requirements: 4.1, 4.2, 4.3
// -----------------------------------------------------------------------------
void AutoTimer::tick() {
    if (!active) return;

    unsigned long now     = millis();
    unsigned long elapsed = now - lastToggleMs;
    unsigned long target  = pumpOn ? onIntervalMs : offIntervalMs;

    if (elapsed >= target) {
        pumpOn       = !pumpOn;
        lastToggleMs = millis();
        applyPumpState(pumpOn);
    }
}
