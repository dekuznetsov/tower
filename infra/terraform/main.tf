locals {
  database_instance_id = var.database_instance_id != "" ? var.database_instance_id : "${var.project_id}-default-rtdb"

  required_apis = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "firebase.googleapis.com",
    "firebasedatabase.googleapis.com",
    "firebasehosting.googleapis.com",
    "identitytoolkit.googleapis.com",
    # Cloud Functions (2nd gen) for Google Chat monitoring alerts
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "cloudscheduler.googleapis.com",
    "secretmanager.googleapis.com",
  ]
}

# Optionally create the GCP project. When adopting an existing project, set
# create_project = false and this resource is skipped.
resource "google_project" "default" {
  count           = var.create_project ? 1 : 0
  name            = var.project_name
  project_id      = var.project_id
  billing_account = var.billing_account != "" ? var.billing_account : null
  org_id          = var.org_id != "" ? var.org_id : null
}

# Enable the APIs Firebase needs.
resource "google_project_service" "apis" {
  for_each                   = toset(local.required_apis)
  project                    = var.project_id
  service                    = each.value
  disable_dependent_services = false
  disable_on_destroy         = false

  depends_on = [google_project.default]
}

# Adopt the project into Firebase.
resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id

  depends_on = [google_project_service.apis]
}
