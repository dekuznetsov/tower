# Secret Manager entry holding the Google Chat webhook URL. The Cloud Functions
# read it via `defineSecret('GOOGLE_CHAT_WEBHOOK_URL')`; firebase deploy wires
# the IAM binding to the functions runtime service account automatically.
resource "google_secret_manager_secret" "chat_webhook" {
  count     = var.deploy_functions ? 1 : 0
  project   = var.project_id
  secret_id = "GOOGLE_CHAT_WEBHOOK_URL"

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "chat_webhook" {
  count       = var.deploy_functions ? 1 : 0
  secret      = google_secret_manager_secret.chat_webhook[0].id
  secret_data = var.google_chat_webhook_url
}
