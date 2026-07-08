# Hydroponics Farm Management System

Повностекова IoT-система для віддаленого моніторингу та керування гідропонними баштами. Складається зі спільного бекенду **Firebase Realtime Database**, **прошивки ESP32** на мікроконтролері кожної башти та **двох фронтендів** над одним бекендом: розгорнутого **web-застосунку** (React на Firebase Hosting) і **застосунку Flutter**, який залишено як основу для майбутніх збірок Android/iOS.

> **Примітка про платформи.** Публікація в App Store вимагає платної участі в Apple Developer Program, що суперечить концепції проєкту — **нульові затрати на інфраструктуру**. Тому операторський інтерфейс реалізовано як web (Firebase Hosting) із входом через Google OAuth, у межах безкоштовних лімітів Firebase. Код Flutter збережено як основу для майбутніх Android/iOS, але **зараз не розгортається**.

---

## Можливості

- **Моніторинг у реальному часі** — покази вологості ґрунту та рівня води в резервуарі надходять кожні 30 секунд
- **Авто-режим** — насос вмикається/вимикається за налаштовуваними інтервалами часу без ручного втручання
- **Ручний режим** — увімкнення/вимкнення насоса та задання швидкості на вимогу
- **Керування швидкістю через PWM** — швидкість 0–100% відображається у 8-бітну шпаруватість PWM (0–255)
- **Захисне блокування** — насос примусово вимикається, коли резервуар порожніє, захищаючи його від роботи «на суху»
- **Стійкість до збоїв зв'язку** — прошивка працює на останньому відомому стані під час перебоїв WiFi/Firebase; клієнт показує банер про втрату з'єднання
- **Автентифікація через Google OAuth** — вхід через Google із авторизацією за списком доступу (allowlist)
- **Сповіщення моніторингу в Google Chat** — критичні події (низький рівень води, відновлення, пристрій офлайн, зміна режиму) надсилаються власнику через Cloud Function із edge-тригером (без спаму)

---

## Архітектура

```
        Клієнти                          Бекенд                          Пристрій
┌──────────────────────┐
│  Web App (React/TS)  │──┐
│  Firebase Hosting    │  │        ┌──────────────────────────┐        ┌─────────────────────┐
│  Google OAuth        │  │        │  Firebase Realtime DB    │        │   ESP32 Firmware    │
└──────────────────────┘  │        │                          │ ──────▶│  Stream callback    │
                          ├──────▶ │  farms/farm_id_1/        │        │  Auto mode timer    │
┌──────────────────────┐  │        │    towers/tower_1/       │ ◀───── │  Safety interlock   │
│  Flutter App         │──┘        │  allowlist/{uid}         │        │  PWM controller     │
│  (майбутні Android/  │           └──────────────────────────┘        │  Sensor reporter    │
│   iOS; не деплоїться)│                                                └─────────────────────┘
└──────────────────────┘
```

Клієнти ніколи не спілкуються з прошивкою напряму — уся координація проходить через Firebase, який діє як спільна машина станів. Прошивка є авторитетним джерелом для `pump_state` та показів датчиків; клієнти — авторитетне джерело наміру оператора (`pump_mode`, `pump_switch`, `pump_speed`, `interval_on_min`, `interval_off_min`) і **ніколи** не записують поля, якими володіє прошивка.

---

## Модель доступу

- Вхід — через **Google OAuth** (Firebase Auth).
- Авторизація — за **списком доступу (allowlist)**: користувач може читати/керувати `farms/` лише якщо `/allowlist/{uid} === true`.
- Правило застосовується авторитетно в `firebase/database.rules.json`; web-клієнт додатково перевіряє членство для дружнього екрана «Немає доступу». Список керується поза застосунком (Terraform/консоль) і недоступний клієнтам для запису.
- Прошивка використовує привілейований credential і **обходить** ці правила — вона не залежить від allowlist.

Деталі — у специфікації `.kiro/specs/web-app-google-auth/`.

---

## Структура репозиторію

