// Feature: hydroponics-farm-management
//
// Property-based and unit tests for sensorLoop().
//
// Properties covered:
//   Property 9: Sensor Values Are Written to Firebase  (Req 7.3)
//
// Unit tests:
//   30 s not elapsed → no read, no write               (Req 7.4)
//   30 s elapsed → reads both sensors, writes Firebase (Req 7.1, 7.2, 7.3)
//   water_level_low true → applyPumpState(false) called (Req 8.1)

#define SENSOR_REPORTER_TEST

// ---------------------------------------------------------------------------
// 1. Include fake SDK headers first.
// ---------------------------------------------------------------------------
#include <Arduino.h>
#include <Firebase_ESP_Client.h>

// ---------------------------------------------------------------------------
// 2. Define mock globals
// ---------------------------------------------------------------------------
int  g_water_level_pin_value       = 0;
int  g_analog_read_value           = 0;
int  g_last_ledc_channel           = -1;
int  g_last_ledc_duty              = -1;
bool g_last_pump_state_written     = true;
bool g_firebase_write_called       = false;
int  g_last_sensor_moisture        = -1;
bool g_last_sensor_water_level_low = false;
bool g_sensor_write_called         = false;
unsigned long g_millis_value       = 0;

// ---------------------------------------------------------------------------
// 3. Define Firebase and Serial singletons
// ---------------------------------------------------------------------------
FirebaseClass Firebase;
SerialClass   Serial;

// ---------------------------------------------------------------------------
// 4. Define connectivity globals
// ---------------------------------------------------------------------------
FirebaseData   writeData;
FirebaseData   streamData;
FirebaseConfig fbConfig;
FirebaseAuth   fbAuth;

void onFirebaseStream(FirebaseStream /*data*/) {}
void onStreamTimeout(bool /*timeout*/) {}

// ---------------------------------------------------------------------------
// 5. Include firmware source files under test.
// ---------------------------------------------------------------------------
#include "../../src/firmware_state.cpp"
#include "../../src/pump_control.cpp"
#include "../../src/sensor_reporter.cpp"

// ---------------------------------------------------------------------------
// 6. Test framework headers
// ---------------------------------------------------------------------------
#include <gtest/gtest.h>
#include <rapidcheck.h>
#include <rapidcheck/gtest.h>

// ---------------------------------------------------------------------------
// Windows-specific boilerplate
// ---------------------------------------------------------------------------
#ifdef _WIN32
#ifndef UNICODE
#define UNICODE
#endif
#include <windows.h>
#include <cstdio>

int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}

int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int) {
    AllocConsole();
    FILE* fp = nullptr;
    freopen_s(&fp, "CONOUT$", "w", stdout);
    freopen_s(&fp, "CONOUT$", "w", stderr);
    freopen_s(&fp, "CONIN$",  "r", stdin);
    int argc = 1;
    static char prog[] = "test";
    static char* argv_arr[] = {prog, nullptr};
    int result = main(argc, argv_arr);
    FreeConsole();
    return result;
}
#endif

// Forward declaration of the test-only reset helper
void sensorLoopResetForTest();

// ---------------------------------------------------------------------------
// Helper: reset all mock globals and firmware state
// ---------------------------------------------------------------------------
static void resetMocks() {
    g_water_level_pin_value       = LOW;
    g_analog_read_value           = 0;
    g_last_ledc_channel           = -1;
    g_last_ledc_duty              = -1;
    g_last_pump_state_written     = true;
    g_firebase_write_called       = false;
    g_last_sensor_moisture        = -1;
    g_last_sensor_water_level_low = false;
    g_sensor_write_called         = false;

    firmwareState.pump_mode       = "manual";
    firmwareState.pump_speed      = 0;
    firmwareState.pump_switch     = false;
    firmwareState.pump_state      = false;
    firmwareState.moisture        = 0;
    firmwareState.water_level_low = false;

    sensorLoopResetForTest();

    // Set millis to exactly the 30-second threshold so the next sensorLoop() fires
    g_millis_value = 30000UL;
}

// ===========================================================================
// Property 9: Sensor Values Are Written to Firebase
//
// Feature: hydroponics-farm-management, Property 9: Sensor Values Are Written to Firebase
//
// For any moisture ∈ [0, 4095] and water_level_low ∈ {true, false}:
//   - Mock analogRead to return moisture
//   - Mock digitalRead to return water_level_low (HIGH or LOW)
//   - Call sensorLoop() after the 30-second interval has elapsed
//   - Assert Firebase.updateNode was called with the exact values
//
// Validates: Requirements 7.3
// ===========================================================================
RC_GTEST_PROP(SensorReporterProperty9,
              SensorValuesAreWrittenToFirebase,
              ())
{
    const auto moisture  = *rc::gen::inRange(0, 4096);
    const auto water_low = *rc::gen::arbitrary<bool>();

    resetMocks();

    g_analog_read_value     = moisture;
    g_water_level_pin_value = water_low ? HIGH : LOW;

    sensorLoop();

    RC_ASSERT(g_sensor_write_called == true);
    RC_ASSERT(g_last_sensor_moisture == moisture);
    RC_ASSERT(g_last_sensor_water_level_low == water_low);
}

// ===========================================================================
// Unit tests for sensorLoop
// ===========================================================================

TEST(SensorReporterUnit, TimerNotElapsed_NoReadNoWrite) {
    resetMocks();

    // Fire once to set lastSensorMs = 30000
    g_analog_read_value     = 1000;
    g_water_level_pin_value = LOW;
    sensorLoop();

    // Reset observation globals
    g_sensor_write_called         = false;
    g_last_sensor_moisture        = -1;
    g_last_sensor_water_level_low = false;
    g_analog_read_value           = 2000;

    // Advance to just before the next threshold (lastSensorMs=30000, next at 60000)
    g_millis_value = 59999UL;

    sensorLoop();   // must NOT fire

    EXPECT_FALSE(g_sensor_write_called);
    EXPECT_EQ(g_last_sensor_moisture, -1);
}

TEST(SensorReporterUnit, TimerElapsed_ReadsBothSensorsAndWritesFirebase) {
    resetMocks();

    g_analog_read_value     = 2048;
    g_water_level_pin_value = LOW;

    sensorLoop();

    EXPECT_TRUE(g_sensor_write_called);
    EXPECT_EQ(g_last_sensor_moisture, 2048);
    EXPECT_FALSE(g_last_sensor_water_level_low);
    EXPECT_EQ(firmwareState.moisture, 2048);
    EXPECT_FALSE(firmwareState.water_level_low);
}

TEST(SensorReporterUnit, WaterLevelLow_ApplyPumpStateFalseCalled) {
    resetMocks();

    firmwareState.pump_speed = 200;
    firmwareState.pump_state = true;

    g_analog_read_value     = 500;
    g_water_level_pin_value = HIGH;

    sensorLoop();

    EXPECT_EQ(g_last_ledc_duty, 0);
    EXPECT_TRUE(g_firebase_write_called);
    EXPECT_FALSE(g_last_pump_state_written);
}
