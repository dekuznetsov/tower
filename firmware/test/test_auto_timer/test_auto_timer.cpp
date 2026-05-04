// Feature: hydroponics-farm-management
//
// Property-based and unit tests for AutoTimer.
//
// Properties covered:
//   Property 5: Auto Timer Cycles at Correct Intervals   (Req 3.4, 4.1)
//   Property 8: PWM Duty Cycle Matches Pump On/Off State (Req 6.3, 6.4)
//
// Unit tests:
//   Timer inactive → no toggle                           (Req 4.1)
//   Elapsed < interval → no toggle                       (Req 4.1)
//   Elapsed ≥ off interval → pump turns on               (Req 4.1, 4.2, 4.3)
//   Elapsed ≥ on interval → pump turns off               (Req 4.1, 4.2, 4.3)

// ---------------------------------------------------------------------------
// 1. Include fake SDK headers first.
// ---------------------------------------------------------------------------
#include <Arduino.h>             // fake: provides String, HIGH, LOW, millis()
#include <Firebase_ESP_Client.h> // fake: provides FirebaseData, FirebaseClass, etc.

// ---------------------------------------------------------------------------
// 2. Define mock globals
// ---------------------------------------------------------------------------
int  g_water_level_pin_value   = 0;
int  g_last_ledc_channel       = -1;
int  g_last_ledc_duty          = -1;
bool g_last_pump_state_written = true;
bool g_firebase_write_called   = false;
unsigned long g_millis_value   = 0;

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
#include "../../src/auto_timer.cpp"

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

// ---------------------------------------------------------------------------
// Helper: reset all mock globals and firmware state
// ---------------------------------------------------------------------------
static void resetMocks() {
    g_water_level_pin_value   = LOW;
    g_last_ledc_channel       = -1;
    g_last_ledc_duty          = -1;
    g_last_pump_state_written = true;
    g_firebase_write_called   = false;
    g_millis_value            = 0;

    firmwareState.pump_mode   = "auto";
    firmwareState.pump_speed  = 128;
    firmwareState.pump_switch = false;
    firmwareState.pump_state  = false;

    autoTimer.active         = false;
    autoTimer.pumpOn         = false;
    autoTimer.lastToggleMs   = 0;
    autoTimer.onIntervalMs   = 60000UL;
    autoTimer.offIntervalMs  = 60000UL;
}

// ===========================================================================
// Property 5: Auto Timer Cycles at Correct Intervals
//
// Feature: hydroponics-farm-management, Property 5: Auto Timer Cycles at Correct Intervals
//
// For any on_min ∈ [1, 60] and off_min ∈ [1, 60]:
//   1. Activate timer at t=0 (pumpOn=false, first phase is OFF).
//   2. At off_min*60000-1 ms: tick() must NOT toggle.
//   3. At off_min*60000 ms: tick() MUST toggle (pump turns on).
//
// Validates: Requirements 3.4, 4.1
// ===========================================================================
RC_GTEST_PROP(AutoTimerProperty5,
              AutoTimerCyclesAtCorrectIntervals,
              ())
{
    const auto on_min  = *rc::gen::inRange(1, 61);
    const auto off_min = *rc::gen::inRange(1, 61);

    resetMocks();

    autoTimer.setOnInterval(on_min);
    autoTimer.setOffInterval(off_min);
    g_millis_value = 0;
    autoTimer.activate();   // pumpOn=false, lastToggleMs=0

    const unsigned long off_threshold_ms =
        static_cast<unsigned long>(off_min) * 60000UL;

    // One ms before threshold — no toggle
    g_millis_value = off_threshold_ms - 1UL;
    autoTimer.tick();

    RC_ASSERT(!autoTimer.pumpOn);
    RC_ASSERT(g_last_ledc_duty != firmwareState.pump_speed);

    // Exactly at threshold — must toggle
    g_millis_value = off_threshold_ms;
    autoTimer.tick();

    RC_ASSERT(autoTimer.pumpOn);
    RC_ASSERT(g_last_ledc_duty == firmwareState.pump_speed);
}

// ===========================================================================
// Property 8: PWM Duty Cycle Matches Pump On/Off State
//
// Feature: hydroponics-farm-management, Property 8: PWM Duty Cycle Matches Pump On/Off State
//
// For any pump_speed ∈ [0, 255] and pump_state ∈ {true, false}:
//   - pump off → ledcWrite(0)
//   - pump on, water ok → ledcWrite(pump_speed)
//
// Validates: Requirements 6.3, 6.4
// ===========================================================================
RC_GTEST_PROP(AutoTimerProperty8,
              PWMDutyCycleMatchesPumpOnOffState,
              ())
{
    const auto speed      = *rc::gen::inRange(0, 256);
    const auto pump_state = *rc::gen::arbitrary<bool>();

    resetMocks();

    firmwareState.pump_speed = speed;
    firmwareState.pump_state = !pump_state;  // start from opposite so state-change write fires
    g_water_level_pin_value  = LOW;

    applyPumpState(pump_state);

    if (pump_state) {
        RC_ASSERT(g_last_ledc_duty == speed);
    } else {
        RC_ASSERT(g_last_ledc_duty == 0);
    }
}

// ===========================================================================
// Unit tests for AutoTimer
// ===========================================================================

TEST(AutoTimerUnit, TimerInactive_NoToggle) {
    resetMocks();

    autoTimer.active        = false;
    autoTimer.pumpOn        = false;
    autoTimer.lastToggleMs  = 0;
    autoTimer.onIntervalMs  = 1000UL;
    autoTimer.offIntervalMs = 1000UL;

    g_millis_value = 999999UL;
    autoTimer.tick();

    EXPECT_FALSE(autoTimer.pumpOn);
    EXPECT_EQ(g_last_ledc_duty, -1);
}

TEST(AutoTimerUnit, ElapsedLessThanInterval_NoToggle) {
    resetMocks();

    autoTimer.setOffInterval(5);   // 300000 ms
    g_millis_value = 0;
    autoTimer.activate();

    g_millis_value = 299999UL;
    autoTimer.tick();

    EXPECT_FALSE(autoTimer.pumpOn);
    EXPECT_EQ(g_last_ledc_duty, -1);
}

TEST(AutoTimerUnit, ElapsedGeOffInterval_PumpTurnsOn) {
    resetMocks();

    firmwareState.pump_speed = 200;
    firmwareState.pump_state = false;

    autoTimer.setOffInterval(2);   // 120000 ms
    autoTimer.setOnInterval(3);    // 180000 ms
    g_millis_value = 0;
    autoTimer.activate();

    g_millis_value = 120000UL;
    autoTimer.tick();

    EXPECT_TRUE(autoTimer.pumpOn);
    EXPECT_EQ(g_last_ledc_duty, 200);
    EXPECT_TRUE(g_firebase_write_called);
}

TEST(AutoTimerUnit, ElapsedGeOnInterval_PumpTurnsOff) {
    resetMocks();

    firmwareState.pump_speed = 200;
    firmwareState.pump_state = true;

    autoTimer.active        = true;
    autoTimer.pumpOn        = true;
    autoTimer.lastToggleMs  = 0;
    autoTimer.setOnInterval(3);    // 180000 ms
    autoTimer.setOffInterval(2);   // 120000 ms

    g_millis_value = 180000UL;
    autoTimer.tick();

    EXPECT_FALSE(autoTimer.pumpOn);
    EXPECT_EQ(g_last_ledc_duty, 0);
    EXPECT_TRUE(g_firebase_write_called);
    EXPECT_FALSE(g_last_pump_state_written);
}
