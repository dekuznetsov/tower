# Requirements Document

## Introduction

This document defines the requirements for a full-stack IoT hydroponics farm management system. The system enables remote monitoring and control of hydroponic growing towers through a Firebase Realtime Database backend, ESP32 firmware running on each tower's microcontroller, and a Flutter mobile application. The system supports both automatic timed pump cycling and manual pump control, with safety interlocks based on water level sensing.

## Glossary

- **Farm**: A collection of hydroponic towers identified by a unique farm ID in the database.
- **Tower**: A single hydroponic growing unit containing a pump, moisture sensor, and water level sensor.
- **Firebase_Database**: The Firebase Realtime Database service used as the central data store and communication bus between the firmware and mobile app.
- **ESP32_Firmware**: The C++ firmware running on the ESP32 microcontroller embedded in each tower.
- **Mobile_App**: The Flutter-based mobile application used by the farm operator to monitor and control towers.
- **Pump**: The 12V water pump controlled via MOSFET and PWM signal on the ESP32.
- **PWM_Controller**: The LEDC PWM peripheral on the ESP32 used to control pump speed (GPIO 18, channel 0, 5000 Hz, 8-bit resolution).
- **Moisture_Sensor**: The capacitive soil moisture sensor v1.2 connected to GPIO 34 (ADC input) on the ESP32.
- **Water_Level_Sensor**: The non-contact XKC-Y25 water level sensor connected to GPIO 19 (digital input, active high) on the ESP32.
- **Auto_Mode**: A pump operating mode where the pump cycles on and off based on configurable time intervals.
- **Manual_Mode**: A pump operating mode where the pump is directly controlled by the operator via the mobile app.
- **pump_speed**: An integer value in the range 0–255 representing the PWM duty cycle for pump speed control.
- **pump_mode**: A string value of either `'auto'` or `'manual'` indicating the current operating mode of the pump.
- **pump_state**: A boolean value in the database reflecting the current on/off state of the pump.
- **pump_switch**: A boolean value written by the operator to turn the pump on or off in Manual_Mode.
- **interval_on_min**: An integer representing the number of minutes the pump stays on during one Auto_Mode cycle.
- **interval_off_min**: An integer representing the number of minutes the pump stays off during one Auto_Mode cycle.
- **water_level_low**: A boolean sensor reading that is `true` when the reservoir water level is below the sensor threshold.
- **moisture**: An integer analog reading from the Moisture_Sensor representing soil moisture level.
- **Safety_Interlock**: The firmware behavior that forces pump speed to 0 when `water_level_low` is `true`.

---

## Requirements

### Requirement 1: Firebase Realtime Database Schema

**User Story:** As a farm operator, I want a well-defined database structure, so that the firmware and mobile app can reliably exchange tower state and sensor data.

#### Acceptance Criteria

1. THE Firebase_Database SHALL store tower data under the path `farms/farm_id_1/towers/{tower_id}` for each tower.
2. THE Firebase_Database SHALL store the following fields for each tower: `pump_speed` (integer, 0–255), `pump_mode` (string, `'auto'` or `'manual'`), `interval_on_min` (integer), `interval_off_min` (integer), `pump_state` (boolean), and `pump_switch` (boolean).
3. THE Firebase_Database SHALL store sensor readings for each tower under the path `farms/farm_id_1/towers/{tower_id}/sensors`, containing `moisture` (integer) and `water_level_low` (boolean).
4. WHEN a field value is written to the Firebase_Database, THE Firebase_Database SHALL make the updated value available to all connected clients within the real-time sync latency of the Firebase service.

---

### Requirement 2: ESP32 Firmware — Connectivity

**User Story:** As a farm operator, I want the ESP32 to connect to WiFi and Firebase automatically, so that the tower is always reachable for monitoring and control.

#### Acceptance Criteria

