// Feature: hydroponics-farm-management, Property 10: Safety Interlock Overrides All Pump Activation
//
// Property-based test for applyPumpState() safety interlock.
// Uses rapidcheck to generate random pump_mode / pump_switch combinations
// and asserts that when water is low (digitalRead returns HIGH), the pump
// is always forced off regardless of any other control input.
//
// Validates: Requirements 8.1, 8.2, 8.3
//
// Build note: The test/test_support/ directory is added to the include path
// in platformio.ini so that fake Arduino.h and Firebase_ESP_Client.h shadow
// the real SDK headers during native host compilation.

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
int  g_water_level_pin_value   = 0;   // LOW by default
int  g_last_ledc_channel       = -1;
int  g_last_ledc_duty          = -1;
bool g_last_pump_state_written = true;
bool g_firebase_write_called   = false;
unsigned long g_millis_value   = 0;

// millis() stub — declared extern in Arduino.h; defined here for this TU
unsigned long g_millis_value = 0;

// Firebase and Serial singletons
FirebaseClass Firebase;
SerialClass   Serial;

// ---------------------------------------------------------------------------
// 3. Define the globals that connectivity.h declares as extern.
//    pump_control.cpp includes connectivity.h which has:
//      extern FirebaseData writeData;
//    We provide the definitions here so the linker is satisfied.
// ---------------------------------------------------------------------------
FirebaseData   writeData;
FirebaseData   streamData;
FirebaseConfig fbConfig;
FirebaseAuth   fbAuth;

// Stub the stream callbacks declared in connectivity.h
void onFirebaseStream(FirebaseStream /*data*/) {}
void onStreamTimeout(bool /*timeout*/) {}

// ---------------------------------------------------------------------------
// 4. Include firmware source files under test.
//    firmware_state.cpp defines the firmwareState global.
//    pump_control.cpp defines applyPumpState().
// ---------------------------------------------------------------------------
#include "../../src/firmware_state.cpp"
#include "../../src/pump_control.cpp"

// ---------------------------------------------------------------------------
// 5. Test framework headers
// ---------------------------------------------------------------------------
#include <gtest/gtest.h>
#include <rapidcheck.h>
#include <rapidcheck/gtest.h>

// ---------------------------------------------------------------------------
// Windows-specific: MinGW's libmingw32.a defaults to the Windows GUI subsystem
// which requires WinMain. We provide both main() (for the test runner) and
// WinMain (for the Windows GUI startup code) so the linker is satisfied.
// ---------------------------------------------------------------------------
#ifdef _WIN32
#ifndef UNICODE
#define UNICODE
#endif
#include <windows.h>
#include <cstdio>

// main() — the real test entry point used by GoogleTest
int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}

// WinMain — required by libmingw32.a (Windows GUI subsystem startup)
int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int) {
    AllocConsole();
    FILE* fp = nullptr;
    freopen_s(&fp, "CONOUT$", "w", stdout);
    freopen_s(&fp, "CONOUT$", "w", stderr);
    freopen_s(&fp, "CONIN$",  "r", stdin);
    int argc = 1;
    static char prog[] = "test";
    static char* argv[] = {prog, nullptr};
    int result = main(argc, argv);
    FreeConsole();
    return result;
}
#endif

// ---------------------------------------------------------------------------
// Helper: reset all mock globals and firmware state before each test case
// ---------------------------------------------------------------------------
static void resetMocks() {
    g_water_level_pin_value   = LOW;
    g_last_ledc_channel       = -1;
    g_last_ledc_duty          = -1;
    g_last_pump_state_written = true;   // sentinel: true means "not yet written false"
    g_firebase_write_called   = false;

    firmwareState.pump_mode    = "manual";
    firmwareState.pump_speed   = 128;   // non-zero so we can detect if it leaks through
    firmwareState.pump_switch  = false;
    firmwareState.pump_state   = false;
}

// ===========================================================================
// Property 10: Safety Interlock Overrides All Pump Activation
//
// For any combination of pump_mode ∈ {"auto","manual"} and
// pump_switch ∈ {true, false}, when water is low (digitalRead returns HIGH),
// calling applyPumpState(true) must:
//   - call ledcWrite with duty cycle 0  (Requirement 8.1)
//   - write pump_state = false to Firebase  (Requirement 8.2, 8.3)
// ===========================================================================
RC_GTEST_PROP(PumpControlProperty10,
              SafetyInterlockOverridesAllPumpActivation,
              ())
{
    // Generate random pump_mode and pump_switch
    const auto mode_idx = *rc::gen::inRange(0, 2);   // 0 = "auto", 1 = "manual"
    const auto pump_sw  = *rc::gen::arbitrary<bool>();

    const char* modes[] = {"auto", "manual"};
    const char* chosen_mode = modes[mode_idx];

    resetMocks();

    // Configure firmware state with generated values
    firmwareState.pump_mode   = chosen_mode;
    firmwareState.pump_switch = pump_sw;
    firmwareState.pump_speed  = 200;   // non-zero to confirm interlock overrides it

    // Set water level LOW (sensor active-HIGH means water IS low)
    g_water_level_pin_value = HIGH;

    // Request pump on — the safety interlock must override this
    applyPumpState(true);

    // Requirement 8.1: PWM duty cycle must be 0 regardless of pump_speed
    RC_ASSERT(g_last_ledc_duty == 0);

    // Requirement 8.2 / 8.3: pump_state must be written as false to Firebase
    RC_ASSERT(g_firebase_write_called == true);
    RC_ASSERT(g_last_pump_state_written == false);
}