```
├── firebase/               # Схема БД, правила безпеки (allowlist) та початкові дані
│   ├── seed_data.json      # Початкова структура БД для імпорту
│   ├── database.rules.json # Правила безпеки Firebase (гейт через allowlist)
│   └── README.md           # Інструкції з імпорту та довідник полів
│
├── firmware/               # Прошивка ESP32 на C++/Arduino (PlatformIO)
│   ├── src/                # Продакшн-код
│   ├── test/               # Юніт- та property-based тести (GoogleTest + rapidcheck)
│   └── platformio.ini      # Конфігурація збірки для esp32dev та native
│
├── web/                    # Web-застосунок оператора (React + TypeScript + Vite) — розгортається
│   ├── src/                # firebase, auth (Google OAuth + allowlist), data, components
│   └── test/               # Юніт- та property-based тести (Vitest + fast-check)
│
├── mobile/                 # Застосунок Flutter — основа для майбутніх Android/iOS (не деплоїться)
│   ├── lib/                # Код застосунку (моделі, репозиторій, провайдери, UI)
│   └── test/               # Юніт-, property- та widget-тести
│
├── functions/              # Cloud Functions (TypeScript): сповіщення моніторингу в Google Chat
│   ├── src/                # тригери RTDB + scheduled, логіка сповіщень, відправка у webhook
│   └── test/               # Юніт- та property-based тести (Vitest + fast-check)
│
├── infra/terraform/        # Інфраструктура як код: провіженінг Firebase/GCP + деплой web
│
├── hardware/               # Схема підключення та список компонентів
│   └── README.md
│
├── firebase.json           # Мапінг Hosting → web/dist та Database → правила
└── .firebaserc             # Прив'язка проєкту Firebase
```

---

## Технологічний стек

| Рівень | Технологія |
|---|---|
| База даних | Firebase Realtime Database |
| Автентифікація | Firebase Auth (Google OAuth) + allowlist |
| Прошивка | C++ / фреймворк Arduino на ESP32 (PlatformIO) |
| Бібліотеки прошивки | Firebase-ESP-Client, ArduinoJson, rapidcheck |
| Web-застосунок | React 18 + TypeScript + Vite, Firebase JS SDK |
| Тестування web | Vitest + fast-check (property-based) + Testing Library |
| Мобільний застосунок | Flutter 3 / Dart, flutter_riverpod |
| Тестування застосунку | flutter_test, mockito |
| Хостинг | Firebase Hosting |
| Сповіщення | Cloud Functions (2nd gen, TypeScript) → Google Chat webhook |
| Інфраструктура | Terraform (провайдери google / google-beta) |
| CI | GitHub Actions |

---

## Апаратна частина

Пристрій побудований навколо **ESP32 DevKit v1**; усі компоненти доступні на AliExpress за ~$15–25 USD.

| Компонент | Призначення |
|---|---|
| ESP32 DevKit v1 (38-pin) | Мікроконтролер — WiFi, Firebase, PWM, ADC |
| Капацитивний датчик вологості ґрунту v1.2 | Зчитування вологості на GPIO 34 (ADC) |
| Безконтактний датчик рівня рідини XKC-Y25 | Виявлення рівня води на GPIO 19 |
| MOSFET-модуль IRF520 | Ключ із PWM-керуванням для насоса 12V на GPIO 18 |
| Занурювальний насос 12V DC (3–5W) | Подача води до башти |
| Блок живлення 12V 2A (DC адаптер) | Живлення насоса |
| Понижуючий модуль LM2596 DC-DC | Знижує 12V до 5V для ESP32 |

Повний список компонентів, схему підключення та примітки зі збирання див. у [`hardware/README.md`](hardware/README.md).

### Призначення GPIO

| GPIO | Режим | Підключено до |
|---|---|---|
| GPIO 18 | Вихід PWM | IRF520 MOSFET SIG (керування насосом) |
| GPIO 34 | Вхід ADC | Датчик вологості AOUT |
| GPIO 19 | Цифровий вхід | Датчик рівня води XKC-Y25 OUT |

---

## Початок роботи

### 1. Інфраструктура та Firebase