1. WHEN the ESP32_Firmware starts, THE ESP32_Firmware SHALL connect to the configured WiFi network before attempting any Firebase operations.
2. WHEN the WiFi connection is established, THE ESP32_Firmware SHALL authenticate with the Firebase_Database using the Firebase-ESP-Client library.
3. WHEN the Firebase_Database connection is established, THE ESP32_Firmware SHALL begin streaming changes from the path `/farms/farm_id_1/towers/tower_1`.
4. IF the WiFi connection is lost, THEN THE ESP32_Firmware SHALL attempt to reconnect to WiFi without blocking sensor reporting or pump control operations already in progress.

---

### Requirement 3: ESP32 Firmware — Firebase Stream Handling

**User Story:** As a farm operator, I want the firmware to respond immediately to database changes, so that control commands take effect without delay.

#### Acceptance Criteria

1. WHEN the Firebase_Database stream delivers an updated value for `pump_mode`, THE ESP32_Firmware SHALL switch the Pump operating mode to the received value within one stream callback cycle.
2. WHEN the Firebase_Database stream delivers an updated value for `pump_speed`, THE ESP32_Firmware SHALL apply the new PWM duty cycle to the PWM_Controller within one stream callback cycle.
3. WHEN the Firebase_Database stream delivers an updated value for `pump_switch` and `pump_mode` is `'manual'`, THE ESP32_Firmware SHALL set the Pump on or off according to the received boolean value within one stream callback cycle.
4. WHEN the Firebase_Database stream delivers updated values for `interval_on_min` or `interval_off_min`, THE ESP32_Firmware SHALL apply the new interval values to the Auto_Mode timer on the next timer cycle.

---

### Requirement 4: ESP32 Firmware — Auto Mode Operation

**User Story:** As a farm operator, I want the pump to cycle automatically based on configurable on/off intervals, so that plants receive water on a schedule without manual intervention.

#### Acceptance Criteria

1. WHILE `pump_mode` is `'auto'`, THE ESP32_Firmware SHALL cycle the Pump on for `interval_on_min` minutes and then off for `interval_off_min` minutes, repeating continuously.
2. WHILE `pump_mode` is `'auto'`, THE ESP32_Firmware SHALL implement the timer cycle using non-blocking `millis()`-based timing so that other firmware tasks are not blocked.
3. WHEN the Pump state changes during Auto_Mode, THE ESP32_Firmware SHALL write the updated `pump_state` boolean to the Firebase_Database.
4. WHEN `pump_mode` changes from `'auto'` to `'manual'`, THE ESP32_Firmware SHALL stop the Auto_Mode timer immediately.

---

### Requirement 5: ESP32 Firmware — Manual Mode Operation

**User Story:** As a farm operator, I want to turn the pump on or off manually from the mobile app, so that I can water plants on demand outside of the automatic schedule.

#### Acceptance Criteria

1. WHILE `pump_mode` is `'manual'`, THE ESP32_Firmware SHALL set the Pump on or off based on the current value of `pump_switch` in the Firebase_Database.
2. WHEN `pump_switch` changes while `pump_mode` is `'manual'`, THE ESP32_Firmware SHALL update the Pump state within one stream callback cycle.
3. WHEN the Pump state changes during Manual_Mode, THE ESP32_Firmware SHALL write the updated `pump_state` boolean to the Firebase_Database.
4. WHEN `pump_mode` changes from `'manual'` to `'auto'`, THE ESP32_Firmware SHALL ignore subsequent changes to `pump_switch` until `pump_mode` returns to `'manual'`.

---

### Requirement 6: ESP32 Firmware — PWM Pump Speed Control

**User Story:** As a farm operator, I want to control the pump speed via a PWM signal, so that I can adjust water flow rate for different growing conditions.

#### Acceptance Criteria

1. THE PWM_Controller SHALL be configured on GPIO 18, LEDC channel 0, at 5000 Hz frequency with 8-bit resolution (0–255 duty cycle range).
2. WHEN `pump_speed` is updated in the Firebase_Database, THE ESP32_Firmware SHALL write the new duty cycle value to the PWM_Controller.
3. WHEN the Pump is turned off (pump state = false), THE ESP32_Firmware SHALL set the PWM_Controller duty cycle to 0 regardless of the `pump_speed` value.
4. WHEN the Pump is turned on (pump state = true), THE ESP32_Firmware SHALL set the PWM_Controller duty cycle to the current `pump_speed` value.

