#include "pump_control.h"

#include <Arduino.h>
#include <Firebase_ESP_Client.h>

#include "config.h"
#include "firmware_state.h"
#include "connectivity.h"

// =============================================================================
// applyPumpState(bool requestedOn)
//
// The single authoritative gate for pump activation.  All code paths that
// want to turn the pump on or off (auto timer, manual switch, sensor reporter)
// call this function so the water-level safety interlock is always enforced.
//
// Requirements: 8.1, 8.2, 8.3, 6.3, 6.4
// =============================================================================
void applyPumpState(bool requestedOn) {
    // -------------------------------------------------------------------------
    // 1. Read the water-level sensor and derive the actual pump state.
    //    WATER_LEVEL_PIN is active-HIGH: HIGH means the reservoir is low.
    //    Requirement 8.1, 8.3
    // -------------------------------------------------------------------------
    bool waterLow = digitalRead(WATER_LEVEL_PIN) == HIGH;
    bool actualOn = requestedOn && !waterLow;

    // -------------------------------------------------------------------------
    // 2. Apply PWM duty cycle.
    //    - Pump on  → use current pump_speed (Requirement 6.4)
    //    - Pump off → duty cycle 0           (Requirement 6.3, 8.1)
    // -------------------------------------------------------------------------
    ledcWrite(PWM_CHANNEL, actualOn ? firmwareState.pump_speed : 0);

    // -------------------------------------------------------------------------
    // 3. Write pump_state to Firebase only when it changes.
    //    This avoids unnecessary writes on every loop iteration.
    //    Requirement 8.2, 4.3, 5.3
    // -------------------------------------------------------------------------
    if (firmwareState.pump_state != actualOn) {
        firmwareState.pump_state = actualOn;
        if (!Firebase.setBool(writeData, TOWER_PATH "/pump_state", firmwareState.pump_state)) {
            Serial.print("pump_state write failed: ");
            Serial.println(writeData.errorReason().c_str());
        }
    }

    // -------------------------------------------------------------------------
    // 4. Safety interlock force-write.
    //    If water is low and the pump was requested on, write pump_state=false
    //    even when the stored value was already false.  This ensures the mobile
    //    app always receives an explicit false when the interlock is active.
    //    Requirement 8.2, 8.3
    // -------------------------------------------------------------------------
    if (waterLow && requestedOn) {
        if (!Firebase.setBool(writeData, TOWER_PATH "/pump_state", false)) {
            Serial.print("pump_state interlock write failed: ");
            Serial.println(writeData.errorReason().c_str());
        }
    }
}
