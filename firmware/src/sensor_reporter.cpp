#include "sensor_reporter.h"

#include <Arduino.h>
#include <Firebase_ESP_Client.h>

#include "config.h"
#include "connectivity.h"
#include "firmware_state.h"
#include "pump_control.h"

// =============================================================================
// Module-private state
// =============================================================================

static unsigned long lastSensorMs = 0;

#ifdef SENSOR_REPORTER_TEST
void sensorLoopResetForTest() {
    lastSensorMs = 0;
}
#endif

// =============================================================================
// sensorLoop()
//
// Non-blocking sensor reporter.  Call on every loop() iteration.
//
// Requirements: 7.1, 7.2, 7.3, 7.4, 8.1
// =============================================================================
void sensorLoop() {
    // -------------------------------------------------------------------------
    // 1. Non-blocking 30-second timer check.  Requirement 7.4
    // -------------------------------------------------------------------------
    if (millis() - lastSensorMs < SENSOR_INTERVAL_MS) {
        return;
    }
    lastSensorMs = millis();

    // -------------------------------------------------------------------------
    // 2. Read moisture sensor (ADC, GPIO 34).  Requirement 7.1
    // -------------------------------------------------------------------------
    int rawMoisture = analogRead(MOISTURE_PIN);
    int moisture    = rawMoisture;

    if (rawMoisture < 0 || rawMoisture > 4095) {
        Serial.print("Sensor anomaly: moisture out of range: ");
        Serial.println(rawMoisture);
        if (rawMoisture < 0)    moisture = 0;
        if (rawMoisture > 4095) moisture = 4095;
    }

    // -------------------------------------------------------------------------
    // 3. Read water-level sensor (digital, GPIO 19, active-HIGH).  Req 7.2
    // -------------------------------------------------------------------------
    bool waterLow = digitalRead(WATER_LEVEL_PIN) == HIGH;

    // -------------------------------------------------------------------------
    // 4. Update in-memory firmware state.
    // -------------------------------------------------------------------------
    firmwareState.moisture        = moisture;
    firmwareState.water_level_low = waterLow;

    // -------------------------------------------------------------------------
    // 5. Write sensor readings to Firebase.  Requirement 7.3
    // -------------------------------------------------------------------------
    FirebaseJson json;
    json.set("moisture",        moisture);
    json.set("water_level_low", waterLow);

    if (!Firebase.updateNode(writeData, SENSORS_PATH, json)) {
        Serial.print("Sensor write failed: ");
        Serial.println(writeData.errorReason().c_str());
    }

    // -------------------------------------------------------------------------
    // 6. Safety interlock re-evaluation.  Requirement 8.1
    // -------------------------------------------------------------------------
    if (waterLow) {
        applyPumpState(false);
    }
}