---

### Requirement 7: ESP32 Firmware — Sensor Reporting

**User Story:** As a farm operator, I want sensor readings reported to the database regularly, so that I can monitor plant moisture and reservoir water level in real time.

#### Acceptance Criteria

1. THE ESP32_Firmware SHALL read the Moisture_Sensor analog value from GPIO 34 (ADC) every 30 seconds.
2. THE ESP32_Firmware SHALL read the Water_Level_Sensor digital value from GPIO 19 every 30 seconds.
3. WHEN sensor readings are taken, THE ESP32_Firmware SHALL write the `moisture` integer and `water_level_low` boolean to the Firebase_Database path `farms/farm_id_1/towers/tower_1/sensors`.
4. THE ESP32_Firmware SHALL implement the 30-second sensor reporting interval using non-blocking `millis()`-based timing so that pump control operations are not blocked.

---

### Requirement 8: ESP32 Firmware — Safety Interlock

**User Story:** As a farm operator, I want the pump to stop automatically when the water reservoir is empty, so that the pump is protected from running dry and being damaged.

#### Acceptance Criteria

1. WHEN `water_level_low` is `true`, THE ESP32_Firmware SHALL immediately set the PWM_Controller duty cycle to 0, overriding both Auto_Mode and Manual_Mode pump control.
2. WHEN `water_level_low` is `true`, THE ESP32_Firmware SHALL write `pump_state` as `false` to the Firebase_Database.
3. WHILE `water_level_low` is `true`, THE ESP32_Firmware SHALL prevent any pump activation regardless of `pump_mode`, `pump_switch`, or Auto_Mode timer state.
4. WHEN `water_level_low` changes from `true` to `false`, THE ESP32_Firmware SHALL resume normal pump control according to the current `pump_mode`.

---

### Requirement 9: Mobile App — Firebase Integration

**User Story:** As a farm operator, I want the mobile app to connect to Firebase, so that I can monitor and control the tower from my phone in real time.

#### Acceptance Criteria

1. WHEN the Mobile_App launches, THE Mobile_App SHALL establish a connection to the Firebase_Database.
2. WHEN the Firebase_Database connection is established, THE Mobile_App SHALL subscribe to real-time updates from the path `/farms/farm_id_1/towers/tower_1`.
3. WHEN a value changes at the subscribed path, THE Mobile_App SHALL update the displayed UI within one UI frame render cycle after receiving the update.
4. IF the Firebase_Database connection is lost, THEN THE Mobile_App SHALL display a connection status indicator to the operator.

---

### Requirement 10: Mobile App — Sensor Monitoring Display

**User Story:** As a farm operator, I want to see live sensor readings on the app, so that I can assess plant health and water availability at a glance.

#### Acceptance Criteria

1. THE Mobile_App SHALL display the current `moisture` integer value received from the Firebase_Database.
2. THE Mobile_App SHALL display the water level status as the text `'Good'` when `water_level_low` is `false`, and as the text `'Low'` when `water_level_low` is `true`.
3. WHEN the `moisture` or `water_level_low` value changes in the Firebase_Database, THE Mobile_App SHALL update the displayed value without requiring the operator to refresh the screen.

---

### Requirement 11: Mobile App — Mode Selection

**User Story:** As a farm operator, I want to switch the tower between Auto and Manual mode from the app, so that I can choose the appropriate control strategy for current conditions.

#### Acceptance Criteria

1. THE Mobile_App SHALL display a switch control that reflects the current `pump_mode` value from the Firebase_Database (`'auto'` or `'manual'`).
2. WHEN the operator toggles the mode switch, THE Mobile_App SHALL write the corresponding `pump_mode` value (`'auto'` or `'manual'`) to the Firebase_Database path `farms/farm_id_1/towers/tower_1`.
3. WHEN `pump_mode` changes in the Firebase_Database, THE Mobile_App SHALL update the mode switch state and show or hide the relevant control panel (Auto controls or Manual controls) without requiring the operator to restart the app.