**Рекомендовано — через Terraform** (провіженить проєкт, Firebase, RTDB, Google-провайдер, Hosting і виконує деплой):

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # впишіть значення
terraform init -backend-config="bucket=<your-tf-state-bucket>" -backend-config="prefix=tower"
terraform apply
```

Передумови: білінг-акаунт (Blaze), OAuth client (GCP OAuth consent screen), GCS-бакет для стейту, Firebase CLI. Деталі — у [`infra/terraform/README.md`](infra/terraform/README.md).

**Або вручну:** створіть проєкт Firebase, увімкніть **Realtime Database** та провайдер **Google** в Authentication, імпортуйте `firebase/seed_data.json`, засідьте allowlist і розгорніть правила:
```bash
npm install -g firebase-tools && firebase login
firebase deploy --only database
```
Докладніше — у [`firebase/README.md`](firebase/README.md).

### 2. Web-застосунок

**Передумови:** Node.js ≥ 20.

```bash
cd web
npm install
cp .env.example .env         # заповніть VITE_FB_* (Terraform генерує це автоматично)
npm run dev                  # локальна розробка
npm run test:run             # тести (Vitest + fast-check)
npm run build                # продакшн-збірка у web/dist
```

Розгортання виконується Terraform (`terraform apply`) або вручну: `firebase deploy --only hosting`.

### 3. Прошивка ESP32

**Передумови:** [PlatformIO](https://platformio.org/) (розширення для VS Code або CLI)

1. Скопіюйте `firmware/src/config.h.example` у `firmware/src/config.h` та впишіть свої облікові дані:
   ```cpp
   #define SSID          "your_wifi_ssid"
   #define PASSWORD      "your_wifi_password"
   #define FIREBASE_HOST "your-project-id-default-rtdb.firebaseio.com"
   #define FIREBASE_AUTH "your_database_secret_or_id_token"
   ```
2. Прошийте ESP32 та спостерігайте за виводом:
   ```bash
   pio run --target upload --environment esp32dev
   pio device monitor
   ```
3. Тести прошивки на хості (без обладнання):
   ```bash
   pio test --environment native
   ```

### 4. Мобільний застосунок Flutter (необов'язково)

Збережено для майбутніх Android/iOS; наразі не розгортається.

```bash
cd mobile
flutter pub get
flutter run
flutter test
```

---

## Схема бази даних

```
farms/
  farm_id_1/
    towers/
      tower_1/
        pump_speed:       Integer   (0–255, шпаруватість PWM — записує клієнт)
        pump_mode:        String    ("auto" | "manual" — записує клієнт)
        pump_state:       Boolean   (фактичний стан on/off — записує прошивка)
        pump_switch:      Boolean   (намір оператора в ручному режимі — записує клієнт)
        interval_on_min:  Integer   (хвилин увімкнено в авто-режимі — записує клієнт)
        interval_off_min: Integer   (хвилин вимкнено в авто-режимі — записує клієнт)
        sensors/
          moisture:         Integer   (сире значення ADC 0–4095 — записує прошивка)
          water_level_low:  Boolean   (true = резервуар порожніє — записує прошивка)

allowlist/
  <uid>: true                        (авторизовані користувачі — керується поза застосунком)
