# Realtime Database default instance.
resource "google_firebase_database_instance" "default" {
  provider    = google-beta
  project     = var.project_id
  region      = var.rtdb_region
  instance_id = local.database_instance_id
  type        = "DEFAULT_DATABASE"

  depends_on = [google_firebase_project.default]
}
