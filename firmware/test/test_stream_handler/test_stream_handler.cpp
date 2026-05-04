// Feature: hydroponics-farm-management
//
// Property-based and unit tests for onFirebaseStream() dispatch logic.
//
// Properties covered:
//   Property 2: Stream Callback Dispatches Mode Change        (Req 3.1)
//   Property 3: Stream Callback Applies Pump Speed to PWM    (Req 3.2, 6.2)
//   Property 4: Manual Mode — Pump Switch Controls Pump State (Req 3.3, 5.1, 5.2)
//   Property 7: Auto Mode Ignores Pump Switch                 (Req 5.4)
//
// Unit tests:
//   Each path branch dispatches to the correct handler         (Req 3.1–3.4)
//   Malformed data type is ignored without crash               (Req 3.1–3.4)
//
// Build note: STREAM_HANDLER_TEST suppresses the inline onFirebaseStream /
// onStreamTimeout stubs in test_support/connectivity.h so that the real
// implementations from stream_handler.cpp are used instead.

// ---------------------------------------------------------------------------
// 0. Define STREAM_HANDLER_TEST before any includes so that connectivity.h
//    does not emit its inline no-op stubs for onFirebaseStream / onStreamTimeout.
// ---------------------------------------------------------------------------
#define STREAM_HANDLER_TEST

// ---------------------------------------------------------------------------
// 1. Include fake SDK headers first.
//    These must come before any firmware source files so that the Arduino
//    types (String, HIGH, LOW) and Firebase stubs are defined before the
//    firmware headers try to use them.
// ---------------------------------------------------------------------------
#include <Arduino.h>             // fake: provides String, HIGH, LOW
#include <Firebase_ESP_Client.h> // fake: provides FirebaseData, FirebaseClass, etc.

// ---------------------------------------------------------------------------
// 2. Define mock globals (declared as extern in Firebase_ESP_Client.h)
// ---------------------------------------------------------------------------
int  g_water_level_pin_value   = 0;   // LOW by default (water OK)
int  g_last_ledc_channel       = -1;
int  g_last_ledc_duty          = -1;
bool g_last_pump_state_written = true;
bool g_firebase_write_called   = false;
unsigned long g_millis_value   = 0;

// millis() stub — declared extern in Arduino.h; defined here for this TU
unsigned long g_millis_value = 0;

// ---------------------------------------------------------------------------
// 3. Define Firebase and Serial singletons
// ---------------------------------------------------------------------------
FirebaseClass Firebase;
SerialClass   Serial;

// ---------------------------------------------------------------------------
// 4. Define connectivity globals (declared as extern in connectivity.h).
//    stream_handler.cpp includes connectivity.h which declares these as
//    extern; we provide the definitions here so the linker is satisfied.
//    (connectivity.h in test_support also provides inline definitions, but
//    those are guarded by STREAM_HANDLER_TEST for the stream callbacks.)
// ---------------------------------------------------------------------------
FirebaseData   writeData;
FirebaseData   streamData;
FirebaseConfig fbConfig;
FirebaseAuth   fbAuth;

// ---------------------------------------------------------------------------
// 5. Define stub AutoTimer struct and global instance.
//    stream_handler.cpp includes auto_timer.h (provided in test_support/).
//    We define the global autoTimer here so the linker finds it.
// ---------------------------------------------------------------------------
#include "../test_support/auto_timer.h"
AutoTimer autoTimer;

// ---------------------------------------------------------------------------
// 6. Include firmware source files under test.
//    firmware_state.cpp defines the firmwareState global.
//    pump_control.cpp  defines applyPumpState().
//    stream_handler.cpp defines onFirebaseStream() and the handler functions.
// ---------------------------------------------------------------------------
#include "../../src/firmware_state.cpp"
#include "../../src/pump_control.cpp"
#include "../../src/stream_handler.cpp"

// ---------------------------------------------------------------------------
// 7. Test framework headers
// ---------------------------------------------------------------------------
#include <gtest/gtest.h>
#include <rapidcheck.h>
#include <rapidcheck/gtest.h>

// ---------------------------------------------------------------------------
// Windows-specific: MinGW's libmingw32.a defaults to the Windows GUI subsystem
// which requires WinMain. We provide both main() and WinMain so the linker is
// satisfied on Windows.
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

