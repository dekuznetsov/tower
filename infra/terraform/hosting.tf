# Firebase Hosting site that serves the compiled web app.
resource "google_firebase_hosting_site" "default" {
  provider = google-beta
  project  = var.project_id
  site_id  = var.site_id
  app_id   = google_firebase_web_app.default.app_id

  depends_on = [google_firebase_project.default]
}
