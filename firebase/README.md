# Початкові дані Firebase

Ця тека містить початкову структуру бази даних для системи керування гідропонною фермою.

## Файл

- `seed_data.json` — повний початковий JSON для Firebase Realtime Database за шляхом `farms/farm_id_1/towers/tower_1`

## Схема бази даних

```
farms/
  farm_id_1/
    towers/
      tower_1/
        pump_speed:       0          (Integer, 0–255 шпаруватість PWM)
        pump_mode:        "manual"   (String, "auto" | "manual")
        pump_state:       false      (Boolean, фактичний стан on/off — записує прошивка)
        pump_switch:      false      (Boolean, намір оператора в ручному режимі)
        interval_on_min:  1          (Integer, хвилин насос увімкнено в авто-режимі)
        interval_off_min: 1          (Integer, хвилин насос вимкнено в авто-режимі)
        sensors/
          moisture:         0        (Integer, сире значення ADC 0–4095)
          water_level_low:  false    (Boolean, true коли резервуар нижче порогу)
```

## Імпорт через консоль Firebase

1. Відкрийте [консоль Firebase](https://console.firebase.google.com) та оберіть свій проєкт.
2. Перейдіть до **Realtime Database** у лівій панелі.
3. Натисніть меню з трьох крапок (⋮) у правому верхньому куті панелі даних.
4. Оберіть **Import JSON**.
5. Натисніть **Browse** та оберіть `firebase/seed_data.json`.
6. Натисніть **Import**.

> **Увага:** імпорт JSON через консоль замінює всю базу даних. Якщо у вас уже є дані, скористайтеся методом REST API нижче, щоб виконати злиття.

## Імпорт через REST API

Скористайтеся REST API Firebase, щоб записати початкові дані, не перезаписуючи несуміжні шляхи.

### Запис повного вузла башти

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

Замініть `<YOUR_PROJECT_ID>` та `<YOUR_DATABASE_SECRET>` значеннями свого проєкту. Секрет бази даних можна знайти в **Project Settings → Service Accounts → Database Secrets**.

### Використання Firebase ID token (рекомендовано для продакшну)

```bash
# Спершу отримайте ID token через Firebase Auth REST API, потім:
curl -X PUT \
  "https://<YOUR_PROJECT_ID>-default-rtdb.firebaseio.com/farms/farm_id_1/towers/tower_1.json?auth=<ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d @firebase/seed_data.json
```

> **Примітка:** файл `seed_data.json` обгортає дані під кореневим ключем `farms` для сумісності з імпортом через консоль. Коли ви використовуєте REST API для конкретного шляху, витягніть внутрішній об'єкт або відповідно скоригуйте корисне навантаження `-d`.

## Правила безпеки

Файл `database.rules.json` містить правила безпеки Firebase Realtime Database для цього проєкту.

### Стислий огляд правил

- Читання/запис за шляхом `farms/` дозволено лише користувачам зі списку доступу (`/allowlist/{uid} === true`).
- Клієнти можуть читати `/allowlist`, але не можуть його змінювати (список керується поза застосунком).
- Будь-який доступ поза шляхами `farms/` та `allowlist/` заборонено за замовчуванням.

### Розгортання правил безпеки

Скористайтеся Firebase CLI, щоб розгорнути правила у своєму проєкті:

```bash
firebase deploy --only database
```

> **Передумови:** має бути встановлено Firebase CLI (`npm install -g firebase-tools`) та виконано вхід (`firebase login`). Файл `firebase.json` у корені проєкту має посилатися на файл правил:
>
> ```json
> {
>   "database": {
>     "rules": "firebase/database.rules.json"
>   }
> }
> ```

Щоб розгорнути правила, не зачіпаючи інші сервіси Firebase (Hosting, Functions тощо), завжди використовуйте прапорець `--only database`.

---

## Довідник полів

| Поле | Тип | За замовч. | Опис |
|---|---|---|---|
| `pump_speed` | Integer | `0` | Шпаруватість PWM (0–255). Записує застосунок. |
| `pump_mode` | String | `"manual"` | Режим роботи: `"auto"` або `"manual"`. Записує застосунок. |
| `pump_state` | Boolean | `false` | Фактичний стан насоса on/off. Записує прошивка ESP32. |
| `pump_switch` | Boolean | `false` | Намір оператора в ручному режимі. Записує застосунок. |
| `interval_on_min` | Integer | `1` | Хвилин насос увімкнено за цикл авто-режиму. Записує застосунок. |
| `interval_off_min` | Integer | `1` | Хвилин насос вимкнено за цикл авто-режиму. Записує застосунок. |
| `sensors/moisture` | Integer | `0` | Сире значення ADC з капацитивного датчика вологості (0–4095). Записує прошивка. |
| `sensors/water_level_low` | Boolean | `false` | `true`, коли резервуар нижче порогу датчика. Записує прошивка. |
