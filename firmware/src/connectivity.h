#pragma once

#include <Arduino.h>
#include <Firebase_ESP_Client.h>

// =============================================================================
// Global Firebase objects — shared across all firmware modules
// =============================================================================
extern FirebaseData   streamData;   // used for the TOWER_PATH stream subscription
extern FirebaseData   writeData;    // used for all outbound Firebase writes
extern FirebaseConfig fbConfig;     // Firebase project host + auth token
extern FirebaseAuth   fbAuth;       // Firebase authentication credentials

// =============================================================================
// Forward declarations for stream callbacks
// Implementations are provided in task 6.1 (onFirebaseStream) and 9.1 (onStreamTimeout).
// =============================================================================
void onFirebaseStream(FirebaseStream data);
void onStreamTimeout(bool timeout);

// =============================================================================
// connectivitySetup()
//
// Called once from setup().  Blocks until WiFi is connected (the only
// intentional blocking delay in the firmware), then authenticates with
// Firebase and subscribes to the TOWER_PATH stream.
//
// Requirements: 2.1, 2.2, 2.3
// =============================================================================
void connectivitySetup();

// =============================================================================
// connectivityLoop()
//
// Called on every loop() iteration.  Performs a non-blocking WiFi reconnect
// check so that connectivity is restored after a transient drop without
// stalling sensor reporting or pump control.
//
// Requirement: 2.4
// =============================================================================
void connectivityLoop();