// ---------------------------------------------------------------------------
// Helper: reset all mock globals and firmware state before each test case
// ---------------------------------------------------------------------------
static void resetMocks() {
    g_water_level_pin_value   = LOW;   // water OK
    g_last_ledc_channel       = -1;
    g_last_ledc_duty          = -1;
    g_last_pump_state_written = true;  // sentinel: true means "not yet written false"
    g_firebase_write_called   = false;

    firmwareState.pump_mode   = "manual";
    firmwareState.pump_speed  = 128;
    firmwareState.pump_switch = false;
    firmwareState.pump_state  = false;

    autoTimer.active         = false;
    autoTimer.onIntervalMs   = 0;
    autoTimer.offIntervalMs  = 0;
}

// Helper: build a FirebaseStream with the given path, type, and values
static FirebaseStream makeStream(const char* path,
                                 const char* type,
                                 const char* strVal = "",
                                 int         intVal = 0,
                                 bool        boolVal = false)
{
    FirebaseStream s;
    s._path    = path;
    s._type    = type;
    s._strVal  = strVal;
    s._intVal  = intVal;
    s._boolVal = boolVal;
    return s;
}

// ===========================================================================
// Property 2: Stream Callback Dispatches Mode Change
//
// Feature: hydroponics-farm-management, Property 2: Stream Callback Dispatches Mode Change
//
// For any pump_mode ∈ {"auto","manual"}, calling onFirebaseStream with path
// /pump_mode and that value must update firmwareState.pump_mode to the
// received value within the same callback invocation.
//
// Validates: Requirements 3.1
// ===========================================================================
RC_GTEST_PROP(StreamHandlerProperty2,
              StreamCallbackDispatchesModeChange,
              ())
{
    // Generate a mode index: 0 = "auto", 1 = "manual"
    const auto mode_idx = *rc::gen::inRange(0, 2);
    const char* modes[] = {"auto", "manual"};
    const char* chosen_mode = modes[mode_idx];

    resetMocks();

    FirebaseStream s = makeStream("/pump_mode", "string", chosen_mode);
    onFirebaseStream(s);

    RC_ASSERT(firmwareState.pump_mode == chosen_mode);
}

// ===========================================================================
// Property 3: Stream Callback Applies Pump Speed to PWM
//
// Feature: hydroponics-farm-management, Property 3: Stream Callback Applies Pump Speed to PWM
//
// For any pump_speed ∈ [0, 255], when onFirebaseStream is called with path
// /pump_speed and that value while the pump is on and water level is not low,
// ledcWrite must be called with that exact duty cycle value.
//
// Validates: Requirements 3.2, 6.2
// ===========================================================================
RC_GTEST_PROP(StreamHandlerProperty3,
              StreamCallbackAppliesPumpSpeedToPWM,
              ())
{
    // Generate pump_speed in [0, 255]
    const auto speed = *rc::gen::inRange(0, 256);   // inRange is [lo, hi)

    resetMocks();

    // Pump is on and water is OK so the new speed takes effect immediately
    firmwareState.pump_state = true;
    g_water_level_pin_value  = LOW;

    FirebaseStream s = makeStream("/pump_speed", "int", "", speed);
    onFirebaseStream(s);

    // firmwareState.pump_speed must be updated
    RC_ASSERT(firmwareState.pump_speed == speed);

    // ledcWrite must have been called with the new speed (pump is on, water ok)
    RC_ASSERT(g_last_ledc_duty == speed);
}

