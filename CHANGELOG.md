# Журнал змін

Усі помітні зміни в цьому проєкті документуються в цьому файлі.

Формат базується на [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
а проєкт дотримується [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-07-09

Перенесення операторського інтерфейсу у web (публікація в App Store недоступна), автентифікація через Google OAuth, доставка інфраструктури через Terraform і сповіщення моніторингу в Google Chat. Прошивка, схема БД та застосунок Flutter не змінені; Flutter збережено як основу для майбутніх Android/iOS, але наразі не розгортається.

### Додано

#### Web-застосунок (`web/`)
- Новий SPA на React + TypeScript + Vite, розгортається на Firebase Hosting
- Порт логіки з Flutter: `TowerState` (parse/serialize/computed), realtime-хук `useTower` (`onValue` + `.info/connected`), `TowerRepository`, валідація інтервалів
- UI-паритет: банер з'єднання, картка датчиків, перемикач режиму, панелі Auto/Manual (слайдер швидкості 0–100% → 0–255)
- Юніт- та property-based тести (Vitest + fast-check): властивості W1–W8

#### Автентифікація та доступ
- Вхід через **Google OAuth** (Firebase Auth), popup із fallback на redirect
- Авторизація за **списком доступу (allowlist)**: `/allowlist/{uid} === true`
- Клієнтський гейт статусів (`loading`/`signed_out`/`not_allowed`/`allowed`) + екран «Немає доступу»

#### Сповіщення моніторингу в Google Chat (`functions/`)
- Cloud Functions (2nd gen, TypeScript) з доставкою через incoming webhook
- Події: низький рівень води (критично), відновлення, пристрій офлайн (scheduled watchdog), знову онлайн, зміна `pump_mode`
- Edge-тригер проти спаму; heartbeat `monitoring/last_seen`; секрет `GOOGLE_CHAT_WEBHOOK_URL`
- Юніт- та property-based тести (Vitest + fast-check): властивості N1–N6

#### Інфраструктура та деплой (`infra/terraform/`)
- Terraform (google / google-beta): проєкт, увімкнення Firebase, RTDB, Identity Platform + Google-провайдер, Firebase web app, сайт Hosting, секрет у Secret Manager
- Деплой правил, seed, allowlist, Cloud Functions і Hosting через Firebase CLI у `local-exec`
- Кореневі `firebase.json` та `.firebaserc`
- CI (GitHub Actions): тести/збірка web та functions, `terraform fmt`/`validate`

### Змінено
- Правила безпеки RTDB: доступ до `farms/` тепер гейтиться через allowlist (замість просто `auth != null`)
- Документацію оновлено й перекладено українською (README, CHANGELOG, README у firebase/, firmware/test/, infra/terraform/)
- `CLAUDE.md` доповнено web-клієнтом, моделлю доступу та інфраструктурою

---

## [1.0.0] - 2026-05-05

### Додано

#### Firebase
- Схема Realtime Database для `farms/farm_id_1/towers/tower_1` з усіма полями керування та датчиків
- Правила безпеки: автентифікований доступ на читання/запис за шляхом `farms/`; неавтентифікований доступ заборонено
- Початкові дані JSON для імпорту через консоль та REST API
- Конфігурація розгортання через Firebase CLI

#### Прошивка ESP32 (PlatformIO / Arduino)
- Проєкт PlatformIO зі середовищами збірки `esp32dev` та `native`
- Менеджер WiFi-з'єднання з неблокуючим циклом перепідключення
- Підписка на Firebase-стрім `farms/farm_id_1/towers/tower_1` з відновленням після таймауту стріму
- Структура `FirmwareState`, що зберігає весь стан керування та датчиків у пам'яті
- Диспетчер зворотного виклику стріму (`onFirebaseStream`) для `pump_mode`, `pump_speed`, `pump_switch`, `interval_on_min`, `interval_off_min`
- Таймер авто-режиму (`AutoTimer`) — неблокуюче циклювання on/off на основі `millis()`
- Обробник ручного режиму — керування вимикачем насоса через Firebase-стрім
- Керування швидкістю насоса через PWM на LEDC (GPIO 18, канал 0, 5000 Hz, 8-bit)
- Захисне блокування (`applyPumpState`) — примусово встановлює PWM у 0 та записує `pump_state = false`, коли `water_level_low` дорівнює true
- Репортер датчиків — зчитує вологість (GPIO 34 ADC) та рівень води (GPIO 19) кожні 30 секунд, записує у Firebase
- Логування помилок запису Firebase через Serial
- Юніт-тести GoogleTest для всіх модулів прошивки
- Property-based тести rapidcheck (властивості 2–5, 7–11)

#### Мобільний застосунок Flutter
- Ініціалізація Firebase з кореневим `ProviderScope`
- Модель даних `TowerState` із фабрикою `fromSnapshot`, `toMap`, `speedPercent`, `sliderToSpeed`, `waterLevelDisplay`
- `TowerRepository` — типізований шар читання/запису Firebase для всіх полів керування
- `validateInterval` — валідація вводу для полів інтервалів авто-режиму
- Провайдери Riverpod: `towerRepositoryProvider`, `towerStreamProvider`, `connectionStatusProvider`
- `ConnectionStatusBanner` — показується, коли Firebase-стрім недоступний
- `SensorCard` із `MoistureDisplay` та `WaterLevelDisplay`
- `ModeSwitchTile` — відображає та записує `pump_mode`
- `AutoModePanel` з `IntervalOnField` та `IntervalOffField` — інлайн-валідація, snackbar у разі помилки запису
- `ManualModePanel` з `PumpSwitchTile` та `SpeedSlider` (0–100% → 0–255)
- Кореневий віджет `TowerDashboard` — умовно рендерить панель Auto чи Manual залежно від `pump_mode`
- Юніт-тести flutter_test, тести репозиторію на mockito та widget-тести
- Property-based тести fast_check (властивості 1, 12–17)

#### Апаратна документація
- Повний список компонентів із пошуковими запитами AliExpress (13 компонентів, ~$15–25 USD)
- ASCII-схема підключення: ESP32 ↔ IRF520 MOSFET ↔ насос, датчик вологості, датчик рівня води XKC-Y25
- Таблиця призначення GPIO та вимоги до живлення
- Примітки зі збирання для MOSFET, капацитивного датчика вологості та XKC-Y25
- Схема розміщення в корпусі

#### Проєкт
- `README.md` з оглядом архітектури, посібником із початку роботи та довідником схеми БД
- `LICENSE` — Mozilla Public License 2.0

[1.1.0]: https://github.com/your-username/hydroponics-farm-management/releases/tag/v1.1.0
[1.0.0]: https://github.com/your-username/hydroponics-farm-management/releases/tag/v1.0.0
