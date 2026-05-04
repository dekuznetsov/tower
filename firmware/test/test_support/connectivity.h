#pragma once
// Fake connectivity.h for native host testing.
// Provides the writeData global and stub callback declarations that
// pump_control.cpp depends on, without pulling in the real Firebase SDK.

// Firebase_ESP_Client.h is already included (or stubbed) before this header.
// writeData is defined here as an inline global.
inline FirebaseData writeData;
inline FirebaseData streamData;
inline FirebaseConfig fbConfig;
inline FirebaseAuth   fbAuth;

// Stream callback stubs — no-op implementations.
// When STREAM_HANDLER_TEST is defined (i.e. when building test_stream_handler.cpp),
// these stubs are suppressed because stream_handler.cpp provides the real definitions.
#ifndef STREAM_HANDLER_TEST
inline void onFirebaseStream(FirebaseStream /*data*/) {}
inline void onStreamTimeout(bool /*timeout*/) {}
#endif

// Connectivity function stubs
inline void connectivitySetup() {}
inline void connectivityLoop()  {}
