#include "stream_handler.h"

#include <Arduino.h>
#include <Firebase_ESP_Client.h>

#include "config.h"
#include "connectivity.h"
#include "firmware_state.h"
#include "pump_control.h"
#include "auto_timer.h"

// =============================================================================
// onFirebaseStream(FirebaseStream data)
//
// Registered as the Firebase stream callback in connectivitySetup().
// Dispatches each incoming path to the appropriate handler.
//
// Each branch guards with data.dataType() before casting to avoid acting on
// malformed payloads.
//
// Path → handler mapping:
//   /pump_mode        → handleModeChange   (expects type "string")
//   /pump_speed       → handleSpeedChange  (expects type "int")
//   /pump_switch      → handleSwitchChange (expects type "boolean")
//   /interval_on_min  → autoTimer.setOnInterval  (expects type "int")
//   /interval_off_min → autoTimer.setOffInterval (expects type "int")
//
// Requirements: 3.1, 3.2, 3.3, 3.4
// =============================================================================
void onFirebaseStream(FirebaseStream data) {
    String path = data.dataPath();

    if (path == "/pump_mode") {
        if (data.dataType() == "string") {
            handleModeChange(data.stringData());
        } else {
            Serial.print("onFirebaseStream: unexpected type for /pump_mode: ");
            Serial.println(data.dataType().c_str());
        }
    } else if (path == "/pump_speed") {
        if (data.dataType() == "int") {
            handleSpeedChange(data.intData());
        } else {
            Serial.print("onFirebaseStream: unexpected type for /pump_speed: ");
            Serial.println(data.dataType().c_str());
        }
    } else if (path == "/pump_switch") {
        if (data.dataType() == "boolean") {
            handleSwitchChange(data.boolData());
        } else {
            Serial.print("onFirebaseStream: unexpected type for /pump_switch: ");
            Serial.println(data.dataType().c_str());
        }
    } else if (path == "/interval_on_min") {
        if (data.dataType() == "int") {
            autoTimer.setOnInterval(data.intData());
        } else {
            Serial.print("onFirebaseStream: unexpected type for /interval_on_min: ");
            Serial.println(data.dataType().c_str());
        }
    } else if (path == "/interval_off_min") {
        if (data.dataType() == "int") {
            autoTimer.setOffInterval(data.intData());
        } else {
            Serial.print("onFirebaseStream: unexpected type for /interval_off_min: ");
            Serial.println(data.dataType().c_str());
        }
    }
    // Paths not listed above (e.g. /pump_state, /sensors/*) are written by the
    // firmware itself and are intentionally ignored here.
}

// =============================================================================
// onStreamTimeout(bool timeout)
//
// Called by the Firebase library when the stream connection times out.
// Logs the event and re-subscribes to TOWER_PATH so the stream resumes.
//
// Requirement: 2.3
// =============================================================================
void onStreamTimeout(bool timeout) {
    if (timeout) {
        Serial.println("onStreamTimeout: Firebase stream timed out. Reconnecting...");
        if (!Firebase.beginStream(streamData, TOWER_PATH)) {
            Serial.print("onStreamTimeout: stream reconnect failed: ");
            Serial.println(streamData.errorReason().c_str());
        } else {
            Serial.println("onStreamTimeout: stream reconnected.");
        }
    }
}

// =============================================================================
// handleModeChange(String mode)
//
// Updates firmwareState.pump_mode.
// - "auto"   → activates autoTimer so it starts cycling the pump.
// - "manual" → deactivates autoTimer so it stops cycling the pump.
//
// Requirements: 3.1, 4.4, 5.4
// =============================================================================
void handleModeChange(String mode) {
    firmwareState.pump_mode = mode;

    if (mode == "auto") {
        autoTimer.activate();
    } else {
        // "manual" or any unrecognised value — stop the timer
        autoTimer.deactivate();
    }
}

// =============================================================================
// handleSpeedChange(int speed)
//
// Updates firmwareState.pump_speed and re-applies the current pump state so
// the new duty cycle takes effect immediately if the pump is already running.
//
// Requirements: 3.2, 6.2
// =============================================================================
void handleSpeedChange(int speed) {
    firmwareState.pump_speed = speed;
    // Re-apply the current pump state so the PWM duty cycle is updated.
    applyPumpState(firmwareState.pump_state);
}

// =============================================================================
// handleSwitchChange(bool on)
//
// Only acts when the firmware is in manual mode.  In auto mode the pump switch
// is ignored (Requirement 5.4 / Property 7).
//
// Requirements: 3.3, 5.1, 5.2
// =============================================================================
void handleSwitchChange(bool on) {
    if (firmwareState.pump_mode != "manual") {
        // Auto mode — ignore pump_switch changes (Requirement 5.4)
        return;
    }
    applyPumpState(on);
}