```

---

## Захисне блокування

Коли `water_level_low` дорівнює `true`, прошивка негайно встановлює PWM у 0 та записує `pump_state = false` у Firebase — незалежно від `pump_mode`, `pump_switch` чи стану авто-таймера. Це запобігає роботі насоса «на суху». Нормальна робота відновлюється автоматично, щойно рівень води буде відновлено.

---

## Сповіщення в Google Chat

Cloud Functions (2nd gen, `functions/`) стежать за RTDB та надсилають сповіщення власнику через **incoming webhook** Google Chat. Логіка edge-тригерна — повідомлення йде лише на зміні стану, а не щопокази кожні 30 с.

Події:

| Подія | Тригер | Приклад |
|---|---|---|
| Низький рівень води (критично) | `water_level_low` false → true | 🚨 Насос вимкнено для захисту від роботи «на суху» |
| Рівень води відновлено | `water_level_low` true → false | ✅ Нормальна робота відновлена |
| Пристрій офлайн | немає записів датчиків > 3 хв (scheduled) | ⚠️ Немає даних, перевірте живлення/WiFi |
| Пристрій знову онлайн | записи датчиків відновились | 🟢 Дані знову надходять |
| Зміна режиму помпи | `pump_mode` змінився | ℹ️ Режим: auto → manual |

**Налаштування:** створіть incoming webhook у просторі Chat власника (Space → Apps & integrations → Webhooks), передайте URL у Terraform-змінну `google_chat_webhook_url` — вона зберігається в Secret Manager і читається функціями як секрет `GOOGLE_CHAT_WEBHOOK_URL`. Регіон RTDB-тригерів має збігатися з `rtdb_region` (за замовч. `europe-west1`).

---

## Тестування

Проєкт наскрізно використовує property-based тестування (PBT) для перевірки властивостей коректності на випадково згенерованих вхідних даних (мінімум 100 ітерацій кожна).

**Прошивка (native-збірка):**
```bash
cd firmware && pio test --environment native
```

**Web-застосунок (Vitest + fast-check):**
```bash
cd web && npm run test:run && npm run typecheck
```

**Cloud Functions (Vitest + fast-check):**
```bash
cd functions && npm run test:run && npm run typecheck
```

**Застосунок Flutter:**
```bash
cd mobile && flutter test
```

Ключові властивості коректності, що перевіряються тестами:

- Кругова серіалізація `TowerState` через знімок Firebase (прошивка, web, Flutter)
- Захисне блокування переважає над будь-яким увімкненням насоса за низького рівня води
- Авто-таймер циклює за коректними інтервалами на основі `millis()`
- Шпаруватість PWM завжди відповідає стану насоса on/off
- Валідація інтервалів відхиляє нецілі та поза-діапазонні значення
- Видимість панелей режиму є взаємовиключною
- Доступ надається лише за наявності в allowlist; клієнт ніколи не пише поля прошивки

CI (GitHub Actions, `.github/workflows/ci.yml`) виконує тести й збірку web та `terraform fmt`/`validate`.

---

## Специфікації

Проєкт розробляється за специфікаціями (Kiro-стиль), що зберігаються в `.kiro/specs/`:

- `hydroponics-farm-management/` — базова система (Firebase, прошивка, Flutter)
- `web-app-google-auth/` — web-застосунок, Google OAuth та доставка через Terraform

Кожна специфікація містить `requirements.md`, `design.md` і `tasks.md`.

---

## Створено за допомогою

### Інструменти розробки

| Інструмент | Призначення |
|---|---|
| [Kiro](https://kiro.dev/) | ШІ-IDE для розробки базової системи за специфікаціями (v1.0.0) |
| [Claude Code](https://claude.com/claude-code) | ШІ-агент, яким додано web-застосунок, автентифікацію та інфраструктуру Terraform |
| [PlatformIO](https://platformio.org/) | Збірка прошивки ESP32, залежності та запуск тестів |
| [Vite](https://vitejs.dev/) | Збірник web-застосунку |
| [Firebase CLI](https://firebase.google.com/docs/cli) | Розгортання Hosting та правил БД |
| [Terraform](https://www.terraform.io/) | Провіженінг інфраструктури Firebase/GCP |
| [Flutter SDK](https://flutter.dev/) | Інструментарій збірки мобільного застосунку |
| [Git](https://git-scm.com/) | Контроль версій |

Базову систему (прошивка, Flutter, Firebase, апаратна документація) створено за допомогою [Kiro](https://kiro.dev/) за робочим процесом специфікацій. Web-рівень, модель доступу через Google OAuth і доставку через Terraform додано пізніше за допомогою [Claude Code](https://claude.com/claude-code).

---

## Ліцензія

[Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/)

Цей проєкт ліцензовано за MPL-2.0. Ви можете використовувати, змінювати та поширювати цей код, але будь-які зміни до файлів під ліцензією MPL мають випускатися під тією ж ліцензією. Ширші твори можуть поєднувати цей код із кодом під іншими ліцензіями.
