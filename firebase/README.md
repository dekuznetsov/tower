# Firebase Seed Data

This directory contains the initial database structure for the hydroponics farm management system.

## File

- `seed_data.json` — complete Firebase Realtime Database seed JSON for `farms/farm_id_1/towers/tower_1`

## Database Schema

```
farms/
  farm_id_1/
    towers/
      tower_1/
        pump_speed:       0          (Integer, 0–255 PWM duty cycle)
        pump_mode:        "manual"   (String, "auto" | "manual")
        pump_state:       false      (Boolean, actual pump on/off — written by firmware)
        pump_switch:      false      (Boolean, operator intent in manual mode)
        interval_on_min:  1          (Integer, minutes pump stays on in auto mode)
        interval_off_min: 1          (Integer, minutes pump stays off in auto mode)
        sensors/
          moisture:         0        (Integer, ADC raw value 0–4095)
          water_level_low:  false    (Boolean, true when reservoir is below threshold)
```

## Importing via Firebase Console

1. Open the [Firebase Console](https://console.firebase.google.com) and select your project.
2. Navigate to **Realtime Database** in the left sidebar.
3. Click the three-dot menu (⋮) in the top-right corner of the data panel.
4. Select **Import JSON**.
5. Click **Browse** and select `firebase/seed_data.json`.
6. Click **Import**.

> **Warning:** Importing JSON via the console replaces the entire database. If you already have data, use the REST API method below to merge instead.

## Importing via REST API

Use the Firebase REST API to write the seed data without overwriting unrelated paths.

### Write the full tower node

```bash
curl -X PUT \
  "https://<YOUR_PROJECT_ID>-default-rtdb.firebaseio.com/farms/farm_id_1/towers/tower_1.json?auth=<YOUR_DATABASE_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{
    "pump_speed": 0,
    "pump_mode": "manual",
    "pump_state": false,
    "pump_switch": false,
    "interval_on_min": 1,
    "interval_off_min": 1,
    "sensors": {
      "moisture": 0,
      "water_level_low": false
    }
  }'
```

Replace `<YOUR_PROJECT_ID>` and `<YOUR_DATABASE_SECRET>` with your project's values. The database secret can be found in **Project Settings → Service Accounts → Database Secrets**.

### Using a Firebase ID token (recommended for production)

```bash
# First obtain an ID token via the Firebase Auth REST API, then:
curl -X PUT \
  "https://<YOUR_PROJECT_ID>-default-rtdb.firebaseio.com/farms/farm_id_1/towers/tower_1.json?auth=<ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d @firebase/seed_data.json
```

> **Note:** The `seed_data.json` file wraps the data under the `farms` root key for console import compatibility. When using the REST API to target a specific path, extract the inner object or adjust the `-d` payload accordingly.

## Security Rules

The `database.rules.json` file contains the Firebase Realtime Database security rules for this project.

### Rules Summary

- Authenticated users (`auth != null`) can read and write the entire `farms/` path.
- All unauthenticated access is denied by default.
- All paths outside `farms/` are explicitly denied.

### Deploying the Security Rules

Use the Firebase CLI to deploy the rules to your project:

```bash
firebase deploy --only database
```

> **Prerequisites:** You must have the Firebase CLI installed (`npm install -g firebase-tools`) and be logged in (`firebase login`). A `firebase.json` file in the project root must reference the rules file:
>
> ```json
> {
>   "database": {
>     "rules": "firebase/database.rules.json"
>   }
> }
> ```

To deploy rules without affecting other Firebase services (Hosting, Functions, etc.), always use the `--only database` flag.

---

## Field Reference

| Field | Type | Default | Description |
|---|---|---|---|
| `pump_speed` | Integer | `0` | PWM duty cycle (0–255). Written by the mobile app. |
| `pump_mode` | String | `"manual"` | Operating mode: `"auto"` or `"manual"`. Written by the mobile app. |
| `pump_state` | Boolean | `false` | Actual pump on/off state. Written by the ESP32 firmware. |
| `pump_switch` | Boolean | `false` | Operator intent in manual mode. Written by the mobile app. |
| `interval_on_min` | Integer | `1` | Minutes the pump stays on per auto-mode cycle. Written by the mobile app. |
| `interval_off_min` | Integer | `1` | Minutes the pump stays off per auto-mode cycle. Written by the mobile app. |
| `sensors/moisture` | Integer | `0` | Raw ADC reading from the capacitive moisture sensor (0–4095). Written by firmware. |
| `sensors/water_level_low` | Boolean | `false` | `true` when the reservoir is below the sensor threshold. Written by firmware. |
