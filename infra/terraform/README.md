# Інфраструктура (Terraform)

Провіженить Firebase/GCP-бекенд для гідропонного web-застосунку та розгортає
web-збірку, правила безпеки, початкові дані та список доступу (allowlist).

## Що Terraform провіженить нативно

- APIs проєкту + увімкнення Firebase (`google_firebase_project`)
- Інстанс Realtime Database (`google_firebase_database_instance`)
- Конфігурацію Identity Platform + провайдер входу **Google**
- Firebase web app (джерело конфігу web SDK)
- Сайт Firebase Hosting
- Секрет `GOOGLE_CHAT_WEBHOOK_URL` у Secret Manager (для сповіщень у Google Chat)

## Що виконується через Firebase CLI (з Terraform `local-exec`)

Провайдери Terraform для Firebase/Google не вміють завантажувати файли Hosting,
задавати правила безпеки RTDB чи писати дані в RTDB. Ці кроки виконуються через
Firebase CLI, викликаний з Terraform та впорядкований через `depends_on`:

- Розгортання `firebase/database.rules.json`
- Сідинг вузла башти з `firebase/seed_data.json`
- Злиття allowlist зі змінної `allowlist_uids`
- Деплой Cloud Functions для сповіщень у Google Chat (`firebase deploy --only functions`)
- Збірка `web/` та публікація релізу Hosting

## Передумови (ручні, одноразові)

1. **Білінг-акаунт (Blaze)** — потрібен для Identity Platform та RTDB.
2. **OAuth consent screen + OAuth client** (GCP → APIs & Services → Credentials):
   створіть OAuth 2.0 client і передайте його id/secret як `oauth_client_id` /
   `oauth_client_secret`.
2а. **Google Chat webhook** — створіть incoming webhook у просторі Chat власника
   (Space → Apps & integrations → Webhooks) і передайте URL як
   `google_chat_webhook_url` (або задайте `deploy_functions = false`, щоб пропустити).
3. **Бакет для стейту** — GCS-бакет для віддаленого стейту.
4. **Автентифікація CLI** — `firebase login` локально або задайте
   `GOOGLE_APPLICATION_CREDENTIALS` (ключ сервісного акаунта з правами Firebase
   Admin) / `FIREBASE_TOKEN` для CI.
5. Інструменти: Terraform ≥ 1.5, Firebase CLI, Node.js/npm.

## Використання

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # впишіть значення

terraform init \
  -backend-config="bucket=<your-tf-state-bucket>" \
  -backend-config="prefix=tower"

terraform plan
terraform apply
```

Після apply файл `web/.env` генерується з outputs, а реліз Hosting публікується.
Отримати конфіг будь-коли можна так:

```bash
terraform output web_config
terraform output hosting_url
```

## Примітки

- Рекомендується `site_id == project_id` (сайт Hosting за замовчуванням). Для
  іншого site id налаштуйте Hosting target у `firebase.json`/`.firebaserc`.
- Задайте `run_deploy = false`, щоб лише провіженити інфраструктуру (без
  збірки/деплою).
- Прошивка зберігає власний привілейований credential і не залежить від правил
  allowlist. Якщо перевести її на токен із UID, додайте цей UID до
  `allowlist_uids`.
- Ніколи не комітьте `terraform.tfvars`, `*.tfstate`, ключі сервісних акаунтів
  чи згенерований `web/.env` (усе в .gitignore).
