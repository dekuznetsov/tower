#include <Arduino.h>
#include <Firebase_ESP_Client.h>

#include "auto_timer.h"
#include "config.h"
#include "connectivity.h"
#include "sensor_reporter.h"
#include "stream_handler.h"

// -----------------------------------------------------------------------------
// pwmSetup() — configure LEDC PWM controller and ensure duty cycle starts at 0
// Requirement 6.1: GPIO 18, LEDC channel 0, 5000 Hz, 8-bit resolution
// -----------------------------------------------------------------------------
void pwmSetup() {
    ledcSetup(PWM_CHANNEL, PWM_FREQ, PWM_RESOLUTION);  // ch 0, 5000 Hz, 8-bit
    ledcAttachPin(PUMP_GPIO, PWM_CHANNEL);              // GPIO 18
    ledcWrite(PWM_CHANNEL, 0);                          // duty cycle 0 on startup
}

// -----------------------------------------------------------------------------
// setup() — runs once on power-on / reset
// -----------------------------------------------------------------------------
void setup() {
    Serial.begin(115200);  // debug output

    pwmSetup();            // Task 2.2 — PWM controller initialisation
    connectivitySetup();   // Task 3.1 — WiFi connect + Firebase auth + stream subscription
}

// -----------------------------------------------------------------------------
// loop() — runs repeatedly after setup()
// -----------------------------------------------------------------------------
void loop() {
    connectivityLoop();  // Task 3.2 — non-blocking WiFi reconnect (Requirement 2.4)
    autoTimer.tick();    // Task 7.2 — auto mode timer tick (Requirements 4.1, 4.2)
    sensorLoop();        // Task 8.2 — sensor reporter (Requirements 7.1, 7.2, 7.3, 7.4)
}