---

### Requirement 12: Mobile App — Manual Mode Controls

**User Story:** As a farm operator, I want manual pump controls in the app, so that I can turn the pump on or off and set its speed when operating in Manual mode.

#### Acceptance Criteria

1. WHILE `pump_mode` is `'manual'`, THE Mobile_App SHALL display a pump on/off switch and a speed slider.
2. WHEN the operator toggles the pump on/off switch, THE Mobile_App SHALL write the corresponding boolean value to `pump_switch` in the Firebase_Database.
3. THE Mobile_App SHALL display the speed slider with a visible range of 0% to 100%.
4. WHEN the operator moves the speed slider, THE Mobile_App SHALL map the slider percentage to an integer in the range 0–255 and write the result to `pump_speed` in the Firebase_Database.
5. WHEN `pump_state` changes in the Firebase_Database, THE Mobile_App SHALL update the pump on/off switch to reflect the current state.

---

### Requirement 13: Mobile App — Auto Mode Controls

**User Story:** As a farm operator, I want to configure the automatic pump cycle intervals from the app, so that I can adjust the watering schedule to suit plant growth stages.

#### Acceptance Criteria

1. WHILE `pump_mode` is `'auto'`, THE Mobile_App SHALL display text input fields for `interval_on_min` (Time On) and `interval_off_min` (Time Off), each accepting integer values in minutes.
2. WHEN the operator submits a new value for `interval_on_min` or `interval_off_min`, THE Mobile_App SHALL write the integer value to the corresponding field in the Firebase_Database.
3. IF the operator enters a non-integer or negative value for `interval_on_min` or `interval_off_min`, THEN THE Mobile_App SHALL display a validation error and SHALL NOT write the invalid value to the Firebase_Database.
4. WHEN `interval_on_min` or `interval_off_min` changes in the Firebase_Database, THE Mobile_App SHALL update the displayed text field values to reflect the current database values.

---

### Requirement 14: Hardware — Схема пристрою та список компонентів

**User Story:** Як розробник або збирач пристрою, я хочу мати чітку схему підключення та список компонентів, доступних на AliExpress, щоб я міг зібрати фізичний пристрій без додаткових досліджень.

#### Acceptance Criteria

1. THE Hardware_Documentation SHALL include a wiring diagram showing all electrical connections between the ESP32, MOSFET module, pump, moisture sensor, water level sensor, and power supply.
2. THE Hardware_Documentation SHALL specify the exact GPIO pin assignments used in the firmware: GPIO 18 (PWM pump output), GPIO 34 (moisture sensor ADC input), GPIO 19 (water level sensor digital input).
3. THE Hardware_Documentation SHALL include a bill of materials (BOM) listing every required component with its AliExpress search keyword or product name, quantity, and purpose.
4. THE Hardware_Documentation SHALL specify the power supply requirements: 5V for the ESP32 and logic circuits, 12V for the pump, and the required current ratings.
5. THE Hardware_Documentation SHALL include a note on electrical isolation between the 12V pump circuit and the 3.3V ESP32 logic circuit, achieved via the MOSFET gate driver.
6. THE Hardware_Documentation SHALL be stored as `hardware/README.md` in the project repository.

---

#### Bill of Materials (AliExpress)

