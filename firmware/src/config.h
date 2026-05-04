#pragma once

// =============================================================================
// Network credentials
// TODO: Fill in your WiFi SSID and password before flashing.
// =============================================================================
#define SSID     "YOUR_WIFI_SSID"
#define PASSWORD "YOUR_WIFI_PASSWORD"

// =============================================================================
// Firebase credentials
// TODO: Fill in your Firebase project host and legacy database secret (or
//       service-account token) before flashing.
// =============================================================================
#define FIREBASE_HOST "YOUR_PROJECT_ID.firebaseio.com"
#define FIREBASE_AUTH "YOUR_DATABASE_SECRET_OR_TOKEN"

// =============================================================================
// Firebase Realtime Database paths
// =============================================================================
#define TOWER_PATH   "farms/farm_id_1/towers/tower_1"
#define SENSORS_PATH "farms/farm_id_1/towers/tower_1/sensors"

// =============================================================================
// GPIO pin assignments
// =============================================================================
#define PUMP_GPIO        18   // MOSFET gate — PWM output
#define MOISTURE_PIN     34   // Capacitive moisture sensor — ADC input
#define WATER_LEVEL_PIN  19   // XKC-Y25 water level sensor — digital input (active HIGH)

// =============================================================================
// LEDC PWM controller settings  (Requirement 6.1)
// =============================================================================
#define PWM_CHANNEL    0      // LEDC channel 0
#define PWM_FREQ       5000   // 5 000 Hz carrier frequency
#define PWM_RESOLUTION 8      // 8-bit resolution → duty cycle range 0–255

// =============================================================================
// Sensor reporting interval  (Requirement 7.1, 7.2, 7.4)
// =============================================================================
#define SENSOR_INTERVAL_MS 30000UL  // 30 seconds between sensor reads
