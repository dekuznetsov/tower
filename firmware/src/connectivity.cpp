#include "connectivity.h"
#include "config.h"

// =============================================================================
// Global Firebase object definitions
// Declared extern in connectivity.h; defined here so the linker finds exactly
// one copy regardless of how many translation units include the header.
// =============================================================================
FirebaseData   streamData;
FirebaseData   writeData;
FirebaseConfig fbConfig;
FirebaseAuth   fbAuth;

// =============================================================================
// connectivitySetup()
//
// 1. Connects to WiFi — blocks with delay(100) until WL_CONNECTED.
//    This is the only intentional blocking delay in the firmware (Requirement 2.1).
// 2. Configures FirebaseConfig with FIREBASE_HOST and FIREBASE_AUTH,
//    then calls Firebase.begin() and Firebase.reconnectWiFi() (Requirement 2.2).
// 3. Subscribes to the TOWER_PATH stream and registers the stream callbacks
//    (Requirement 2.3).
// =============================================================================
void connectivitySetup() {
    // -------------------------------------------------------------------------
    // Step 1 — WiFi connection (blocking, acceptable in setup() only)
    // -------------------------------------------------------------------------
    Serial.print("Connecting to WiFi");
    WiFi.begin(SSID, PASSWORD);

    while (WiFi.status() != WL_CONNECTED) {
        delay(100);
        Serial.print(".");
    }

    Serial.println();
    Serial.print("WiFi connected. IP address: ");
    Serial.println(WiFi.localIP());

    // -------------------------------------------------------------------------
    // Step 2 — Firebase authentication
    // -------------------------------------------------------------------------
    fbConfig.host = FIREBASE_HOST;
    fbConfig.signer.tokens.legacy_token = FIREBASE_AUTH;

    Firebase.begin(&fbConfig, &fbAuth);
    Firebase.reconnectWiFi(true);

    Serial.println("Firebase initialised.");

    // -------------------------------------------------------------------------
    // Step 3 — Stream subscription for TOWER_PATH
    // onFirebaseStream and onStreamTimeout are forward-declared in this header;
    // their bodies are provided in tasks 6.1 and 9.1 respectively.
    // -------------------------------------------------------------------------
    if (!Firebase.beginStream(streamData, TOWER_PATH)) {
        Serial.print("Firebase stream begin failed: ");
        Serial.println(streamData.errorReason().c_str());
    } else {
        Serial.print("Firebase stream started on path: ");
        Serial.println(TOWER_PATH);
    }

    Firebase.setStreamCallback(streamData, onFirebaseStream, onStreamTimeout);
}

// =============================================================================
// connectivityLoop()
//
// Non-blocking WiFi reconnect check.  Called on every loop() iteration.
// Does not block; pump control and sensor reporting continue uninterrupted.
// Requirement: 2.4
// =============================================================================
void connectivityLoop() {
    if (WiFi.status() != WL_CONNECTED) {
        WiFi.reconnect();
    }
}
