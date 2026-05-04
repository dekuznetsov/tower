#pragma once

// =============================================================================
// pump_control — Safety Interlock and PWM pump state application.
//
// applyPumpState() is the single authoritative function for activating or
// deactivating the pump.  Every code path that wants to turn the pump on or
// off (auto timer, manual switch, sensor reporter) MUST call this function so
// that the water-level safety interlock cannot be bypassed.
//
// Requirements: 8.1, 8.2, 8.3, 6.3, 6.4
// =============================================================================

// -----------------------------------------------------------------------------
// applyPumpState(bool requestedOn)
//
// Reads the water-level sensor and derives the actual pump state:
//   actualOn = requestedOn && !waterLow
//
// PWM behaviour:
//   - actualOn == true  → ledcWrite(PWM_CHANNEL, firmwareState.pump_speed)
//   - actualOn == false → ledcWrite(PWM_CHANNEL, 0)
//
// Firebase write policy:
//   - pump_state is written whenever it changes (state transition).
//   - If water is low AND the caller requested the pump on, pump_state=false
//     is force-written even when the stored value was already false, so the
//     mobile app always sees the correct interlock state.
//
// Requirements: 8.1, 8.2, 8.3, 6.3, 6.4
// -----------------------------------------------------------------------------
void applyPumpState(bool requestedOn);
