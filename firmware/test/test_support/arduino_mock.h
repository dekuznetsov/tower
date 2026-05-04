#pragma once
// =============================================================================
// arduino_mock.h — Convenience header that documents the mock/stub strategy
// for native host testing of ESP32 firmware.
//
// The actual stubs are split across two files in this directory:
//
//   Arduino.h              — Fake Arduino.h: provides String, HIGH, LOW
//   Firebase_ESP_Client.h  — Fake Firebase SDK: provides FirebaseData,
//                            FirebaseClass, SerialClass, and hardware stubs
//                            (digitalRead, ledcWrite, etc.)
//
// Both files are found automatically by the compiler because test/test_support/
// is added to the include path in platformio.ini (before src/).
//
// Mock globals (defined in the test file, declared extern in Firebase_ESP_Client.h):
//   g_water_level_pin_value   — value returned by digitalRead()
//   g_last_ledc_channel       — last channel passed to ledcWrite()
//   g_last_ledc_duty          — last duty cycle passed to ledcWrite()
//   g_last_pump_state_written — last pump_state value written via Firebase.setBool
//   g_firebase_write_called   — true if Firebase.setBool was called at least once
// =============================================================================

#include <Arduino.h>
#include <Firebase_ESP_Client.h>
