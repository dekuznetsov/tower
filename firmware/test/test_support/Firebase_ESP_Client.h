#pragma once
// Fake Firebase_ESP_Client.h for native host testing.
// Provides minimal stub types so firmware source files compile on the host.
// The mock globals (g_water_level_pin_value, etc.) are declared here as extern
// and must be defined in exactly one translation unit (the test file).

#include <string>
#include <cstdint>

// ---------------------------------------------------------------------------
// Mock globals — declared here, defined in the test file
// ---------------------------------------------------------------------------

// digitalRead() returns this value for any pin
extern int  g_water_level_pin_value;

// analogRead() returns this value for any pin
extern int  g_analog_read_value;

// Captures the last ledcWrite() call
extern int  g_last_ledc_channel;
extern int  g_last_ledc_duty;

// Captures the last pump_state value written via Firebase.setBool
extern bool g_last_pump_state_written;
extern bool g_firebase_write_called;

// Captures the last sensor values written via Firebase.updateNode
extern int  g_last_sensor_moisture;
extern bool g_last_sensor_water_level_low;
extern bool g_sensor_write_called;

// ---------------------------------------------------------------------------
// Arduino hardware API stubs
// ---------------------------------------------------------------------------

inline int digitalRead(int /*pin*/) {
    return g_water_level_pin_value;
}

inline int analogRead(int /*pin*/) {
    return g_analog_read_value;
}

inline void ledcWrite(int channel, int duty) {
    g_last_ledc_channel = channel;
    g_last_ledc_duty    = duty;
}

inline void ledcSetup(int /*channel*/, int /*freq*/, int /*resolution*/) {}
inline void ledcAttachPin(int /*pin*/, int /*channel*/) {}

// ---------------------------------------------------------------------------
// Firebase stubs
// ---------------------------------------------------------------------------

// FirebaseJson stub — captures the last set() calls for sensor values
struct FirebaseJson {
    void set(const char* key, int value) {
        std::string k(key);
        if (k == "moisture") {
            g_last_sensor_moisture = value;
        }
    }
    void set(const char* key, bool value) {
        std::string k(key);
        if (k == "water_level_low") {
            g_last_sensor_water_level_low = value;
        }
    }
};

struct FirebaseData {
    std::string errorReason() const { return ""; }
};

struct FirebaseConfig {};
struct FirebaseAuth   {};

struct FirebaseStream {
    std::string dataPath()   const { return _path; }
    std::string stringData() const { return _strVal; }
    int         intData()    const { return _intVal; }
    bool        boolData()   const { return _boolVal; }
    std::string dataType()   const { return _type; }

    std::string _path;
    std::string _strVal;
    int         _intVal  = 0;
    bool        _boolVal = false;
    std::string _type    = "string";
};

struct FirebaseClass {
    bool setBool(FirebaseData& /*data*/, const char* path, bool value) {
        std::string p(path);
        if (p.find("pump_state") != std::string::npos) {
            g_last_pump_state_written = value;
            g_firebase_write_called   = true;
        }
        return true;
    }

    bool updateNode(FirebaseData& /*data*/, const char* /*path*/, FirebaseJson& /*json*/) {
        g_sensor_write_called = true;
        return true;
    }

    bool beginStream(FirebaseData&, const char*) { return true; }
    bool setStreamCallback(FirebaseData&, void*, void*) { return true; }
    void begin(FirebaseConfig*, FirebaseAuth*) {}
    void reconnectWiFi(bool) {}
};

// Firebase singleton — declared here, defined in the test file
extern FirebaseClass Firebase;

// ---------------------------------------------------------------------------
// Serial stub — no-op
// ---------------------------------------------------------------------------

struct SerialClass {
    template<typename T> void print(T)   {}
    template<typename T> void println(T) {}
    void print(const char*)   {}
    void println(const char*) {}
};

// Serial singleton — declared here, defined in the test file
extern SerialClass Serial;
