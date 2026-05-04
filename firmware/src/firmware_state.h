#pragma once

#include <Arduino.h>

// =============================================================================
// FirmwareState — in-memory representation of the tower's current state.
//
// Control fields (pump_mode, pump_speed, pump_switch, interval_on_ms,
// interval_off_ms) are written by the mobile app via Firebase and read by the
// firmware stream callback.
//
// Sensor / output fields (pump_state, moisture, water_level_low) are written
// by the firmware and read back by the mobile app.
//
// Requirements: 3.1, 3.2, 3.3, 3.4
// =============================================================================
struct FirmwareState {
    // -------------------------------------------------------------------------
    // Control fields — authoritative source: mobile app
    // -------------------------------------------------------------------------
    String        pump_mode;         // "auto" | "manual"
    int           pump_speed;        // PWM duty cycle 0–255
    bool          pump_switch;       // operator intent in manual mode

    unsigned long interval_on_ms;   // on-phase duration in milliseconds
    unsigned long interval_off_ms;  // off-phase duration in milliseconds

    // -------------------------------------------------------------------------
    // Sensor / output fields — authoritative source: firmware
    // -------------------------------------------------------------------------
    bool          pump_state;        // current actual pump on/off
    int           moisture;          // ADC raw value 0–4095
    bool          water_level_low;   // true when reservoir is below threshold
};

// Global instance — defined in firmware_state.cpp
extern FirmwareState firmwareState;
