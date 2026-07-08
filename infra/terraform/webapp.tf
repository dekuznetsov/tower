# Firebase web app — the source of the web SDK configuration consumed by the
# React build.
resource "google_firebase_web_app" "default" {
  provider     = google-beta
  project      = var.project_id
  display_name = "Hydroponics Web"

  depends_on = [google_firebase_project.default]
}

data "google_firebase_web_app_config" "default" {
  provider   = google-beta
  project    = var.project_id
  web_app_id = google_firebase_web_app.default.app_id
}