| # | Компонент | Пошуковий запит на AliExpress | К-сть | Призначення |
|---|-----------|-------------------------------|-------|-------------|
| 1 | ESP32 DevKit v1 (38-pin) | `ESP32 DevKit V1 38pin` | 1 | Мікроконтролер — WiFi, Firebase, PWM, ADC |
| 2 | Капацитивний датчик вологості ґрунту v1.2 | `Capacitive Soil Moisture Sensor v1.2` | 1 | Аналоговий вхід GPIO 34 — вимірювання вологості |
| 3 | Безконтактний датчик рівня рідини XKC-Y25 | `XKC-Y25 liquid level sensor non-contact` | 1 | Цифровий вхід GPIO 19 — контроль рівня води в резервуарі |
| 4 | MOSFET-модуль IRF520 (або IRLZ44N) | `IRF520 MOSFET module PWM` | 1 | Ключ для керування насосом 12V через PWM GPIO 18 |
| 5 | Занурювальний насос 12V DC (3–5W) | `12V DC mini submersible pump 3W` | 1 | Подача води до гідропонної башти |
| 6 | Блок живлення 12V 2A (DC адаптер) | `12V 2A DC power adapter 5.5mm` | 1 | Живлення насоса |
| 7 | Понижуючий перетворювач DC-DC (12V → 5V) | `LM2596 DC-DC step down module 12V 5V` | 1 | Живлення ESP32 від 12V шини |
| 8 | Макетна плата або перфорована плата | `PCB prototype board 5x7cm` | 1 | Монтаж схеми |
| 9 | З'єднувальні дроти Dupont (мама-тато) | `Dupont jumper wire 20cm male female` | 1 набір | З'єднання компонентів |
| 10 | Резистор 10 кОм (для підтяжки, якщо потрібно) | `resistor 10k ohm 1/4W` | 5 | Pull-up/pull-down для цифрових входів |
| 11 | Конденсатор 100 мкФ 25V (електролітичний) | `electrolytic capacitor 100uF 25V` | 2 | Фільтрація живлення насоса |
| 12 | Клемна колодка 2-pin (гвинтова) | `screw terminal block 2pin 5mm` | 3 | Підключення насоса та живлення |
| 13 | Корпус для електроніки (пластиковий) | `plastic enclosure project box 100x60mm` | 1 | Захист електроніки від вологи |

---

#### Схема підключення (текстовий опис)

```
12V DC Adapter
    │
    ├──[+12V]──────────────────────────────────────────────────────┐
    │                                                              │
    │         LM2596 Step-Down Module                             │
    ├──[+12V]──[IN+]──[OUT+]──[+5V]──[ESP32 VIN]                 │
    └──[GND]───[IN-]──[OUT-]──[GND]──[ESP32 GND]                 │
                                                                   │
ESP32 DevKit v1                                                    │
    ├── GPIO 18 ──────────────[IRF520 SIG]                        │
    │                              │                               │
    │                         IRF520 MOSFET Module                │
    │                         [SIG]─[VCC(5V)]─[GND]              │
    │                              │                               │
    │                         [DRAIN]──[Pump +]──────────────────[+12V]
    │                         [SOURCE]──[Pump -]──────────────────[GND]
    │                                                              │
    ├── GPIO 34 ──────────────[Moisture Sensor AOUT]              │
    │            [Moisture Sensor VCC]──[3.3V]                    │
    │            [Moisture Sensor GND]──[GND]                     │
    │                                                              │
    ├── GPIO 19 ──────────────[XKC-Y25 OUT]                       │
    │            [XKC-Y25 VCC]──[5V]                              │
    │            [XKC-Y25 GND]──[GND]                             │
    │                                                              │
    └── GND ──────────────────────────────────────────────────────┘
```

> **Примітка щодо MOSFET IRF520:** Модуль IRF520 має вбудований резистор затвора та захист. Сигнал PWM з GPIO 18 (3.3V логіка) достатній для керування затвором. Насос підключається між DRAIN і +12V; SOURCE з'єднується з GND. Переконайтеся, що GND ESP32 і GND 12V шини об'єднані (спільна земля).

> **Примітка щодо датчика вологості:** Капацитивний датчик v1.2 живиться від 3.3V або 5V. Аналоговий вихід AOUT підключається до GPIO 34 (ADC1). Значення 0–4095 відповідає діапазону вологості (4095 = сухо, ~1500 = у воді).

> **Примітка щодо XKC-Y25:** Датчик живиться від 5V. Вихід OUT — цифровий, активний HIGH (HIGH = рівень нижче датчика = резервуар порожній). Підключається до GPIO 19.
