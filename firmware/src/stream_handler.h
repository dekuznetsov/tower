#pragma once

#include <Arduino.h>

// =============================================================================
// stream_handler — Firebase stream callback dispatch and mode/speed/switch
// handlers.
//
// onFirebaseStream() is registered as the stream callback in connectivitySetup()
// (connectivity.h forward-declares it).  It dispatches each incoming path to
// the appropriate handler function.
//
// onStreamTimeout() is also forward-declared in connectivity.h; its body is
// here so all stream-related logic lives in one translation unit.
//
// Requirements: 3.1, 3.2, 3.3, 3.4
// =============================================================================

// -----------------------------------------------------------------------------
// Forward declaration of AutoTimer.
// The full definition is provided in task 7.1 (auto_timer.h / auto_timer.cpp).
// stream_handler.cpp uses the global `autoTimer` instance via this declaration.
// -----------------------------------------------------------------------------
struct AutoTimer;
extern AutoTimer autoTimer;

// -----------------------------------------------------------------------------
// handleModeChange(String mode)
//
// Updates firmwareState.pump_mode.
// - Switching to "auto"   → activates autoTimer
// - Switching to "manual" → deactivates autoTimer
//
// Requirements: 3.1, 4.4, 5.4
// -----------------------------------------------------------------------------
void handleModeChange(String mode);

// -----------------------------------------------------------------------------
// handleSpeedChange(int speed)
//
// Updates firmwareState.pump_speed and re-applies the PWM duty cycle by
// calling applyPumpState(firmwareState.pump_state).
//
// Requirements: 3.2, 6.2
// -----------------------------------------------------------------------------
void handleSpeedChange(int speed);

// -----------------------------------------------------------------------------
// handleSwitchChange(bool on)
//
// Only acts when firmwareState.pump_mode == "manual".
// Calls applyPumpState(on) to set the pump state through the safety interlock.
//
// Requirements: 3.3, 5.1, 5.2
// -----------------------------------------------------------------------------
void handleSwitchChange(bool on);