// ===========================================================================
// Property 4: Manual Mode — Pump Switch Controls Pump State
//
// Feature: hydroponics-farm-management, Property 4: Manual Mode — Pump Switch Controls Pump State
//
// For any pump_switch ∈ {true, false}, when pump_mode is "manual" and water
// level is OK, calling onFirebaseStream with path /pump_switch must result in
// the pump state (ledcWrite duty cycle) matching the switch value.
//
// Validates: Requirements 3.3, 5.1, 5.2
// ===========================================================================
RC_GTEST_PROP(StreamHandlerProperty4,
              ManualModePumpSwitchControlsPumpState,
              ())
{
    const auto pump_sw = *rc::gen::arbitrary<bool>();

    resetMocks();

    firmwareState.pump_mode  = "manual";
    firmwareState.pump_speed = 200;   // non-zero so we can detect PWM value
    g_water_level_pin_value  = LOW;   // water OK

    FirebaseStream s = makeStream("/pump_switch", "boolean", "", 0, pump_sw);
    onFirebaseStream(s);

    if (pump_sw) {
        // Switch on → pump should be on → PWM = pump_speed
        RC_ASSERT(g_last_ledc_duty == firmwareState.pump_speed);
    } else {
        // Switch off → pump should be off → PWM = 0
        RC_ASSERT(g_last_ledc_duty == 0);
    }
}

// ===========================================================================
// Property 7: Auto Mode Ignores Pump Switch
//
// Feature: hydroponics-farm-management, Property 7: Auto Mode Ignores Pump Switch
//
// For any pump_switch ∈ {true, false}, when pump_mode is "auto", calling
// onFirebaseStream with path /pump_switch must produce no change in pump state
// (ledcWrite must not be called).
//
// Validates: Requirements 5.4
// ===========================================================================
RC_GTEST_PROP(StreamHandlerProperty7,
              AutoModeIgnoresPumpSwitch,
              ())
{
    const auto pump_sw = *rc::gen::arbitrary<bool>();

    resetMocks();

    firmwareState.pump_mode  = "auto";
    firmwareState.pump_speed = 200;
    g_water_level_pin_value  = LOW;

    // Record the duty cycle before the callback — it should not change
    const int duty_before = g_last_ledc_duty;   // -1 (sentinel from resetMocks)

    FirebaseStream s = makeStream("/pump_switch", "boolean", "", 0, pump_sw);
    onFirebaseStream(s);

    // ledcWrite must NOT have been called (duty stays at sentinel -1)
    RC_ASSERT(g_last_ledc_duty == duty_before);
}

// ===========================================================================
// Unit tests for onFirebaseStream dispatch
//
// Requirements: 3.1, 3.2, 3.3, 3.4
// ===========================================================================

// ---------------------------------------------------------------------------
// Test: /pump_mode with type "string" → handleModeChange called, mode updated
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpModePath_StringType_UpdatesMode) {
    resetMocks();

    FirebaseStream s = makeStream("/pump_mode", "string", "auto");
    onFirebaseStream(s);

    EXPECT_EQ(firmwareState.pump_mode, "auto");
}

// ---------------------------------------------------------------------------
// Test: /pump_mode "auto" → autoTimer activated
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpModeAuto_ActivatesAutoTimer) {
    resetMocks();

    FirebaseStream s = makeStream("/pump_mode", "string", "auto");
    onFirebaseStream(s);

    EXPECT_TRUE(autoTimer.active);
}

// ---------------------------------------------------------------------------
// Test: /pump_mode "manual" → autoTimer deactivated
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpModeManual_DeactivatesAutoTimer) {
    resetMocks();
    autoTimer.active = true;   // start with timer active

    FirebaseStream s = makeStream("/pump_mode", "string", "manual");
    onFirebaseStream(s);

    EXPECT_FALSE(autoTimer.active);
}

// ---------------------------------------------------------------------------
// Test: /pump_speed with type "int" → firmwareState.pump_speed updated
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpSpeedPath_IntType_UpdatesSpeed) {
    resetMocks();

    FirebaseStream s = makeStream("/pump_speed", "int", "", 175);
    onFirebaseStream(s);

    EXPECT_EQ(firmwareState.pump_speed, 175);
}

// ---------------------------------------------------------------------------
// Test: /pump_speed while pump is on → ledcWrite called with new speed
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpSpeedPath_PumpOn_LedcWriteCalledWithNewSpeed) {
    resetMocks();
    firmwareState.pump_state = true;
    firmwareState.pump_speed = 50;
    g_water_level_pin_value  = LOW;

    FirebaseStream s = makeStream("/pump_speed", "int", "", 220);
    onFirebaseStream(s);

    EXPECT_EQ(g_last_ledc_duty, 220);
}