// ===========================================================================
// Property 11: Safety Interlock Clears on Water Restored
//
// Feature: hydroponics-farm-management, Property 11: Safety Interlock Clears on Water Restored
//
// For any pump_mode ∈ {"auto","manual"} and pump_switch ∈ {true,false}:
//   1. Simulate water low: set g_water_level_pin_value = HIGH, call
//      applyPumpState(true) — interlock must force PWM to 0.
//   2. Simulate water restored: set g_water_level_pin_value = LOW, call
//      applyPumpState(pump_switch) — the operator's intent.
//   3. Assert that when pump_switch == true, PWM == firmwareState.pump_speed
//      (pump resumes).
//   4. Assert that when pump_switch == false, PWM == 0 (pump stays off).
//
// Validates: Requirements 8.4
// ===========================================================================
RC_GTEST_PROP(PumpControlProperty11,
              SafetyInterlockClearsOnWaterRestored,
              ())
{
    // Generate random pump_mode and pump_switch
    const auto mode_idx = *rc::gen::inRange(0, 2);   // 0 = "auto", 1 = "manual"
    const auto pump_sw  = *rc::gen::arbitrary<bool>();

    const char* modes[] = {"auto", "manual"};
    const char* chosen_mode = modes[mode_idx];

    resetMocks();

    // Configure firmware state with generated values
    firmwareState.pump_mode   = chosen_mode;
    firmwareState.pump_switch = pump_sw;
    firmwareState.pump_speed  = 200;   // non-zero so we can detect if it leaks through
    firmwareState.pump_state  = false; // start from off

    // -----------------------------------------------------------------------
    // Step 1: Simulate water low — interlock must force PWM to 0
    // -----------------------------------------------------------------------
    g_water_level_pin_value = HIGH;   // water IS low (active-HIGH sensor)
    applyPumpState(true);

    RC_ASSERT(g_last_ledc_duty == 0);

    // -----------------------------------------------------------------------
    // Step 2: Simulate water restored — pump should resume per pump_switch
    // -----------------------------------------------------------------------
    g_water_level_pin_value = LOW;    // water level OK
    // Reset pump_state so the state-change write fires correctly
    firmwareState.pump_state = false;
    g_firebase_write_called  = false;

    applyPumpState(pump_sw);

    // -----------------------------------------------------------------------
    // Step 3 & 4: Assert correct PWM based on operator intent
    // -----------------------------------------------------------------------
    if (pump_sw) {
        // Pump requested on and water is OK → PWM must equal pump_speed
        RC_ASSERT(g_last_ledc_duty == firmwareState.pump_speed);
    } else {
        // Pump requested off → PWM must be 0
        RC_ASSERT(g_last_ledc_duty == 0);
    }
}

// ===========================================================================
// Task 5.4 — Unit tests for applyPumpState
//
// These three tests exercise the three core behaviours of applyPumpState()
// in isolation, using concrete inputs rather than random generation.
//
// Requirements: 8.1, 8.2, 6.3, 6.4
// ===========================================================================

// Test 1: pump on, water ok → ledcWrite called with pump_speed (Req 6.4)
TEST(ApplyPumpStateUnit, PumpOnWaterOk_LedcWriteCalledWithPumpSpeed) {
    resetMocks();

    firmwareState.pump_speed = 150;
    firmwareState.pump_state = false;   // start from off so state-change write fires

    g_water_level_pin_value = LOW;      // water OK

    applyPumpState(true);

    EXPECT_EQ(g_last_ledc_duty, 150);
}

// Test 2: pump off → ledcWrite called with 0 (Req 6.3)
TEST(ApplyPumpStateUnit, PumpOff_LedcWriteCalledWithZero) {
    resetMocks();

    firmwareState.pump_speed = 200;
    firmwareState.pump_state = true;    // start from on so state-change write fires

    g_water_level_pin_value = LOW;      // water OK

    applyPumpState(false);

    EXPECT_EQ(g_last_ledc_duty, 0);
}

// Test 3: pump on, water low → ledcWrite called with 0, pump_state written false
//         (Req 8.1 — PWM forced to 0; Req 8.2 — pump_state=false written to Firebase)
TEST(ApplyPumpStateUnit, PumpOnWaterLow_LedcZeroAndPumpStateFalse) {
    resetMocks();

    firmwareState.pump_speed = 200;
    firmwareState.pump_state = false;   // already false; interlock must force-write it anyway

    g_water_level_pin_value = HIGH;     // water IS low (active-HIGH sensor)

    applyPumpState(true);

    EXPECT_EQ(g_last_ledc_duty, 0);
    EXPECT_EQ(g_last_pump_state_written, false);
    EXPECT_EQ(g_firebase_write_called, true);
}

// ===========================================================================
// Sanity unit test: when water is OK and pump is requested on, PWM > 0
// (ensures the mock is wired correctly and the interlock only fires on HIGH)
// ===========================================================================
TEST(PumpControlUnit, WaterOkPumpOnWritesNonZeroDuty) {
    resetMocks();

    firmwareState.pump_mode  = "manual";
    firmwareState.pump_speed = 150;
    firmwareState.pump_state = false;   // start from off so state changes

    g_water_level_pin_value = LOW;   // water OK

    applyPumpState(true);

    EXPECT_EQ(g_last_ledc_duty, 150);
}

// ===========================================================================
// Sanity unit test: when pump is requested off, PWM is always 0
// ===========================================================================
TEST(PumpControlUnit, PumpOffWritesZeroDuty) {
    resetMocks();

    firmwareState.pump_mode  = "manual";
    firmwareState.pump_speed = 200;
    firmwareState.pump_state = true;   // start from on so state changes

    g_water_level_pin_value = LOW;   // water OK

    applyPumpState(false);

    EXPECT_EQ(g_last_ledc_duty, 0);
}
