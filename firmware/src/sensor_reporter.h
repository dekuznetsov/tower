#pragma once

// =============================================================================
// sensor_reporter — 30-second sensor polling and Firebase write.
//
// sensorLoop() is called on every loop() iteration.  It uses a millis()-based
// timer to read sensors every SENSOR_INTERVAL_MS (30 000 ms) and write the
// results to Firebase under SENSORS_PATH.
//
// After each sensor read the safety interlock is re-evaluated: if the water
// level is low, applyPumpState(false) is called immediately.
//
// Requirements: 7.1, 7.2, 7.3, 7.4, 8.1
// =============================================================================

void sensorLoop();

#ifdef SENSOR_REPORTER_TEST
// Resets the internal lastSensorMs to 0 for test isolation.
void sensorLoopResetForTest();
#endif