// ---------------------------------------------------------------------------
// Test: /pump_switch with type "boolean" in manual mode → applyPumpState called
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpSwitchPath_ManualMode_AppliesPumpState) {
    resetMocks();
    firmwareState.pump_mode  = "manual";
    firmwareState.pump_speed = 150;
    g_water_level_pin_value  = LOW;

    FirebaseStream s = makeStream("/pump_switch", "boolean", "", 0, true);
    onFirebaseStream(s);

    EXPECT_EQ(g_last_ledc_duty, 150);
}

// ---------------------------------------------------------------------------
// Test: /pump_switch in auto mode → no pump state change (Req 5.4)
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpSwitchPath_AutoMode_NoPumpStateChange) {
    resetMocks();
    firmwareState.pump_mode  = "auto";
    firmwareState.pump_speed = 150;
    g_water_level_pin_value  = LOW;

    const int duty_before = g_last_ledc_duty;   // -1 sentinel

    FirebaseStream s = makeStream("/pump_switch", "boolean", "", 0, true);
    onFirebaseStream(s);

    EXPECT_EQ(g_last_ledc_duty, duty_before);
}

// ---------------------------------------------------------------------------
// Test: /interval_on_min with type "int" → autoTimer.setOnInterval called
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, IntervalOnMinPath_IntType_SetsOnInterval) {
    resetMocks();

    FirebaseStream s = makeStream("/interval_on_min", "int", "", 5);
    onFirebaseStream(s);

    // setOnInterval stores the raw int value from the stream
    EXPECT_EQ(autoTimer.onIntervalMs, 5);
}

// ---------------------------------------------------------------------------
// Test: /interval_off_min with type "int" → autoTimer.setOffInterval called
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, IntervalOffMinPath_IntType_SetsOffInterval) {
    resetMocks();

    FirebaseStream s = makeStream("/interval_off_min", "int", "", 10);
    onFirebaseStream(s);

    EXPECT_EQ(autoTimer.offIntervalMs, 10);
}

// ---------------------------------------------------------------------------
// Test: /pump_mode with wrong type → mode NOT updated (malformed data ignored)
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpModePath_WrongType_ModeNotUpdated) {
    resetMocks();
    firmwareState.pump_mode = "manual";

    // Send type "int" instead of "string" — should be ignored
    FirebaseStream s = makeStream("/pump_mode", "int", "", 1);
    onFirebaseStream(s);

    EXPECT_EQ(firmwareState.pump_mode, "manual");   // unchanged
}

// ---------------------------------------------------------------------------
// Test: /pump_speed with wrong type → speed NOT updated (malformed data ignored)
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpSpeedPath_WrongType_SpeedNotUpdated) {
    resetMocks();
    firmwareState.pump_speed = 100;

    // Send type "string" instead of "int" — should be ignored
    FirebaseStream s = makeStream("/pump_speed", "string", "fast");
    onFirebaseStream(s);

    EXPECT_EQ(firmwareState.pump_speed, 100);   // unchanged
}

// ---------------------------------------------------------------------------
// Test: /pump_switch with wrong type → no pump state change (malformed ignored)
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, PumpSwitchPath_WrongType_NoPumpStateChange) {
    resetMocks();
    firmwareState.pump_mode  = "manual";
    firmwareState.pump_speed = 150;

    const int duty_before = g_last_ledc_duty;   // -1 sentinel

    // Send type "string" instead of "boolean" — should be ignored
    FirebaseStream s = makeStream("/pump_switch", "string", "true");
    onFirebaseStream(s);

    EXPECT_EQ(g_last_ledc_duty, duty_before);
}

// ---------------------------------------------------------------------------
// Test: unknown path → no crash, no state change
// ---------------------------------------------------------------------------
TEST(StreamHandlerUnit, UnknownPath_NoStateChange) {
    resetMocks();
    firmwareState.pump_mode  = "manual";
    firmwareState.pump_speed = 100;

    const int duty_before = g_last_ledc_duty;

    FirebaseStream s = makeStream("/unknown_field", "string", "value");
    onFirebaseStream(s);

    // Nothing should have changed
    EXPECT_EQ(firmwareState.pump_mode,  "manual");
    EXPECT_EQ(firmwareState.pump_speed, 100);
    EXPECT_EQ(g_last_ledc_duty, duty_before);
}
